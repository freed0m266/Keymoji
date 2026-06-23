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

	func testAllDigits_isAWord() {
		// Task 74: numbers tokenize as whole words (years, phones).
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "2026", after: nil), "2026")
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "Call 604", after: nil), "604")
	}

	func testAlphanumericNick_isAWord() {
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "freedom266", after: nil), "freedom266")
	}

	func testLeadingPlus_isBoundary_phoneTokenizesWithoutIt() {
		// A leading `+` (phone country-code marker) is a word boundary, so the token is the digits
		// alone — `+420604731026` learns/offers as `420604731026` (task 74 decision).
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "+420604731026", after: nil), "420604731026")
		XCTAssertEqual(WordPrefixExtractor.lastCompletedWord(in: "+420604731026 "), "420604731026")
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

	// MARK: - trailingEmail (prose whole-email capture)

	func testTrailingEmail_detectsAddressAtEnd() {
		XCTAssertEqual(WordPrefixExtractor.trailingEmail(in: "email me at martin@gmail.com"), "martin@gmail.com")
		XCTAssertEqual(WordPrefixExtractor.trailingEmail(in: "martin@gmail.com"), "martin@gmail.com")
	}

	func testTrailingEmail_ignoresTrailingBoundaryAndPunctuation() {
		XCTAssertEqual(WordPrefixExtractor.trailingEmail(in: "at martin@gmail.com "), "martin@gmail.com")
		XCTAssertEqual(WordPrefixExtractor.trailingEmail(in: "at martin@gmail.com."), "martin@gmail.com")
		XCTAssertEqual(WordPrefixExtractor.trailingEmail(in: "(martin@gmail.com)"), "martin@gmail.com")
	}

	func testTrailingEmail_multiLevelTLDandRichLocalPart() {
		XCTAssertEqual(WordPrefixExtractor.trailingEmail(in: "x martin@company.co.uk"), "martin@company.co.uk")
		XCTAssertEqual(WordPrefixExtractor.trailingEmail(in: "martin.svoboda026+tag@gmail.com"), "martin.svoboda026+tag@gmail.com")
	}

	func testTrailingEmail_nilForNonEmails() {
		XCTAssertNil(WordPrefixExtractor.trailingEmail(in: "this is e.g. a sentence"))
		XCTAssertNil(WordPrefixExtractor.trailingEmail(in: "foo.bar baz"))
		XCTAssertNil(WordPrefixExtractor.trailingEmail(in: "U.S.A."))
		XCTAssertNil(WordPrefixExtractor.trailingEmail(in: "martin@gmail"), "no TLD → not an address")
		XCTAssertNil(WordPrefixExtractor.trailingEmail(in: ""))
		XCTAssertNil(WordPrefixExtractor.trailingEmail(in: nil))
	}

	func testTrailingEmail_nilWhenEmailIsNotTrailing() {
		// An address earlier in the text isn't returned when the text doesn't END with one — the prose
		// path captures it at the boundary right after the address instead.
		XCTAssertNil(WordPrefixExtractor.trailingEmail(in: "martin@gmail.com is my address"))
	}
}
