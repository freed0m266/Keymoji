import XCTest
@testable import KeyboardCore

final class CheatCodeDetectorTests: XCTestCase {

	// Derive every fixture from `CheatCodeDetector.code` so these tests survive a keyword change —
	// the whole point of keeping the trigger string in exactly one place.
	private let code = CheatCodeDetector.code

	// MARK: - Matches

	func testMatch_exactSuffix() {
		XCTAssertTrue(CheatCodeDetector.matches(context: code))
		XCTAssertTrue(CheatCodeDetector.matches(context: "go go \(code)"))
	}

	func testMatch_caseInsensitive() {
		XCTAssertTrue(CheatCodeDetector.matches(context: code.uppercased()))
	}

	func testMatch_withTrailingCharactersInsideWindow() {
		// A coalesced textDidChange can append a char/space after the code — still inside the window.
		XCTAssertTrue(CheatCodeDetector.matches(context: "\(code) "))
		XCTAssertTrue(CheatCodeDetector.matches(context: "\(code) h"))
		XCTAssertTrue(CheatCodeDetector.matches(context: "type \(code)!"))
	}

	func testMatch_codeEmbeddedMidWindow() {
		XCTAssertTrue(CheatCodeDetector.matches(context: "x \(code) ok"))
	}

	// MARK: - Non-matches

	func testNoMatch_outsideWindow() {
		// Code followed by more than the slack window of trailing chars → scrolled out of view.
		let trailing = String(repeating: "x", count: CheatCodeDetector.windowLength)
		XCTAssertFalse(CheatCodeDetector.matches(context: code + trailing))
	}

	func testNoMatch_partialPrefix() {
		XCTAssertFalse(CheatCodeDetector.matches(context: String(code.dropLast())))
	}

	func testNoMatch_emptyOrNil() {
		XCTAssertFalse(CheatCodeDetector.matches(context: nil))
		XCTAssertFalse(CheatCodeDetector.matches(context: ""))
	}

	func testWindowLength_isCodePlusSlack() {
		XCTAssertEqual(CheatCodeDetector.windowLength, CheatCodeDetector.code.count + 10)
	}
}
