import Foundation
import KeyboCore

/// Pure-logic input dispatcher. Routes `Key` taps to the text proxy and updates `KeyboardState`.
/// `now` is injectable so the double-tap-space window can be tested deterministically.
///
/// `@MainActor` because callees (`TextDocumentProxying`, `KeyboardControlling`) are main-isolated.
@MainActor
public enum InputDispatcher {

	/// Window within which two space taps collapse into ". ". Matches Apple-like behavior.
	public static let doubleSpaceWindow: TimeInterval = 0.5

	/// Dispatch the user's tap to text proxy and state-machine. Haptic feedback and the
	/// keyboard click sound are *not* a dispatcher concern — `KeyView` fires both on touch-down
	/// for the press-feel feel (matches Apple/SwiftKey), and on each backspace repeat fire.
	public static func dispatch(
		key: Key,
		state: inout KeyboardState,
		proxy: any TextDocumentProxying,
		controller: any KeyboardControlling,
		now: () -> Date = Date.init
	) {
		switch key.action {
		case .insertText(let text):
			let shifted = textWithShiftApplied(text, state: state)
			proxy.insertText(shifted)
			ShiftStateMachine.apply(.characterInserted, to: &state)
			updateSpaceTracking(insertedText: shifted, state: &state)
			applySlackEmojiSubstitutionIfNeeded(justInserted: shifted, state: &state, proxy: proxy)

		case .insertRawText(let text):
			// Long-press alternates ship already-cased text; skip shift apply.
			proxy.insertText(text)
			ShiftStateMachine.apply(.characterInserted, to: &state)
			updateSpaceTracking(insertedText: text, state: &state)
			applySlackEmojiSubstitutionIfNeeded(justInserted: text, state: &state, proxy: proxy)

		case .backspace:
			proxy.deleteBackward()
			state.lastInsertWasSpace = false
			state.lastSpaceInsertedAt = nil

		case .deleteWord:
			let count = trailingWordDeleteCount(in: proxy.documentContextBeforeInput ?? "")
			// At-least-one delete keeps the key responsive even when the context preview is empty
			// (e.g. password fields hide it) — the user is still holding delete and expects feedback.
			let effectiveCount = max(count, 1)
			for _ in 0..<effectiveCount {
				proxy.deleteBackward()
			}
			state.lastInsertWasSpace = false
			state.lastSpaceInsertedAt = nil

		case .shift:
			ShiftStateMachine.apply(.shiftTapped(at: now()), to: &state)

		case .space:
			handleSpace(state: &state, proxy: proxy, controller: controller, now: now())
			// After a space on either symbol page, hop back to letters. The user is presumably
			// starting a new word; SwiftKey/Apple stock behave the same way. Auto-cap (in the
			// controller's `textDidChange`) will then promote to `.upper` if appropriate.
			if case .symbols = state.page {
				state.page = .letters(.lower)
			}

		case .return:
			proxy.insertText("\n")
			state.lastInsertWasSpace = false
			state.lastSpaceInsertedAt = nil

		case .dismissKeyboard:
			controller.dismissKeyboard()

		case .switchPage(let newPage):
			ShiftStateMachine.apply(.pageSwitched(to: newPage), to: &state)
			state.lastInsertWasSpace = false
			state.lastSpaceInsertedAt = nil

		case .cursorOffset(let offset):
			// Trackpad-mode scrubbing. Skip the no-op offset to avoid bouncing the proxy needlessly.
			// Reset space tracking so a subsequent space tap can't be misread as a double-space.
			if offset != 0 {
				proxy.adjustTextPosition(byCharacterOffset: offset)
			}
			state.lastInsertWasSpace = false
			state.lastSpaceInsertedAt = nil
		}
	}

	// MARK: - Shift / case

	private static func textWithShiftApplied(_ text: String, state: KeyboardState) -> String {
		guard case .letters(let shift) = state.page else { return text }
		switch shift {
		case .lower:              return text
		case .upper, .capsLock:   return text.uppercased(with: Locale(identifier: "en_US_POSIX"))
		}
	}

	// MARK: - Space

	private static func handleSpace(
		state: inout KeyboardState,
		proxy: any TextDocumentProxying,
		controller: any KeyboardControlling,
		now: Date
	) {
		let withinWindow = state.lastSpaceInsertedAt.map { now.timeIntervalSince($0) < doubleSpaceWindow } ?? false
		let isDoubleTap = state.lastInsertWasSpace && withinWindow

		guard isDoubleTap else {
			proxy.insertText(" ")
			state.lastInsertWasSpace = true
			state.lastSpaceInsertedAt = now
			return
		}

		switch state.spaceDoubleTapAction {
		case .insertPeriod:
			// Replace the previous space with ". ".
			proxy.deleteBackward()
			proxy.insertText(". ")
			state.lastInsertWasSpace = true
			// Resetting the timestamp prevents triple-tap from chaining into a second substitution.
			state.lastSpaceInsertedAt = nil
		case .dismissKeyboard:
			// Delete the first space too — the user's intent on a double-tap-to-dismiss is to
			// hide the keyboard, not to commit a stray trailing space they didn't actually want.
			proxy.deleteBackward()
			controller.dismissKeyboard()
			state.lastInsertWasSpace = false
			state.lastSpaceInsertedAt = nil
		case .none:
			// Double-tap feature disabled — second tap is a regular space.
			proxy.insertText(" ")
			state.lastInsertWasSpace = true
			state.lastSpaceInsertedAt = now
		}
	}

	private static func updateSpaceTracking(insertedText: String, state: inout KeyboardState) {
		state.lastInsertWasSpace = (insertedText == " ")
		if !state.lastInsertWasSpace {
			state.lastSpaceInsertedAt = nil
		}
	}

	// MARK: - Word delete

	/// Number of trailing characters to remove for one word-delete pulse. Mirrors macOS
	/// Option+Delete: first consume any trailing whitespace run, then the contiguous
	/// trailing non-whitespace run. Returns 0 for empty/nil text — callers may floor to 1
	/// when they still want a visible response.
	static func trailingWordDeleteCount(in text: String) -> Int {
		var count = 0
		var index = text.endIndex

		while index > text.startIndex {
			let prev = text.index(before: index)
			guard text[prev].isWhitespace else { break }
			index = prev
			count += 1
		}

		while index > text.startIndex {
			let prev = text.index(before: index)
			guard !text[prev].isWhitespace else { break }
			index = prev
			count += 1
		}

		return count
	}

	// MARK: - Slack-style emoji shortcodes

	/// After a text insert, check whether the document now ends with a `:shortcode:` we recognize
	/// and, if so, delete the trailing shortcode and insert the emoji in its place. Only fires
	/// when the *just-inserted* text was the closing `:` — that's the moment a shortcode can
	/// have just completed, and the cheap fast-path avoids scanning every keystroke.
	///
	/// On a hit, also moves the inserted emoji to the head of `state.recentEmojis` (deduped,
	/// capped) so the Recents tab tracks Slack-typed emojis alongside picker-tapped ones. The
	/// caller (e.g. `KeyboardViewController`) is responsible for persisting `state.recentEmojis`
	/// to `AppGroupStore`.
	private static func applySlackEmojiSubstitutionIfNeeded(
		justInserted: String,
		state: inout KeyboardState,
		proxy: any TextDocumentProxying
	) {
		guard justInserted == ":" else { return }
		guard let context = proxy.documentContextBeforeInput else { return }
		guard let match = SlackEmojiParser.detectMatch(atEndOf: context) else { return }
		for _ in 0..<match.consumedLength {
			proxy.deleteBackward()
		}
		proxy.insertText(match.emoji)
		moveEmojiToFrontOfRecents(match.emoji, state: &state)
	}

	private static func moveEmojiToFrontOfRecents(_ emoji: String, state: inout KeyboardState) {
		var updated = state.recentEmojis
		updated.removeAll { $0 == emoji }
		updated.insert(emoji, at: 0)
		if updated.count > KeyboardState.recentEmojisCapacity {
			updated = Array(updated.prefix(KeyboardState.recentEmojisCapacity))
		}
		state.recentEmojis = updated
	}
}
