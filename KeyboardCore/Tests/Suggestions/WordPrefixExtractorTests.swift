import XCTest
@testable import KeyboardCore

final class WordPrefixExtractorTests: XCTestCase {

	// MARK: - activeWordPrefix

	func testEndOfWord_returnsTrailingRun() {
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "Hello wor", after: nil), "wor")
	}

	func testSingleWord_returnsWholeWord() {
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "hel", after: nil), "hel")
	}

	func testApostrophe_isWordCharacter() {
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "don'", after: nil), "don'")
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "it's", after: nil), "it's")
	}

	func testHyphen_isBoundary() {
		// "well-kno" → only the run after the hyphen counts.
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "well-kno", after: nil), "kno")
	}

	func testDigits_areWordCharacters() {
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "ipv6", after: nil), "ipv6")
	}

	func testDiacritics_areWordCharacters() {
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "café", after: nil), "café")
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "naï", after: nil), "naï")
	}

	func testTrailingBoundary_returnsNil() {
		XCTAssertNil(WordPrefixExtractor.activeWordPrefix(before: "Hello ", after: nil))
		XCTAssertNil(WordPrefixExtractor.activeWordPrefix(before: "Hello.", after: nil))
		XCTAssertNil(WordPrefixExtractor.activeWordPrefix(before: "(", after: nil))
	}

	func testEmptyOrNil_returnsNil() {
		XCTAssertNil(WordPrefixExtractor.activeWordPrefix(before: "", after: nil))
		XCTAssertNil(WordPrefixExtractor.activeWordPrefix(before: nil, after: nil))
	}

	func testMidWordCursor_returnsNil() {
		// Caret between "hel" and "lo" — completing here would mangle the tail.
		XCTAssertNil(WordPrefixExtractor.activeWordPrefix(before: "hel", after: "lo"))
	}

	func testCursorBeforeBoundary_isNotMidWord() {
		// Caret after "hel" with a space following is a legitimate completion point.
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "hel", after: " world"), "hel")
	}

	func testColonBoundary_stripsLeadingColon() {
		// `:` is a boundary, so a Slack-context buffer yields the bare shortcode prefix (the
		// coordinator's Slack-priority rule is what actually suppresses word completions here).
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: ":sm", after: nil), "sm")
	}

	// MARK: - lastCompletedWord

	func testLastCompletedWord_afterSpace() {
		XCTAssertEqual(WordPrefixExtractor.lastCompletedWord(in: "Hello world "), "world")
	}

	func testLastCompletedWord_afterPunctuation() {
		XCTAssertEqual(WordPrefixExtractor.lastCompletedWord(in: "Hello world."), "world")
		XCTAssertEqual(WordPrefixExtractor.lastCompletedWord(in: "Wait, "), "Wait")
	}

	func testLastCompletedWord_noTrailingBoundary_returnsTrailingWord() {
		XCTAssertEqual(WordPrefixExtractor.lastCompletedWord(in: "Hello world"), "world")
	}

	func testLastCompletedWord_onlyBoundaries_returnsNil() {
		XCTAssertNil(WordPrefixExtractor.lastCompletedWord(in: " . "))
		XCTAssertNil(WordPrefixExtractor.lastCompletedWord(in: ""))
		XCTAssertNil(WordPrefixExtractor.lastCompletedWord(in: nil))
	}

	func testLastCompletedWord_preservesApostropheAndDiacritics() {
		XCTAssertEqual(WordPrefixExtractor.lastCompletedWord(in: "don't "), "don't")
		XCTAssertEqual(WordPrefixExtractor.lastCompletedWord(in: "café "), "café")
	}
}
