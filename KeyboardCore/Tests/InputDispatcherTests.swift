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

	// MARK: - Next keyboard

	func testNextKeyboard_callsController() {
		var state = KeyboardState()
		dispatch(makeKey(.nextKeyboard), &state)
		XCTAssertEqual(controller.advanceCount, 1)
	}

	// MARK: - Helpers

	private func dispatch(_ key: Key, _ state: inout KeyboardState, now: () -> Date = Date.init) {
		InputDispatcher.dispatch(key: key, state: &state, proxy: proxy, controller: controller, now: now)
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
	var documentContextBeforeInput: String?
	var documentContextAfterInput: String?
	var inserted: [String] = []
	var deleteCount = 0

	func insertText(_ text: String) {
		inserted.append(text)
	}

	func deleteBackward() {
		deleteCount += 1
	}
}

@MainActor
private final class MockController: KeyboardControlling {
	var advanceCount = 0
	var dismissCount = 0

	func advanceToNextInputMode() {
		advanceCount += 1
	}

	func dismissKeyboard() {
		dismissCount += 1
	}
}
