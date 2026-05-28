import XCTest
@testable import KeyboardCore

final class EmojiCatalogTests: XCTestCase {

	// MARK: - Bundle load

	func testAll_loadsExpectedCount() {
		// Generated catalog: ~1 386 entries (1 318 from unicode-emoji-json after the
		// single-base-codepoint filter, plus ~68 hand-curated flags). Drift outside ±50
		// almost certainly means the generator script regressed or the bundle resource
		// failed to load — both worth surfacing.
		let count = EmojiCatalog.all.count
		XCTAssertGreaterThan(count, 1_350, "EmojiCatalog.all under floor; got \(count)")
		XCTAssertLessThan(count, 1_500, "EmojiCatalog.all over ceiling; got \(count)")
	}

	func testAll_idsAreUnique() {
		let all = EmojiCatalog.all
		let unique = Set(all.map(\.glyph))
		XCTAssertEqual(all.count, unique.count, "duplicate glyph entries in EmojiCatalog.all")
	}

	// MARK: - Per-category sanity

	func testEveryStaticCategory_hasMinimumEntries() {
		// Sanity floor mirrors the convention in task 34: each non-flags static category
		// has at least 50 emojis. Flags are hand-curated and intentionally smaller.
		for category in EmojiCatalog.staticCategories where category != .flags {
			let count = EmojiCatalog.emojis(for: category).count
			XCTAssertGreaterThan(count, 50, "category \(category.rawValue) has only \(count) emojis — bundle load may have regressed")
		}
	}

	func testFlags_areHardcoded_andIndependentOfJSON() {
		let flags = EmojiCatalog.emojis(for: .flags)
		XCTAssertFalse(flags.isEmpty)
		// Hand-curated subset always pins Czechia first after the generic banners.
		XCTAssertTrue(flags.map(\.glyph).contains("🇨🇿"))
		// Flags carry no keywords by design (task 39 §1) — keep an explicit assertion so a
		// future contributor doesn't accidentally start populating keywords mid-task.
		for emoji in flags {
			XCTAssertEqual(emoji.keywords, [], "flag \(emoji.glyph) gained keywords; task 39 §1 deferred this to a follow-up")
		}
	}

	// MARK: - Favorites / recents helpers

	func testFavoritesAndRecents_returnEmptyFromCatalog() {
		// Both categories are runtime-driven (user history / curated list); the static
		// catalog deliberately holds nothing for them so the panel never renders stale data.
		XCTAssertEqual(EmojiCatalog.emojis(for: .favorites), [])
		XCTAssertEqual(EmojiCatalog.emojis(for: .recents), [])
	}
}
