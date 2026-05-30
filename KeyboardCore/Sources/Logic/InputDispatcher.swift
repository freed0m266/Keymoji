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
		learning: LearningHook? = nil,
		now: () -> Date = Date.init
	) {
		// Emoji search has its own input pipeline: characters/space/backspace mutate the
		// in-memory query buffer instead of the host document. Routed here so every action
		// case can short-circuit cleanly without sprinkling `if state.page.isEmojiSearch`
		// checks across the regular handling branches. Covers both the QWERTY sub-page
		// (`.emojiSearch`) and the numbers/symbols sub-page (`.emojiSearchSymbols`).
		if state.page.isEmojiSearch, handleEmojiSearchInput(key: key, state: &state) {
			return
		}

		switch key.action {
		case .insertText(let text):
			let shifted = textWithShiftApplied(text, state: state)
			proxy.insertText(shifted)
			ShiftStateMachine.apply(.characterInserted, to: &state)
			updateSpaceTracking(insertedText: shifted, state: &state)
			applySlackEmojiSubstitutionIfNeeded(justInserted: shifted, state: &state, proxy: proxy)
			learnIfWordBoundary(insertedText: shifted, state: state, proxy: proxy, learning: learning)

		case .insertRawText(let text):
			// Long-press alternates ship already-cased text; skip shift apply.
			proxy.insertText(text)
			ShiftStateMachine.apply(.characterInserted, to: &state)
			updateSpaceTracking(insertedText: text, state: &state)
			applySlackEmojiSubstitutionIfNeeded(justInserted: text, state: &state, proxy: proxy)
			learnIfWordBoundary(insertedText: text, state: state, proxy: proxy, learning: learning)

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
			// A space commits the preceding word — learn it before the page may hop below.
			learnIfWordBoundary(insertedText: " ", state: state, proxy: proxy, learning: learning)
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
			// Leaving the search context (e.g. `×` clears search → `.emojis`) drops the
			// buffer so a fresh entry into search starts blank. The `123` / `ABC` toggle
			// hops between `.emojiSearch` and `.emojiSearchSymbols` — both still count as
			// in-search, so the query buffer survives those transitions.
			if state.page.isEmojiSearch, !newPage.isEmojiSearch {
				state.searchQuery = ""
			}
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

		case .suggestionAccept(_, let replacementText):
			// Replace the in-progress word with the chosen completion + a trailing space (SH3).
			if let prefix = WordPrefixExtractor.activeWordPrefix(
				before: proxy.documentContextBeforeInput,
				after: proxy.documentContextAfterInput
			) {
				for _ in 0..<prefix.count {
					proxy.deleteBackward()
				}
			}
			// `replacementText` is already WYSIWYG-cased by the provider — insert verbatim, no
			// shift-apply. The trailing space matches stock predictive-bar behavior.
			proxy.insertText(replacementText + " ")
			ShiftStateMachine.apply(.characterInserted, to: &state)
			// Mirror a normal space insertion so double-tap-space → ". " still works afterward.
			state.lastInsertWasSpace = true
			state.lastSpaceInsertedAt = now()
		}
	}

	// MARK: - Emoji search mode

	/// Routes a tap in `.emojiSearch` mode. Returns `true` when the action was handled and
	/// the regular pipeline should be skipped. Returns `false` for actions the search-mode
	/// path doesn't own (e.g. switching pages back to letters via the view-layer `×`, or
	/// inserting an emoji glyph from the results bar), so the caller can fall through to
	/// default handling.
	private static func handleEmojiSearchInput(key: Key, state: inout KeyboardState) -> Bool {
		// Emoji glyph taps from the results bar travel as `.insertText` actions on synthetic
		// keys whose IDs start with `emoji.`. They must reach the host document proxy, not
		// the query buffer — so fall through to the regular insertion path and let the
		// controller's `recordRecentEmojiIfNeeded` bump the glyph into recents.
		if key.id.hasPrefix("emoji.") {
			return false
		}

		switch key.action {
		case .insertText(let text), .insertRawText(let text):
			// Lowercase so the buffer mirrors what `EmojiSearchIndex` expects after its own
			// `lowercased()` — and so a future case-toggling shift never desyncs the buffer.
			state.searchQuery.append(text.lowercased())
			return true

		case .space:
			state.searchQuery.append(" ")
			return true

		case .backspace:
			// Don't mutate host text from search mode — silently swallow when the buffer
			// is already empty. Pressing × in the search bar is the proper exit.
			if !state.searchQuery.isEmpty {
				state.searchQuery.removeLast()
			}
			return true

		case .deleteWord:
			// v1 simplification (task 39 §6): long-press backspace doesn't escalate in
			// search mode. Treat it as a single character delete to keep behaviour
			// predictable if the keyboard ever dispatches a `.deleteWord` through here.
			if !state.searchQuery.isEmpty {
				state.searchQuery.removeLast()
			}
			return true

		case .switchPage:
			// Page transitions (e.g. `×` clears search → `.emojis`) flow through the regular
			// path so `ShiftStateMachine` resets `lastShiftTapAt` consistently. The view
			// layer is responsible for clearing `searchQuery` when leaving the mode.
			return false

		case .shift, .return, .dismissKeyboard, .cursorOffset, .suggestionAccept:
			// None of these are meaningful in search mode; swallow so a stray keypress
			// can't fire `return` into the host or toggle shift state. (The suggestion bar is
			// suppressed in search mode anyway, so `.suggestionAccept` shouldn't arrive here.)
			return true
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

	// MARK: - Personal recents learning

	/// Word-boundary characters that commit the preceding word into the recents pool: a space or
	/// sentence punctuation. Hyphen/colon/etc. are intentionally excluded (they don't end a word
	/// for learning purposes any more than they do for completion).
	private static let learningBoundaries: Set<String> = [" ", ".", ",", "!", "?"]

	/// After a word-boundary keystroke, learn the just-completed word — but only in prose fields.
	/// Email fields learn the whole field elsewhere (`KeyboardViewController`), and `.denied`
	/// fields never learn. No-op when `learning` is absent (tests, previews).
	private static func learnIfWordBoundary(
		insertedText: String,
		state: KeyboardState,
		proxy: any TextDocumentProxying,
		learning: LearningHook?
	) {
		guard let learning, state.currentEligibility.learningContext == .prose else { return }
		guard learningBoundaries.contains(insertedText) else { return }
		let context = proxy.documentContextBeforeInput ?? ""
		// Learn only when this boundary directly terminates a word — i.e. the character right before
		// the just-typed trailing boundary is itself a word character. Without this, a *second*
		// boundary re-learns the same word: double-space → ". " (default action), "word  ", or
		// "word. " would each count the word twice and skew ranking.
		let chars = Array(context)
		guard chars.count >= 2, WordPrefixExtractor.isWordCharacter(chars[chars.count - 2]) else { return }
		guard let word = WordPrefixExtractor.lastCompletedWord(in: context) else { return }
		learning.learn(word, .prose)
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

/// Side-effecting hook the dispatcher invokes to learn a word into the personal recents pool.
/// Wrapping the closure in a named type keeps the learning dependency explicit (and injectable for
/// tests) instead of leaking `PersonalRecentsStore` into the pure dispatcher signature.
public struct LearningHook: Sendable {
	private let handler: @MainActor (String, TextContextType) -> Void

	public init(_ handler: @escaping @MainActor (String, TextContextType) -> Void) {
		self.handler = handler
	}

	@MainActor
	func learn(_ word: String, _ context: TextContextType) {
		handler(word, context)
	}
}
