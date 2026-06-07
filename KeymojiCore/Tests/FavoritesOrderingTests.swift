import XCTest
@testable import KeymojiCore

final class FavoritesOrderingTests: XCTestCase {

	private let favorites = ["❤️", "😀", "🚀", "🎉"]

	// MARK: - Manual

	func testManual_returnsInputUnchanged() {
		let result = FavoritesOrdering.ordered(
			favorites,
			counts: ["🚀": 99, "❤️": 1],
			mode: .manual
		)
		XCTAssertEqual(result, favorites)
	}

	// MARK: - Frequency

	func testFrequency_ordersByCountDescending() {
		let result = FavoritesOrdering.ordered(
			favorites,
			counts: ["❤️": 1, "😀": 4, "🚀": 10, "🎉": 7],
			mode: .frequency
		)
		XCTAssertEqual(result, ["🚀", "🎉", "😀", "❤️"])
	}

	func testFrequency_emptyCounts_returnsInputOrder() {
		// Day one: no usage data yet → frequency mode is a no-op (returns manual order).
		let result = FavoritesOrdering.ordered(favorites, counts: [:], mode: .frequency)
		XCTAssertEqual(result, favorites)
	}

	func testFrequency_tieOnCount_isStableByOriginalIndex() {
		// ❤️ and 🚀 both 5; 😀 and 🎉 both 2 → ties keep their manual relative order.
		let result = FavoritesOrdering.ordered(
			favorites,
			counts: ["❤️": 5, "😀": 2, "🚀": 5, "🎉": 2],
			mode: .frequency
		)
		XCTAssertEqual(result, ["❤️", "🚀", "😀", "🎉"])
	}

	func testFrequency_missingCountTreatedAsZero() {
		// 😀 has no entry → treated as 0, sinks below the counted ones; remaining zero-count
		// favorites keep manual order.
		let result = FavoritesOrdering.ordered(
			favorites,
			counts: ["🚀": 3, "❤️": 1],
			mode: .frequency
		)
		XCTAssertEqual(result, ["🚀", "❤️", "😀", "🎉"])
	}

	func testFrequency_emptyFavorites_returnsEmpty() {
		let result = FavoritesOrdering.ordered([], counts: ["🚀": 3], mode: .frequency)
		XCTAssertEqual(result, [])
	}
}
