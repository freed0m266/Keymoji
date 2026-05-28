import XCTest
@testable import KeyboardCore

final class EmojiSearchIndexTests: XCTestCase {

	// MARK: - Empty / sanity

	func testEmptyQuery_returnsEmpty() {
		XCTAssertEqual(EmojiSearchIndex.search(query: "").count, 0)
	}

	func testWhitespaceQuery_returnsEmpty() {
		XCTAssertEqual(EmojiSearchIndex.search(query: "   ").count, 0)
	}

	func testNoMatches_returnsEmpty() {
		XCTAssertEqual(EmojiSearchIndex.search(query: "xyz123nope").count, 0)
	}

	// MARK: - Single-token prefix match

	func testRainQuery_surfacesRainGlyphs() {
		let glyphs = EmojiSearchIndex.search(query: "rain").map(\.glyph)
		// CLDR names containing "rain": "cloud with rain", "cloud with lightning and rain",
		// "sun behind rain cloud", "rainbow", "umbrella with rain drops".
		XCTAssertTrue(glyphs.contains("🌧️"), "Expected 🌧️ in rain results, got \(glyphs.prefix(20))")
		XCTAssertTrue(glyphs.contains("🌈"), "Expected 🌈 in rain results")
		XCTAssertTrue(glyphs.contains("☔"), "Expected ☔ in rain results")
	}

	func testCaseInsensitive() {
		let lower = EmojiSearchIndex.search(query: "rain").map(\.glyph)
		let mixed = EmojiSearchIndex.search(query: "Rain").map(\.glyph)
		XCTAssertEqual(lower, mixed)
	}

	// MARK: - Multi-word AND

	func testRedHeartQuery_returnsRedHeart_excludesGreenHeart() {
		let glyphs = EmojiSearchIndex.search(query: "red heart").map(\.glyph)
		XCTAssertTrue(glyphs.contains("❤️"), "red heart query must surface ❤️")
		XCTAssertFalse(glyphs.contains("💚"), "red heart query must NOT surface 💚 (name is 'green heart')")
	}

	// MARK: - Slack shortcode

	func testThumbsupShortcode_returnsThumbsUpGlyph() {
		let glyphs = EmojiSearchIndex.search(query: "thumbsup").map(\.glyph)
		XCTAssertTrue(glyphs.contains("👍"), "thumbsup shortcode must resolve to 👍")
	}

	// MARK: - Ranking tiers

	func testRanking_exactNameMatchBeatsKeywordHit() {
		// "rainbow" — exact name == "rainbow", keyword hits in other entries exist (e.g. via
		// the multi-word path on "cloud with rain" partial), but exact-name wins tier 1.
		let glyphs = EmojiSearchIndex.search(query: "rainbow").map(\.glyph)
		XCTAssertEqual(glyphs.first, "🌈", "exact name 'rainbow' should rank first; got \(glyphs.prefix(5))")
	}

	func testRanking_nameMatchBeforeKeywordOnlyMatch() {
		// "heart" → name "heart"-prefix entries first (red heart, green heart…),
		// emoji whose only match is a keyword (e.g. "💘" cupid) come after.
		let glyphs = EmojiSearchIndex.search(query: "heart").map(\.glyph)
		// First entry must be one whose canonical CLDR name starts with "heart"
		// — never an entry whose only hit is in keywords.
		guard let first = glyphs.first else {
			XCTFail("Expected at least one match for 'heart'")
			return
		}
		// "red heart" is the canonical "heart-prefix" winner (Unicode order: comes before
		// "orange heart", "yellow heart", etc.). Accept any name starting with "heart".
		// Confirm by looking up the entry in EmojiCatalog.
		let entry = EmojiCatalog.all.first(where: { $0.glyph == first })
		XCTAssertNotNil(entry)
		// Heart-named glyphs in CLDR all read like "<color> heart" so a strict prefix test
		// would be wrong — instead require that "heart" appears as a name token (whitespace-
		// separated word) on the top hit, not just a keyword.
		let nameTokens = entry?.name.split(whereSeparator: { $0.isWhitespace }).map(String.init) ?? []
		XCTAssertTrue(nameTokens.contains("heart"), "top result for 'heart' should have 'heart' in its name tokens; got name='\(entry?.name ?? "nil")'")
	}

	// MARK: - Limit

	func testLimit_capsResultCount() {
		let unlimited = EmojiSearchIndex.search(query: "heart").count
		let capped = EmojiSearchIndex.search(query: "heart", limit: 3).count
		XCTAssertLessThanOrEqual(capped, 3)
		XCTAssertLessThan(capped, unlimited, "limit should cap results below the unlimited total")
	}

	// MARK: - Custom catalog path

	func testCustomCatalog_takesPrecedenceOverBundled() {
		let custom: [Emoji] = [
			Emoji(glyph: "🟦", name: "blue square", keywords: ["blue", "square"], category: .symbols),
			Emoji(glyph: "🟥", name: "red square", keywords: ["red", "square"], category: .symbols)
		]
		let glyphs = EmojiSearchIndex.search(query: "square", catalog: custom).map(\.glyph)
		XCTAssertEqual(Set(glyphs), Set(["🟦", "🟥"]))
	}
}
