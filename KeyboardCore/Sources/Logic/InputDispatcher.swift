import Foundation

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

		case .shift:
			ShiftStateMachine.apply(.shiftTapped(at: now()), to: &state)

		case .space:
			handleSpace(state: &state, proxy: proxy, now: now())
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

		case .nextKeyboard:
			controller.advanceToNextInputMode()

		case .dismissKeyboard:
			controller.dismissKeyboard()

		case .switchPage(let newPage):
			ShiftStateMachine.apply(.pageSwitched(to: newPage), to: &state)
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

	private static func handleSpace(state: inout KeyboardState, proxy: any TextDocumentProxying, now: Date) {
		let withinWindow = state.lastSpaceInsertedAt.map { now.timeIntervalSince($0) < doubleSpaceWindow } ?? false
		let isDoubleTap = state.lastInsertWasSpace && withinWindow

		if isDoubleTap {
			// Replace the previous space with ". ".
			proxy.deleteBackward()
			proxy.insertText(". ")
			state.lastInsertWasSpace = true
			// Resetting the timestamp prevents triple-tap from chaining into a second substitution.
			state.lastSpaceInsertedAt = nil
		} else {
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
