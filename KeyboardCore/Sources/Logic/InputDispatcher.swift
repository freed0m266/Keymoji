import Foundation

/// Pure-logic input dispatcher. Routes `Key` taps to the text proxy and updates `KeyboardState`.
/// `now` is injectable so the double-tap-space window can be tested deterministically.
///
/// `@MainActor` because callees (`TextDocumentProxying`, `KeyboardControlling`) are main-isolated.
@MainActor
public enum InputDispatcher {

	/// Window within which two space taps collapse into ". ". Matches Apple-like behavior.
	public static let doubleSpaceWindow: TimeInterval = 0.5

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
			downshiftAfterCharacter(state: &state)
			updateSpaceTracking(insertedText: shifted, state: &state)

		case .insertRawText(let text):
			// Long-press alternates ship already-cased text; skip shift apply.
			proxy.insertText(text)
			downshiftAfterCharacter(state: &state)
			updateSpaceTracking(insertedText: text, state: &state)

		case .backspace:
			proxy.deleteBackward()
			state.lastInsertWasSpace = false
			state.lastSpaceInsertedAt = nil

		case .shift:
			// Simple 1-tap toggle. Task 05 replaces this with the full state machine + caps lock.
			toggleShiftSimple(state: &state)

		case .space:
			handleSpace(state: &state, proxy: proxy, now: now())

		case .return:
			proxy.insertText("\n")
			state.lastInsertWasSpace = false
			state.lastSpaceInsertedAt = nil

		case .nextKeyboard:
			controller.advanceToNextInputMode()

		case .dismissKeyboard:
			controller.dismissKeyboard()

		case .switchPage(let newPage):
			state.page = newPage
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

	private static func downshiftAfterCharacter(state: inout KeyboardState) {
		// `.upper` is one-shot — return to `.lower` after a character.
		// `.capsLock` stays sticky. `.symbols` doesn't carry shift.
		if case .letters(.upper) = state.page {
			state.page = .letters(.lower)
		}
	}

	private static func toggleShiftSimple(state: inout KeyboardState) {
		switch state.page {
		case .letters(.lower):     state.page = .letters(.upper)
		case .letters(.upper):     state.page = .letters(.lower)
		case .letters(.capsLock):  state.page = .letters(.lower)
		case .symbols:             break    // shift has no meaning on symbols page
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
}
