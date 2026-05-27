import XCTest
@testable import KeyboardCore

final class SlackEmojiTableTests: XCTestCase {

	func testShortcodeForKnownEmoji_returnsShortcode() {
		XCTAssertEqual(SlackEmojiTable.shortcode(for: "🚀"), "rocket")
		XCTAssertEqual(SlackEmojiTable.shortcode(for: "❤️"), "heart")
		XCTAssertEqual(SlackEmojiTable.shortcode(for: "🎉"), "tada")
	}

	func testShortcodeForUnknownEmoji_returnsNil() {
		XCTAssertNil(SlackEmojiTable.shortcode(for: "🫨"))
		XCTAssertNil(SlackEmojiTable.shortcode(for: "🪅"))
	}

	func testReverseLookup_prefersShortestShortcode() {
		let table = [
			"+1":       "👍",
			"thumbsup": "👍"
		]
		let map = SlackEmojiTable.reverseLookup(from: table)
		XCTAssertEqual(map["👍"], "+1", "Shorter shortcode (+1, 2 chars) should win over thumbsup (8 chars).")
	}

	func testReverseLookup_breaksTiesAlphabetically() {
		let table = [
			"bbb": "🐝",
			"aaa": "🐝",
			"ccc": "🐝"
		]
		let map = SlackEmojiTable.reverseLookup(from: table)
		XCTAssertEqual(map["🐝"], "aaa", "When all shortcodes are the same length, the alphabetically first should win.")
	}

	func testDefaultTable_thumbsUpReverseLookupIsDeterministic() {
		// `+1` (2 chars) is shorter than `thumbsup` (8 chars) → +1 wins.
		XCTAssertEqual(SlackEmojiTable.shortcode(for: "👍"), "+1")
		XCTAssertEqual(SlackEmojiTable.shortcode(for: "👎"), "-1")
	}

	func testDefaultTable_sunReverseLookup_picksShorterKey() {
		// "sun" and "sunny" both map to ☀️ — "sun" (3) is shorter than "sunny" (5).
		XCTAssertEqual(SlackEmojiTable.shortcode(for: "☀️"), "sun")
	}
}
