import XCTest
@testable import KeyboardCore

final class SlackEmojiSuggesterTests: XCTestCase {

	private let table: [String: String] = [
		"smile":          "😄",
		"smiley":         "😃",
		"smirk":          "😏",
		"smiling_imp":    "😈",
		"smoking":        "🚬",
		"fire":           "🔥",
		"thumbsup":       "👍"
	]

	// MARK: - Activation

	func testEmptyContext_returnsEmpty() {
		XCTAssertEqual(SlackEmojiSuggester.suggestions(forContext: "", table: table), [])
		XCTAssertEqual(SlackEmojiSuggester.suggestions(forContext: nil, table: table), [])
	}

	func testNoColon_returnsEmpty() {
		XCTAssertEqual(SlackEmojiSuggester.suggestions(forContext: "smi", table: table), [])
	}

	func testColonOnly_returnsEmpty() {
		// Just `:` is below min prefix length of 2.
		XCTAssertEqual(SlackEmojiSuggester.suggestions(forContext: ":", table: table), [])
	}

	func testColonPlusOneChar_returnsEmpty() {
		// `:s` is also below min prefix length of 2.
		XCTAssertEqual(SlackEmojiSuggester.suggestions(forContext: ":s", table: table), [])
	}

	func testColonPlusTwoChars_activates() {
		let results = SlackEmojiSuggester.suggestions(forContext: ":sm", table: table)
		XCTAssertFalse(results.isEmpty)
	}

	// MARK: - Word boundary

	func testNoWordBoundary_returnsEmpty() {
		// `Hello:smi` — opening `:` is glued to `o`, not preceded by whitespace.
		XCTAssertEqual(SlackEmojiSuggester.suggestions(forContext: "Hello:smi", table: table), [])
	}

	func testAtStartOfDocument_activates() {
		let results = SlackEmojiSuggester.suggestions(forContext: ":smi", table: table)
		XCTAssertFalse(results.isEmpty)
	}

	func testAfterSpace_activates() {
		let results = SlackEmojiSuggester.suggestions(forContext: "Hello :smi", table: table)
		XCTAssertFalse(results.isEmpty)
	}

	func testAfterNewline_activates() {
		let results = SlackEmojiSuggester.suggestions(forContext: "Hello\n:smi", table: table)
		XCTAssertFalse(results.isEmpty)
	}

	// MARK: - Ranking

	func testExactMatch_rankedFirst() {
		// `:smile` is an exact match for "smile" but also a prefix for "smiley", "smiling_imp".
		let results = SlackEmojiSuggester.suggestions(forContext: ":smile", table: table)
		XCTAssertEqual(results.first?.shortcode, "smile")
	}

	func testPrefixMatches_sortedAlphabetically() {
		let results = SlackEmojiSuggester.suggestions(forContext: ":sm", table: table)
		let codes = results.map(\.shortcode)
		XCTAssertEqual(codes, ["smile", "smiley", "smiling_imp", "smirk", "smoking"])
	}

	func testCaseInsensitivePrefix() {
		let results = SlackEmojiSuggester.suggestions(forContext: ":SM", table: table)
		XCTAssertEqual(results.map(\.shortcode), ["smile", "smiley", "smiling_imp", "smirk", "smoking"])
	}

	// MARK: - No matches

	func testNoMatchingShortcode_returnsEmpty() {
		XCTAssertEqual(SlackEmojiSuggester.suggestions(forContext: ":xyz", table: table), [])
	}

	func testInvalidCharInPrefix_returnsEmpty() {
		// Space inside breaks the trailing-valid-chars scan.
		XCTAssertEqual(SlackEmojiSuggester.suggestions(forContext: ":sm ile", table: table), [])
	}

	// MARK: - Limit

	func testLimitCapsResults() {
		let results = SlackEmojiSuggester.suggestions(forContext: ":sm", table: table, limit: 2)
		XCTAssertEqual(results.count, 2)
		XCTAssertEqual(results.map(\.shortcode), ["smile", "smiley"])
	}

	// MARK: - Buffer that just had `:foo:` substituted

	func testJustAfterClosingColon_returnsEmpty() {
		// `:smile:` ends with `:`, not a shortcode prefix. Suggester should NOT fire.
		XCTAssertEqual(SlackEmojiSuggester.suggestions(forContext: ":smile:", table: table), [])
	}
}
