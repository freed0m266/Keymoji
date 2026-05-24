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
}
