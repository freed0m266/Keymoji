import XCTest
@testable import KeyboardCore

final class AutoCapitalizerTests: XCTestCase {

	// MARK: - Start of document

	func testNilContext_withSentencesType_returnsTrue() {
		XCTAssertTrue(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: nil,
			autocapitalizationType: .sentences
		))
	}

	func testEmptyContext_withSentencesType_returnsTrue() {
		XCTAssertTrue(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "",
			autocapitalizationType: .sentences
		))
	}

	func testWhitespaceOnlyContext_returnsTrue() {
		XCTAssertTrue(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "   \n  ",
			autocapitalizationType: .sentences
		))
	}

	// MARK: - Sentence terminators

	func testAfterPeriodSpace_returnsTrue() {
		XCTAssertTrue(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "Hello. ",
			autocapitalizationType: .sentences
		))
	}

	func testAfterQuestionSpace_returnsTrue() {
		XCTAssertTrue(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "Really? ",
			autocapitalizationType: .sentences
		))
	}

	func testAfterExclamationSpace_returnsTrue() {
		XCTAssertTrue(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "Wow! ",
			autocapitalizationType: .sentences
		))
	}

	func testAfterPeriodWithoutSpace_returnsFalse() {
		XCTAssertFalse(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "Hello.",
			autocapitalizationType: .sentences
		))
	}

	// MARK: - Mid-sentence

	func testMidSentence_returnsFalse() {
		XCTAssertFalse(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "Hello world",
			autocapitalizationType: .sentences
		))
	}

	func testMidSentenceWithTrailingSpace_returnsFalse() {
		XCTAssertFalse(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "Hello ",
			autocapitalizationType: .sentences
		))
	}

	// MARK: - Newlines

	func testAfterDoubleNewline_returnsTrue() {
		XCTAssertTrue(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "First paragraph.\n\n",
			autocapitalizationType: .sentences
		))
	}

	func testAfterSingleNewline_returnsFalse() {
		// Chat apps insert single newlines often; we don't treat them as sentence boundaries.
		XCTAssertFalse(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "First line\n",
			autocapitalizationType: .sentences
		))
	}

	// MARK: - Disabled types

	func testNoneType_alwaysReturnsFalse() {
		XCTAssertFalse(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "Hello. ",
			autocapitalizationType: .none
		))
		XCTAssertFalse(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: nil,
			autocapitalizationType: .none
		))
	}

	func testWordsType_isTreatedAsNone_inV1() {
		// v1.0 doesn't support `.words` — treat as no-op.
		XCTAssertFalse(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "Hello. ",
			autocapitalizationType: .words
		))
	}

	func testAllCharactersType_isTreatedAsNone_inV1() {
		XCTAssertFalse(AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: "Hello. ",
			autocapitalizationType: .allCharacters
		))
	}
}
