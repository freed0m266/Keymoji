import XCTest
@testable import KeyboardCore

@MainActor
final class ShiftStateMachineTests: XCTestCase {

	private let baseDate = Date(timeIntervalSince1970: 1_000_000)

	// MARK: - Lower → Upper

	func testLower_shiftTapped_goesToUpper() {
		let state = ShiftStateMachine.State(page: .letters(.lower))
		let next = ShiftStateMachine.reduce(state, .shiftTapped(at: baseDate))
		XCTAssertEqual(next.page, .letters(.upper))
		XCTAssertEqual(next.lastShiftTapAt, baseDate)
	}

	// MARK: - Upper → Lower (single tap, no recent prior tap)

	func testUpper_shiftTappedWithNoHistory_goesToLower() {
		let state = ShiftStateMachine.State(page: .letters(.upper), lastShiftTapAt: nil)
		let next = ShiftStateMachine.reduce(state, .shiftTapped(at: baseDate))
		XCTAssertEqual(next.page, .letters(.lower))
	}

	// MARK: - Upper → Caps lock (double tap)

	func testUpper_shiftTappedWithinWindow_goesToCapsLock() {
		let firstTap = baseDate
		let secondTap = baseDate.addingTimeInterval(0.3) // within 0.4s window
		let state = ShiftStateMachine.State(page: .letters(.upper), lastShiftTapAt: firstTap)

		let next = ShiftStateMachine.reduce(state, .shiftTapped(at: secondTap))
		XCTAssertEqual(next.page, .letters(.capsLock))
	}

	func testUpper_shiftTappedOutsideWindow_goesToLower() {
		let firstTap = baseDate
		let secondTap = baseDate.addingTimeInterval(0.6) // outside 0.4s window
		let state = ShiftStateMachine.State(page: .letters(.upper), lastShiftTapAt: firstTap)

		let next = ShiftStateMachine.reduce(state, .shiftTapped(at: secondTap))
		XCTAssertEqual(next.page, .letters(.lower))
	}

	// MARK: - Caps lock → Lower

	func testCapsLock_shiftTapped_goesToLower() {
		let state = ShiftStateMachine.State(page: .letters(.capsLock))
		let next = ShiftStateMachine.reduce(state, .shiftTapped(at: baseDate))
		XCTAssertEqual(next.page, .letters(.lower))
	}

	// MARK: - Character inserted

	func testUpper_characterInserted_downshiftsToLower() {
		let state = ShiftStateMachine.State(page: .letters(.upper), lastShiftTapAt: baseDate)
		let next = ShiftStateMachine.reduce(state, .characterInserted)
		XCTAssertEqual(next.page, .letters(.lower))
	}

	func testCapsLock_characterInserted_staysInCapsLock() {
		let state = ShiftStateMachine.State(page: .letters(.capsLock))
		let next = ShiftStateMachine.reduce(state, .characterInserted)
		XCTAssertEqual(next.page, .letters(.capsLock))
	}

	func testLower_characterInserted_staysInLower() {
		let state = ShiftStateMachine.State(page: .letters(.lower))
		let next = ShiftStateMachine.reduce(state, .characterInserted)
		XCTAssertEqual(next.page, .letters(.lower))
	}

	// MARK: - Page switch

	func testPageSwitched_resetsLastShiftTapAt() {
		let state = ShiftStateMachine.State(page: .letters(.upper), lastShiftTapAt: baseDate)
		let next = ShiftStateMachine.reduce(state, .pageSwitched(to: .symbols(.primary)))
		XCTAssertEqual(next.page, .symbols(.primary))
		XCTAssertNil(next.lastShiftTapAt)
	}

	// MARK: - Symbols page shift is no-op

	func testSymbols_shiftTapped_doesNothing() {
		let state = ShiftStateMachine.State(page: .symbols(.primary), lastShiftTapAt: nil)
		let next = ShiftStateMachine.reduce(state, .shiftTapped(at: baseDate))
		XCTAssertEqual(next.page, .symbols(.primary))
		XCTAssertNil(next.lastShiftTapAt) // unchanged, since we didn't act
	}

	// MARK: - apply(_:to:) bridge

	func testApply_bridgesFromKeyboardStateAndBack() {
		var state = KeyboardState(page: .letters(.lower), lastShiftTapAt: nil)
		ShiftStateMachine.apply(.shiftTapped(at: baseDate), to: &state)
		XCTAssertEqual(state.page, .letters(.upper))
		XCTAssertEqual(state.lastShiftTapAt, baseDate)
	}

	func testApply_pageSwitch_clearsShiftHistory() {
		var state = KeyboardState(page: .letters(.upper), lastShiftTapAt: baseDate)
		ShiftStateMachine.apply(.pageSwitched(to: .symbols(.primary)), to: &state)
		XCTAssertEqual(state.page, .symbols(.primary))
		XCTAssertNil(state.lastShiftTapAt)
	}

	// MARK: - Full double-tap sequence integration

	func testDoubleTapSequence_lowerToUpperToCapsLock() {
		var state = KeyboardState()
		let t0 = baseDate
		let t1 = baseDate.addingTimeInterval(0.2)

		ShiftStateMachine.apply(.shiftTapped(at: t0), to: &state)
		XCTAssertEqual(state.page, .letters(.upper))

		ShiftStateMachine.apply(.shiftTapped(at: t1), to: &state)
		XCTAssertEqual(state.page, .letters(.capsLock))
	}

	func testCapsLockExits_capsLockToLowerOnSingleTap() {
		var state = KeyboardState(page: .letters(.capsLock), lastShiftTapAt: baseDate.addingTimeInterval(-2))
		ShiftStateMachine.apply(.shiftTapped(at: baseDate), to: &state)
		XCTAssertEqual(state.page, .letters(.lower))
	}

	// MARK: - Empty-field caps lock (auto-cap upper → lower → caps lock, task 65)

	func testEmptyField_doubleTapFromAutoCapUpper_reachesCapsLock() {
		// An empty auto-capitalized field starts on `.upper` with no shift history (auto-cap doesn't
		// record a tap). Two quick taps must still latch caps lock: tap1 bounces to `.lower` seeding
		// the clock, tap2 within the window collapses to caps lock.
		var state = KeyboardState(page: .letters(.upper), lastShiftTapAt: nil)
		let t0 = baseDate
		let t1 = baseDate.addingTimeInterval(0.2)

		ShiftStateMachine.apply(.shiftTapped(at: t0), to: &state)
		XCTAssertEqual(state.page, .letters(.lower))
		XCTAssertEqual(state.lastShiftTapAt, t0, "the first tap seeds the double-tap clock")

		ShiftStateMachine.apply(.shiftTapped(at: t1), to: &state)
		XCTAssertEqual(state.page, .letters(.capsLock))
	}

	// MARK: - capsLock → lower clears the double-tap clock

	func testCapsLockToLower_clearsClock_nextQuickTapIsUpperNotCapsLock() {
		var state = KeyboardState(page: .letters(.capsLock), lastShiftTapAt: baseDate)
		let exitTap = baseDate.addingTimeInterval(1)       // leaves caps lock
		let quickTap = exitTap.addingTimeInterval(0.1)     // well inside the window

		ShiftStateMachine.apply(.shiftTapped(at: exitTap), to: &state)
		XCTAssertEqual(state.page, .letters(.lower))
		XCTAssertNil(state.lastShiftTapAt, "exiting caps lock resets the clock")

		ShiftStateMachine.apply(.shiftTapped(at: quickTap), to: &state)
		XCTAssertEqual(state.page, .letters(.upper), "a quick re-tap is one-shot upper, not caps lock")
	}

	// MARK: - Character insertion clears the double-tap clock

	func testCharacterInserted_clearsClock_preventsAccidentalCapsLock() {
		// shift → type a letter → quick shift again must be one-shot upper, not caps lock: the two
		// shift taps aren't consecutive (a character intervened), so they aren't a double-tap.
		var state = KeyboardState(page: .letters(.lower))
		let t0 = baseDate
		ShiftStateMachine.apply(.shiftTapped(at: t0), to: &state)
		XCTAssertEqual(state.page, .letters(.upper))

		ShiftStateMachine.apply(.characterInserted, to: &state)
		XCTAssertEqual(state.page, .letters(.lower))
		XCTAssertNil(state.lastShiftTapAt, "an inserted character clears the double-tap clock")

		ShiftStateMachine.apply(.shiftTapped(at: t0.addingTimeInterval(0.2)), to: &state)
		XCTAssertEqual(state.page, .letters(.upper), "not caps lock — the taps weren't consecutive")
	}
}
