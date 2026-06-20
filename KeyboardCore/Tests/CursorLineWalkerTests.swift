import XCTest
@testable import KeyboardCore

final class CursorLineWalkerTests: XCTestCase {

	private func offset(_ lines: Int, before: String, after: String) -> Int {
		CursorLineWalker.computeLineJumpOffset(lines: lines, before: before, after: after)
	}

	// MARK: - Up

	func testUp_columnPreserved_whenTargetLineLongEnough() {
		// Cursor after "fg" (column 2); the line above "abcde" is longer, so column 2 survives.
		// Move from position 8 back to position 2 → -6.
		XCTAssertEqual(offset(-1, before: "abcde\nfg", after: ""), -6)
	}

	func testUp_clampsToShorterTargetLine() {
		// Cursor at column 5 on "cdefg"; the line above "ab" is only 2 long → clamp to end-of-line.
		// Move from position 8 back to position 2 (end of "ab") → -6.
		XCTAssertEqual(offset(-1, before: "ab\ncdefg", after: ""), -6)
	}

	func testUp_columnZero_whenCursorRightAfterNewline() {
		// Cursor sits just after the newline (column 0) → lands at the start of the line above.
		XCTAssertEqual(offset(-1, before: "abc\n", after: "def"), -4)
	}

	func testUp_notEnoughNewlines_returnsZero() {
		// No newline above at all.
		XCTAssertEqual(offset(-1, before: "abc", after: "def"), 0)
		// Only one line above, asked to go up two.
		XCTAssertEqual(offset(-2, before: "ab\ncd", after: ""), 0)
	}

	func testUp_multipleLines() {
		// Two lines up from the third line, column 5 preserved on "line1" → position 5, was 17 → -12.
		XCTAssertEqual(offset(-2, before: "line1\nline2\nline3", after: ""), -12)
	}

	// MARK: - Down

	func testDown_columnPreserved_whenTargetLineLongEnough() {
		// Cursor at column 2 ("ab"); the rest of the current line is "cd", the line below "efgh" is
		// long enough to keep column 2 → +5.
		XCTAssertEqual(offset(1, before: "ab", after: "cd\nefgh"), 5)
	}

	func testDown_clampsToShorterTargetLine() {
		// Cursor at column 5 ("abcde"); the line below "h" is only 1 long → clamp to its end → +4.
		XCTAssertEqual(offset(1, before: "abcde", after: "fg\nh"), 4)
	}

	func testDown_columnZero_whenCursorRightAfterNewline() {
		// Column 0 → lands at the start of the line below.
		XCTAssertEqual(offset(1, before: "abc\n", after: "de\nfg"), 3)
	}

	func testDown_notEnoughNewlines_returnsZero() {
		XCTAssertEqual(offset(1, before: "x", after: "abc"), 0)
		XCTAssertEqual(offset(2, before: "x", after: "ab\ncd"), 0)
	}

	// MARK: - Symmetry & edges

	func testUpAndDown_fromSameAnchor() {
		// Cursor at the end of line 2 ("defg", column 4) of the 3-line doc "abc\ndefg\nhij".
		let before = "abc\ndefg"
		let after = "\nhij"
		// Up: column 4 clamps to 3 on "abc" → from position 8 back to position 3 → -5.
		XCTAssertEqual(offset(-1, before: before, after: after), -5)
		// Down: column 4 clamps to 3 on "hij" → end of "hij", 4 chars forward → +4.
		XCTAssertEqual(offset(1, before: before, after: after), 4)
	}

	func testEmptyContexts_returnZero() {
		XCTAssertEqual(offset(-1, before: "", after: ""), 0)
		XCTAssertEqual(offset(1, before: "", after: ""), 0)
	}

	func testZeroLines_returnsZero() {
		XCTAssertEqual(offset(0, before: "abc\ndef", after: "ghi"), 0)
	}
}
