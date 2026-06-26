import XCTest
@testable import KeyboardCore

final class AutoCapitalizerTests: XCTestCase {

	// MARK: - Start of document

	func testNilContext_withSentencesType_returnsTrue() {
		XCTAssertTrue(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: nil,
			autocapitalizationType: .sentences,
			enabled: true
		))
	}

	func testEmptyContext_withSentencesType_returnsTrue() {
		XCTAssertTrue(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "",
			autocapitalizationType: .sentences,
			enabled: true
		))
	}

	func testWhitespaceOnlyContext_returnsTrue() {
		XCTAssertTrue(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "   \n  ",
			autocapitalizationType: .sentences,
			enabled: true
		))
	}

	// MARK: - Sentence terminators

	func testAfterPeriodSpace_returnsTrue() {
		XCTAssertTrue(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "Hello. ",
			autocapitalizationType: .sentences,
			enabled: true
		))
	}

	func testAfterQuestionSpace_returnsTrue() {
		XCTAssertTrue(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "Really? ",
			autocapitalizationType: .sentences,
			enabled: true
		))
	}

	func testAfterExclamationSpace_returnsTrue() {
		XCTAssertTrue(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "Wow! ",
			autocapitalizationType: .sentences,
			enabled: true
		))
	}

	func testAfterPeriodWithoutSpace_returnsFalse() {
		XCTAssertFalse(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "Hello.",
			autocapitalizationType: .sentences,
			enabled: true
		))
	}

	// MARK: - Mid-sentence

	func testMidSentence_returnsFalse() {
		XCTAssertFalse(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "Hello world",
			autocapitalizationType: .sentences,
			enabled: true
		))
	}

	func testMidSentenceWithTrailingSpace_returnsFalse() {
		XCTAssertFalse(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "Hello ",
			autocapitalizationType: .sentences,
			enabled: true
		))
	}

	// MARK: - Newlines

	func testAfterDoubleNewline_returnsTrue() {
		XCTAssertTrue(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "First paragraph.\n\n",
			autocapitalizationType: .sentences,
			enabled: true
		))
	}

	func testAfterSingleNewline_returnsFalse() {
		// Chat apps insert single newlines often; we don't treat them as sentence boundaries.
		XCTAssertFalse(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "First line\n",
			autocapitalizationType: .sentences,
			enabled: true
		))
	}

	// MARK: - Disabled types

	func testNoneType_alwaysReturnsFalse() {
		XCTAssertFalse(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "Hello. ",
			autocapitalizationType: .none,
			enabled: true
		))
		XCTAssertFalse(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: nil,
			autocapitalizationType: .none,
			enabled: true
		))
	}

	func testWordsType_isTreatedAsNone_inV1() {
		// v1.0 doesn't support `.words` — treat as no-op.
		XCTAssertFalse(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "Hello. ",
			autocapitalizationType: .words,
			enabled: true
		))
	}

	func testAllCharactersType_isTreatedAsNone_inV1() {
		XCTAssertFalse(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "Hello. ",
			autocapitalizationType: .allCharacters,
			enabled: true
		))
	}

	// MARK: - Master toggle (task 85)

	func testDisabled_neverCapitalizes_evenWithSentenceTrigger() {
		// Master toggle off wins over every trigger and a `.sentences` field.
		XCTAssertFalse(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "Hello. ",
			autocapitalizationType: .sentences,
			enabled: false
		))
		XCTAssertFalse(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "Really? ",
			autocapitalizationType: .sentences,
			enabled: false
		))
		XCTAssertFalse(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "Wow! ",
			autocapitalizationType: .sentences,
			enabled: false
		))
	}

	func testDisabled_neverCapitalizes_atDocumentStart() {
		// Even the start-of-field trigger is suppressed when the toggle is off.
		XCTAssertFalse(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: nil,
			autocapitalizationType: .sentences,
			enabled: false
		))
	}

	// MARK: - applyAutoCapitalization page flip

	func testApply_onTrigger_promotesLowerToUpper_andFlagsAutoCapitalized() {
		var state = KeyboardState(page: .letters(.lower))
		let changed = AutoCapitalizer.applyAutoCapitalization(
			to: &state,
			documentContextBeforeInput: "Hello. ",
			autocapitalizationType: .sentences,
			enabled: true
		)
		XCTAssertTrue(changed)
		XCTAssertEqual(state.page, .letters(.upper))
		XCTAssertTrue(state.autoCapitalized)
	}

	func testApply_disabled_doesNotPromote() {
		var state = KeyboardState(page: .letters(.lower))
		let changed = AutoCapitalizer.applyAutoCapitalization(
			to: &state,
			documentContextBeforeInput: "Hello. ",
			autocapitalizationType: .sentences,
			enabled: false
		)
		XCTAssertFalse(changed)
		XCTAssertEqual(state.page, .letters(.lower))
		XCTAssertFalse(state.autoCapitalized)
	}

	func testApply_offTrigger_revertsPriorAutoPromotion() {
		// A prior auto-promotion (autoCapitalized == true) reverts to lower once the trigger is gone.
		var state = KeyboardState(page: .letters(.upper), autoCapitalized: true)
		let changed = AutoCapitalizer.applyAutoCapitalization(
			to: &state,
			documentContextBeforeInput: "Hi",
			autocapitalizationType: .sentences,
			enabled: true
		)
		XCTAssertTrue(changed)
		XCTAssertEqual(state.page, .letters(.lower))
		XCTAssertFalse(state.autoCapitalized)
	}

	func testApply_offTrigger_leavesManualShiftUntouched() {
		// A manual shift (autoCapitalized == false) must not be reverted by auto-cap.
		var state = KeyboardState(page: .letters(.upper), autoCapitalized: false)
		let changed = AutoCapitalizer.applyAutoCapitalization(
			to: &state,
			documentContextBeforeInput: "Hi",
			autocapitalizationType: .sentences,
			enabled: true
		)
		XCTAssertFalse(changed)
		XCTAssertEqual(state.page, .letters(.upper))
	}

	func testApply_neverTouchesNumericPage() {
		var state = KeyboardState(page: .numeric(.decimal))
		let changed = AutoCapitalizer.applyAutoCapitalization(
			to: &state,
			documentContextBeforeInput: nil,
			autocapitalizationType: .sentences,
			enabled: true
		)
		XCTAssertFalse(changed)
		XCTAssertEqual(state.page, .numeric(.decimal))
	}
}
