import XCTest
@testable import KeyboardCore

final class SlackEmojiParserTests: XCTestCase {

	private let table: [String: String] = [
		"smile":     "😄",
		"thumbsup":  "👍",
		"+1":        "👍",
		"fire":      "🔥",
		"slightly_smiling_face": "🙂"
	]

	// MARK: - Happy path

	func testSimpleShortcode_returnsEmojiAndConsumedLength() {
		let match = SlackEmojiParser.detectMatch(atEndOf: ":smile:", table: table)
		XCTAssertEqual(match, .init(emoji: "😄", consumedLength: 7))
	}

	func testShortcodeAfterText_capturesOnlyShortcode() {
		let match = SlackEmojiParser.detectMatch(atEndOf: "Hello :smile:", table: table)
		XCTAssertEqual(match, .init(emoji: "😄", consumedLength: 7))
	}

	func testShortcodeWithUnderscore_matches() {
		let match = SlackEmojiParser.detectMatch(atEndOf: ":slightly_smiling_face:", table: table)
		XCTAssertEqual(match?.emoji, "🙂")
		XCTAssertEqual(match?.consumedLength, 23)
	}

	func testShortcodeWithPlus_matches() {
		let match = SlackEmojiParser.detectMatch(atEndOf: ":+1:", table: table)
		XCTAssertEqual(match, .init(emoji: "👍", consumedLength: 4))
	}

	func testShortcodeLookupIsCaseInsensitive() {
		let match = SlackEmojiParser.detectMatch(atEndOf: ":SMILE:", table: table)
		XCTAssertEqual(match?.emoji, "😄")
	}

	// MARK: - Adjacent text / multiple shortcodes

	func testTwoShortcodes_capturesOnlyLastOne() {
		// Trailing `:fire:` matches; the earlier `:smile:` is irrelevant to this scan.
		let match = SlackEmojiParser.detectMatch(atEndOf: ":smile: :fire:", table: table)
		XCTAssertEqual(match, .init(emoji: "🔥", consumedLength: 6))
	}

	func testAdjacentShortcodesNoSpace_capturesTrailingPair() {
		// `:smile::fire:` ends with `:fire:`. The scanner stops at the `:` before `fire`.
		let match = SlackEmojiParser.detectMatch(atEndOf: ":smile::fire:", table: table)
		XCTAssertEqual(match, .init(emoji: "🔥", consumedLength: 6))
	}

	// MARK: - Non-matches

	func testEmpty_returnsNil() {
		XCTAssertNil(SlackEmojiParser.detectMatch(atEndOf: "", table: table))
	}

	func testNoTrailingColon_returnsNil() {
		XCTAssertNil(SlackEmojiParser.detectMatch(atEndOf: ":smile", table: table))
	}

	func testSingleColon_returnsNil() {
		XCTAssertNil(SlackEmojiParser.detectMatch(atEndOf: ":", table: table))
	}

	func testDoubleColonNoChars_returnsNil() {
		// `::` has no chars between colons — not a valid shortcode.
		XCTAssertNil(SlackEmojiParser.detectMatch(atEndOf: "::", table: table))
	}

	func testUnknownShortcode_returnsNil() {
		// Pattern is valid but the shortcode isn't in the table — leave the text alone.
		XCTAssertNil(SlackEmojiParser.detectMatch(atEndOf: ":notarealcode:", table: table))
	}

	func testShortcodeWithSpace_returnsNil() {
		XCTAssertNil(SlackEmojiParser.detectMatch(atEndOf: ":smi le:", table: table))
	}

	func testShortcodeWithPunctuation_returnsNil() {
		XCTAssertNil(SlackEmojiParser.detectMatch(atEndOf: ":smi.le:", table: table))
	}

	func testShortcodeWithAccentedChar_returnsNil() {
		XCTAssertNil(SlackEmojiParser.detectMatch(atEndOf: ":café:", table: table))
	}

	func testTrailingTextAfterShortcode_returnsNil() {
		// `:smile: ` has a trailing space — the closing colon isn't the last char.
		XCTAssertNil(SlackEmojiParser.detectMatch(atEndOf: ":smile: ", table: table))
	}

	// MARK: - Default table sanity

	func testDefaultTable_smile_smoke() {
		let match = SlackEmojiParser.detectMatch(atEndOf: ":smile:")
		XCTAssertEqual(match?.emoji, "😄")
	}

	func testDefaultTable_thumbsup_smoke() {
		let match = SlackEmojiParser.detectMatch(atEndOf: ":thumbsup:")
		XCTAssertEqual(match?.emoji, "👍")
	}

	func testDefaultTable_plusOne_smoke() {
		let match = SlackEmojiParser.detectMatch(atEndOf: ":+1:")
		XCTAssertEqual(match?.emoji, "👍")
	}
}
