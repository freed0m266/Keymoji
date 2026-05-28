import XCTest
@testable import KeyboardCore

@MainActor
final class InputDispatcherTests: XCTestCase {

	private var proxy: MockProxy!
	private var controller: MockController!

	override func setUp() {
		super.setUp()
		proxy = MockProxy()
		controller = MockController()
	}

	// MARK: - Character insertion

	func testInsertLetter_inLowerPage_insertsLowercase() {
		var state = KeyboardState(page: .letters(.lower))
		dispatch(letterKey("a"), &state)
		XCTAssertEqual(proxy.inserted, ["a"])
		XCTAssertEqual(state.page, .letters(.lower))
	}

	func testInsertLetter_inUpperPage_insertsUppercase_andDownshifts() {
		var state = KeyboardState(page: .letters(.upper))
		dispatch(letterKey("a"), &state)
		XCTAssertEqual(proxy.inserted, ["A"])
		XCTAssertEqual(state.page, .letters(.lower))
	}

	func testInsertLetter_inCapsLockPage_insertsUppercase_andStays() {
		var state = KeyboardState(page: .letters(.capsLock))
		dispatch(letterKey("a"), &state)
		XCTAssertEqual(proxy.inserted, ["A"])
		XCTAssertEqual(state.page, .letters(.capsLock))
	}

	func testInsertRawText_bypassesShiftApply() {
		var state = KeyboardState(page: .letters(.upper))
		let key = Key(id: "alt", primary: .text("é"), alternates: [], action: .insertRawText("é"), visualWeight: .standard, role: .character)
		dispatch(key, &state)
		XCTAssertEqual(proxy.inserted, ["é"])
		// Should still downshift after the alternate
		XCTAssertEqual(state.page, .letters(.lower))
	}

	// MARK: - Backspace

	func testBackspace_callsDeleteBackward() {
		var state = KeyboardState()
		let key = makeKey(.backspace)
		dispatch(key, &state)
		XCTAssertEqual(proxy.deleteCount, 1)
	}

	func testBackspace_resetsSpaceTracking() {
		var state = KeyboardState(lastInsertWasSpace: true, lastSpaceInsertedAt: Date())
		dispatch(makeKey(.backspace), &state)
		XCTAssertFalse(state.lastInsertWasSpace)
		XCTAssertNil(state.lastSpaceInsertedAt)
	}

	// MARK: - Word delete

	func testTrailingWordDeleteCount_emptyString_isZero() {
		XCTAssertEqual(InputDispatcher.trailingWordDeleteCount(in: ""), 0)
	}

	func testTrailingWordDeleteCount_singleWord_consumesWord() {
		XCTAssertEqual(InputDispatcher.trailingWordDeleteCount(in: "Hello"), 5)
	}

	func testTrailingWordDeleteCount_trailingSpaces_consumesSpacesAndWord() {
		XCTAssertEqual(InputDispatcher.trailingWordDeleteCount(in: "Hello world   "), 8)
	}

	func testTrailingWordDeleteCount_onlyWhitespace_consumesAll() {
		XCTAssertEqual(InputDispatcher.trailingWordDeleteCount(in: "   "), 3)
	}

	func testTrailingWordDeleteCount_wordWithPrecedingText_consumesOnlyTrailingWord() {
		XCTAssertEqual(InputDispatcher.trailingWordDeleteCount(in: "Hello world"), 5)
	}

	func testTrailingWordDeleteCount_treatsNewlineAsWhitespace() {
		XCTAssertEqual(InputDispatcher.trailingWordDeleteCount(in: "Hello\nworld"), 5)
	}

	func testDeleteWord_removesTrailingWord_andSpace() {
		var state = KeyboardState()
		proxy.documentContextBeforeInput = "Hello world "
		dispatch(makeKey(.deleteWord), &state)
		// "world " — 5 chars + 1 trailing space = 6 deleteBackward calls.
		XCTAssertEqual(proxy.deleteCount, 6)
		XCTAssertEqual(proxy.documentContextBeforeInput, "Hello ")
	}

	func testDeleteWord_atTextEnd_removesWord() {
		var state = KeyboardState()
		proxy.documentContextBeforeInput = "Hello world"
		dispatch(makeKey(.deleteWord), &state)
		XCTAssertEqual(proxy.deleteCount, 5)
		XCTAssertEqual(proxy.documentContextBeforeInput, "Hello ")
	}

	func testDeleteWord_emptyContext_stillDeletesOneChar() {
		// Hidden contexts (password fields) report nil/empty. We still emit one delete so
		// the user feels the key responding to their hold.
		var state = KeyboardState()
		proxy.documentContextBeforeInput = nil
		dispatch(makeKey(.deleteWord), &state)
		XCTAssertEqual(proxy.deleteCount, 1)
	}

	func testDeleteWord_resetsSpaceTracking() {
		var state = KeyboardState(lastInsertWasSpace: true, lastSpaceInsertedAt: Date())
		proxy.documentContextBeforeInput = "hi "
		dispatch(makeKey(.deleteWord), &state)
		XCTAssertFalse(state.lastInsertWasSpace)
		XCTAssertNil(state.lastSpaceInsertedAt)
	}

	// MARK: - Shift simple toggle

	func testShift_fromLowerToUpper() {
		var state = KeyboardState(page: .letters(.lower))
		dispatch(makeKey(.shift), &state)
		XCTAssertEqual(state.page, .letters(.upper))
	}

	func testShift_fromUpperToLower() {
		var state = KeyboardState(page: .letters(.upper))
		dispatch(makeKey(.shift), &state)
		XCTAssertEqual(state.page, .letters(.lower))
	}

	func testShift_fromCapsLockToLower() {
		var state = KeyboardState(page: .letters(.capsLock))
		dispatch(makeKey(.shift), &state)
		XCTAssertEqual(state.page, .letters(.lower))
	}

	func testShift_onSymbolsPage_isNoOp() {
		var state = KeyboardState(page: .symbols(.primary))
		dispatch(makeKey(.shift), &state)
		XCTAssertEqual(state.page, .symbols(.primary))
	}

	// MARK: - Page switching

	func testSwitchPage_toSymbolsPrimary() {
		var state = KeyboardState(page: .letters(.lower))
		dispatch(makeKey(.switchPage(.symbols(.primary))), &state)
		XCTAssertEqual(state.page, .symbols(.primary))
	}

	func testSwitchPage_toSymbolsAlternate() {
		var state = KeyboardState(page: .symbols(.primary))
		dispatch(makeKey(.switchPage(.symbols(.alternate))), &state)
		XCTAssertEqual(state.page, .symbols(.alternate))
	}

	func testSwitchPage_resetsSpaceTracking() {
		var state = KeyboardState(lastInsertWasSpace: true, lastSpaceInsertedAt: Date())
		dispatch(makeKey(.switchPage(.symbols(.primary))), &state)
		XCTAssertFalse(state.lastInsertWasSpace)
		XCTAssertNil(state.lastSpaceInsertedAt)
	}

	// MARK: - Return

	func testReturn_insertsNewline() {
		var state = KeyboardState()
		dispatch(makeKey(.return), &state)
		XCTAssertEqual(proxy.inserted, ["\n"])
	}

	// MARK: - Space (single tap, double tap, triple tap)

	func testSingleSpace_insertsSpace() {
		var state = KeyboardState()
		dispatch(makeKey(.space), &state, now: { Date(timeIntervalSince1970: 1000) })
		XCTAssertEqual(proxy.inserted, [" "])
		XCTAssertTrue(state.lastInsertWasSpace)
	}

	func testDoubleSpaceWithinWindow_replacesWithPeriodSpace() {
		var state = KeyboardState()
		let t0 = Date(timeIntervalSince1970: 1000)
		let t1 = t0.addingTimeInterval(0.3)

		dispatch(makeKey(.space), &state, now: { t0 })
		dispatch(makeKey(.space), &state, now: { t1 })

		XCTAssertEqual(proxy.inserted, [" ", ". "])
		XCTAssertEqual(proxy.deleteCount, 1)
	}

	func testDoubleSpaceOutsideWindow_insertsTwoSeparateSpaces() {
		var state = KeyboardState()
		let t0 = Date(timeIntervalSince1970: 1000)
		let t1 = t0.addingTimeInterval(0.8) // outside 0.5s window

		dispatch(makeKey(.space), &state, now: { t0 })
		dispatch(makeKey(.space), &state, now: { t1 })

		XCTAssertEqual(proxy.inserted, [" ", " "])
		XCTAssertEqual(proxy.deleteCount, 0)
	}

	func testTripleSpace_doesNotDoubleSubstitute() {
		var state = KeyboardState()
		let t0 = Date(timeIntervalSince1970: 1000)
		let t1 = t0.addingTimeInterval(0.2)
		let t2 = t1.addingTimeInterval(0.2)

		dispatch(makeKey(.space), &state, now: { t0 })
		dispatch(makeKey(.space), &state, now: { t1 })
		dispatch(makeKey(.space), &state, now: { t2 })

		// Expect: " " → ". " → " " (third space is normal)
		XCTAssertEqual(proxy.inserted, [" ", ". ", " "])
		XCTAssertEqual(proxy.deleteCount, 1)
	}

	func testSpaceAfterCharacter_doesNotSubstitute() {
		var state = KeyboardState()
		let t0 = Date(timeIntervalSince1970: 1000)
		let t1 = t0.addingTimeInterval(0.1)

		dispatch(makeKey(.space), &state, now: { t0 })
		dispatch(letterKey("a"), &state)
		dispatch(makeKey(.space), &state, now: { t1 })

		// Inserted: " ", "a", " "
		XCTAssertEqual(proxy.inserted, [" ", "a", " "])
		XCTAssertEqual(proxy.deleteCount, 0)
	}

	// MARK: - Space auto-switch back to letters

	func testSpace_onSymbolsPrimary_autoSwitchesToLetters() {
		var state = KeyboardState(page: .symbols(.primary))
		dispatch(makeKey(.space), &state, now: { Date(timeIntervalSince1970: 1000) })
		XCTAssertEqual(proxy.inserted, [" "])
		XCTAssertEqual(state.page, .letters(.lower))
	}

	func testSpace_onSymbolsAlternate_autoSwitchesToLetters() {
		var state = KeyboardState(page: .symbols(.alternate))
		dispatch(makeKey(.space), &state, now: { Date(timeIntervalSince1970: 1000) })
		XCTAssertEqual(proxy.inserted, [" "])
		XCTAssertEqual(state.page, .letters(.lower))
	}

	func testSpace_onLetters_doesNotChangePage() {
		var state = KeyboardState(page: .letters(.lower))
		dispatch(makeKey(.space), &state, now: { Date(timeIntervalSince1970: 1000) })
		XCTAssertEqual(state.page, .letters(.lower))
	}

	func testDoubleSpace_onSymbolsPrimary_substitutesAndSwitches() {
		var state = KeyboardState(page: .symbols(.primary))
		let t0 = Date(timeIntervalSince1970: 1000)
		let t1 = t0.addingTimeInterval(0.3)

		dispatch(makeKey(.space), &state, now: { t0 })
		// First space inserted, page hopped to letters.
		XCTAssertEqual(proxy.inserted, [" "])
		XCTAssertEqual(state.page, .letters(.lower))

		dispatch(makeKey(.space), &state, now: { t1 })
		// Double-tap detection survives the page switch (timestamp/flag tracking intact),
		// so the second space substitutes to ". " and the page stays on letters.
		XCTAssertEqual(proxy.inserted, [" ", ". "])
		XCTAssertEqual(proxy.deleteCount, 1)
		XCTAssertEqual(state.page, .letters(.lower))
	}

	// MARK: - Space double-tap configurable action

	func testDoubleSpace_insertPeriodMode_substitutes() {
		var state = KeyboardState(spaceDoubleTapAction: .insertPeriod)
		let t0 = Date(timeIntervalSince1970: 1000)
		let t1 = t0.addingTimeInterval(0.3)

		dispatch(makeKey(.space), &state, now: { t0 })
		dispatch(makeKey(.space), &state, now: { t1 })

		XCTAssertEqual(proxy.inserted, [" ", ". "])
		XCTAssertEqual(proxy.deleteCount, 1)
		XCTAssertEqual(controller.dismissCount, 0)
	}

	func testDoubleSpace_dismissKeyboardMode_dismissesAndRemovesFirstSpace() {
		var state = KeyboardState(spaceDoubleTapAction: .dismissKeyboard)
		let t0 = Date(timeIntervalSince1970: 1000)
		let t1 = t0.addingTimeInterval(0.3)

		dispatch(makeKey(.space), &state, now: { t0 })
		dispatch(makeKey(.space), &state, now: { t1 })

		// The first space is committed to the document on tap 1; tap 2 deletes it and dismisses.
		// Net effect on the document: no inserted space remains.
		XCTAssertEqual(proxy.inserted, [" "])
		XCTAssertEqual(proxy.deleteCount, 1)
		XCTAssertNil(proxy.documentContextBeforeInput)
		XCTAssertEqual(controller.dismissCount, 1)
	}

	func testDoubleSpace_noneMode_insertsTwoSpaces() {
		var state = KeyboardState(spaceDoubleTapAction: .none)
		let t0 = Date(timeIntervalSince1970: 1000)
		let t1 = t0.addingTimeInterval(0.3)

		dispatch(makeKey(.space), &state, now: { t0 })
		dispatch(makeKey(.space), &state, now: { t1 })

		XCTAssertEqual(proxy.inserted, [" ", " "])
		XCTAssertEqual(proxy.deleteCount, 0)
		XCTAssertEqual(controller.dismissCount, 0)
	}

	func testDoubleSpace_dismissKeyboardMode_outsideWindow_doesNotDismiss() {
		var state = KeyboardState(spaceDoubleTapAction: .dismissKeyboard)
		let t0 = Date(timeIntervalSince1970: 1000)
		let t1 = t0.addingTimeInterval(0.6) // outside 0.5s window

		dispatch(makeKey(.space), &state, now: { t0 })
		dispatch(makeKey(.space), &state, now: { t1 })

		XCTAssertEqual(proxy.inserted, [" ", " "])
		XCTAssertEqual(controller.dismissCount, 0)
	}

	func testDoubleSpace_dismissKeyboardMode_onSymbols_dismissesAndSwitchesToLetters() {
		// On a symbol page, the space-driven auto-switch-to-letters from task 27 runs *after*
		// `handleSpace` regardless of dismiss — keyboards aren't destroyed by dismiss, just hidden,
		// so the next presentation lands on letters (the next-word default).
		var state = KeyboardState(page: .symbols(.primary), spaceDoubleTapAction: .dismissKeyboard)
		let t0 = Date(timeIntervalSince1970: 1000)
		let t1 = t0.addingTimeInterval(0.3)

		dispatch(makeKey(.space), &state, now: { t0 })
		XCTAssertEqual(state.page, .letters(.lower))

		dispatch(makeKey(.space), &state, now: { t1 })
		XCTAssertEqual(controller.dismissCount, 1)
		XCTAssertEqual(proxy.deleteCount, 1)
		XCTAssertEqual(state.page, .letters(.lower))
	}

	// MARK: - Emoji page

	func testSwitchToEmojis_setsEmojiPage() {
		var state = KeyboardState(page: .letters(.lower))
		dispatch(makeKey(.switchPage(.emojis)), &state)
		XCTAssertEqual(state.page, .emojis)
	}

	func testInsertEmoji_onEmojiPage_insertsAndStaysOnEmojis() {
		var state = KeyboardState(page: .emojis)
		let key = Key(
			id: "emoji.😀",
			primary: .text("😀"),
			alternates: [],
			action: .insertText("😀"),
			visualWeight: .standard,
			role: .character
		)
		dispatch(key, &state)
		XCTAssertEqual(proxy.inserted, ["😀"])
		XCTAssertEqual(state.page, .emojis)
	}

	func testSpace_onEmojiPage_doesNotSwitchToLetters() {
		var state = KeyboardState(page: .emojis)
		dispatch(makeKey(.space), &state, now: { Date(timeIntervalSince1970: 1000) })
		XCTAssertEqual(proxy.inserted, [" "])
		XCTAssertEqual(state.page, .emojis)
	}

	func testSwitchFromEmojisBackToLetters_works() {
		var state = KeyboardState(page: .emojis)
		dispatch(makeKey(.switchPage(.letters(.lower))), &state)
		XCTAssertEqual(state.page, .letters(.lower))
	}

	// MARK: - Slack-style emoji substitution

	func testSlackShortcode_completedByClosingColon_replacesWithEmoji() {
		var state = KeyboardState(page: .letters(.lower))
		typeString(":smile", into: &state)
		// Sanity check: nothing has been replaced yet.
		XCTAssertEqual(proxy.documentContextBeforeInput, ":smile")
		// Closing colon triggers the substitution.
		dispatch(letterKey(":"), &state)
		// Final buffer = emoji, no leftover colons.
		XCTAssertEqual(proxy.documentContextBeforeInput, "😄")
		// Backspaces were issued to consume `:smile:` (7 chars).
		XCTAssertEqual(proxy.deleteCount, 7)
	}

	func testSlackShortcode_afterText_preservesPrefix() {
		var state = KeyboardState(page: .letters(.lower))
		proxy.documentContextBeforeInput = "Hello "
		typeString(":fire:", into: &state)
		XCTAssertEqual(proxy.documentContextBeforeInput, "Hello 🔥")
	}

	func testSlackShortcode_unknownCode_leavesTextIntact() {
		var state = KeyboardState(page: .letters(.lower))
		typeString(":notarealcode:", into: &state)
		XCTAssertEqual(proxy.documentContextBeforeInput, ":notarealcode:")
		XCTAssertEqual(proxy.deleteCount, 0)
	}

	func testSlackShortcode_caseInsensitive() {
		var state = KeyboardState(page: .letters(.lower))
		// Force upper page so the dispatcher uppercases inserts; verifies lowercase normalization
		// in the parser is what makes this work, not the dispatcher's casing.
		state.page = .letters(.capsLock)
		typeString(":smile:", into: &state)
		XCTAssertEqual(proxy.documentContextBeforeInput, "😄")
	}

	func testSlackShortcode_onlyFiresOnClosingColon() {
		var state = KeyboardState(page: .letters(.lower))
		// Typing `:smile` (no closing colon) must NOT issue any deleteBackward —
		// the substitution scan should be a no-op until the trailing `:` lands.
		typeString(":smile", into: &state)
		XCTAssertEqual(proxy.deleteCount, 0)
	}

	func testSlackShortcode_addsEmojiToRecents() {
		var state = KeyboardState(page: .letters(.lower), recentEmojis: ["👍"])
		typeString(":smile:", into: &state)
		// Newest first, deduped against any prior occurrence.
		XCTAssertEqual(state.recentEmojis, ["😄", "👍"])
	}

	func testSlackShortcode_dedupesExistingRecent() {
		var state = KeyboardState(page: .letters(.lower), recentEmojis: ["👍", "😄", "🔥"])
		typeString(":smile:", into: &state)
		// Existing "😄" moves to the head rather than appearing twice.
		XCTAssertEqual(state.recentEmojis, ["😄", "👍", "🔥"])
	}

	func testSlackShortcode_recentsRespectCapacity() {
		let prior = (0..<KeyboardState.recentEmojisCapacity).map { "🙂\($0)" }
		var state = KeyboardState(page: .letters(.lower), recentEmojis: prior)
		typeString(":fire:", into: &state)
		XCTAssertEqual(state.recentEmojis.count, KeyboardState.recentEmojisCapacity)
		XCTAssertEqual(state.recentEmojis.first, "🔥")
		// Oldest entry got dropped.
		XCTAssertFalse(state.recentEmojis.contains(prior.last!))
	}

	func testSlackShortcode_unknownCode_leavesRecentsAlone() {
		let prior = ["👍", "🔥"]
		var state = KeyboardState(page: .letters(.lower), recentEmojis: prior)
		typeString(":notarealcode:", into: &state)
		XCTAssertEqual(state.recentEmojis, prior)
	}

	func testSlackShortcode_doubleColonNoChars_noReplacement() {
		var state = KeyboardState(page: .letters(.lower))
		typeString("::", into: &state)
		XCTAssertEqual(proxy.documentContextBeforeInput, "::")
		XCTAssertEqual(proxy.deleteCount, 0)
	}

	// MARK: - Cursor offset (trackpad mode)

	func testCursorOffset_positive_forwardsToProxy() {
		var state = KeyboardState()
		dispatch(makeKey(.cursorOffset(3)), &state)
		XCTAssertEqual(proxy.cursorOffsets, [3])
	}

	func testCursorOffset_negative_forwardsToProxy() {
		var state = KeyboardState()
		dispatch(makeKey(.cursorOffset(-2)), &state)
		XCTAssertEqual(proxy.cursorOffsets, [-2])
	}

	func testCursorOffset_zero_skipsProxyCall() {
		var state = KeyboardState()
		dispatch(makeKey(.cursorOffset(0)), &state)
		XCTAssertTrue(proxy.cursorOffsets.isEmpty)
	}

	func testCursorOffset_resetsSpaceTracking() {
		// Without the reset, a subsequent space tap could be misinterpreted as the second half
		// of a double-space → ". " substitution.
		var state = KeyboardState(lastInsertWasSpace: true, lastSpaceInsertedAt: Date())
		dispatch(makeKey(.cursorOffset(1)), &state)
		XCTAssertFalse(state.lastInsertWasSpace)
		XCTAssertNil(state.lastSpaceInsertedAt)
	}

	func testCursorOffset_doesNotInsertOrDelete() {
		var state = KeyboardState()
		dispatch(makeKey(.cursorOffset(5)), &state)
		XCTAssertTrue(proxy.inserted.isEmpty)
		XCTAssertEqual(proxy.deleteCount, 0)
	}

	// MARK: - Helpers

	private func dispatch(_ key: Key, _ state: inout KeyboardState, now: () -> Date = Date.init) {
		InputDispatcher.dispatch(key: key, state: &state, proxy: proxy, controller: controller, now: now)
	}

	/// Dispatch each character in `string` as a separate `.insertText` key. Mirrors what the user
	/// would do tapping one key at a time and lets integration tests build up real document context.
	private func typeString(_ string: String, into state: inout KeyboardState) {
		for char in string {
			dispatch(letterKey(String(char)), &state)
		}
	}

	private func letterKey(_ char: String) -> Key {
		Key(
			id: "letter.\(char)",
			primary: .text(char),
			alternates: [],
			action: .insertText(char),
			visualWeight: .standard,
			role: .character
		)
	}

	private func makeKey(_ action: KeyAction) -> Key {
		Key(
			id: "test.\(String(describing: action))",
			primary: .text(""),
			alternates: [],
			action: action,
			visualWeight: .standard,
			role: .system
		)
	}
}

// MARK: - Mocks

@MainActor
private final class MockProxy: TextDocumentProxying {
	var documentContextAfterInput: String?
	var inserted: [String] = []
	var deleteCount = 0
	var cursorOffsets: [Int] = []
	/// Running buffer of what's been inserted minus what's been deleted. Lets the dispatcher's
	/// Slack-emoji substitution path read a realistic `documentContextBeforeInput` after each
	/// insert. `insertText` appends; `deleteBackward` drops the trailing `Character`.
	private var buffer = ""

	var documentContextBeforeInput: String? {
		get { buffer.isEmpty ? nil : buffer }
		set { buffer = newValue ?? "" }
	}

	func insertText(_ text: String) {
		inserted.append(text)
		buffer.append(text)
	}

	func deleteBackward() {
		deleteCount += 1
		if !buffer.isEmpty {
			buffer.removeLast()
		}
	}

	func adjustTextPosition(byCharacterOffset offset: Int) {
		cursorOffsets.append(offset)
	}
}

@MainActor
private final class MockController: KeyboardControlling {
	var dismissCount = 0

	func dismissKeyboard() {
		dismissCount += 1
	}
}
