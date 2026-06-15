import XCTest
@testable import KeymojiCore

final class FavoritesEntitlementTests: XCTestCase {

	private let many = ["❤️", "😂", "👍", "🙏", "😍", "🔥", "🎉", "🥰"]   // 8 > the free cap

	// MARK: - canAddFavorite

	func testCanAddFavorite_freeBelowLimit_true() {
		XCTAssertTrue(FavoritesEntitlement.canAddFavorite(currentCount: 5, isPlus: false))
	}

	func testCanAddFavorite_freeAtLimit_false() {
		XCTAssertFalse(
			FavoritesEntitlement.canAddFavorite(
				currentCount: FavoritesEntitlement.freeFavoritesLimit,
				isPlus: false
			)
		)
	}

	func testCanAddFavorite_plusAtLimit_true() {
		XCTAssertTrue(
			FavoritesEntitlement.canAddFavorite(
				currentCount: FavoritesEntitlement.freeFavoritesLimit,
				isPlus: true
			)
		)
	}

	// MARK: - visibleFavorites: free clamp

	func testVisibleFavorites_free_clampsToLimit_andForcesManual() {
		// Even with a frequency mode + counts that would reorder, a free user gets the first N in
		// manual order — the keyboard clamp is defense-in-depth behind the host-app gates.
		let result = FavoritesEntitlement.visibleFavorites(
			many,
			counts: ["🥰": 99, "🎉": 50],   // would jump to the front under .frequency
			mode: .frequency,
			isPlus: false
		)
		XCTAssertEqual(result, Array(many.prefix(FavoritesEntitlement.freeFavoritesLimit)))
	}

	func testVisibleFavorites_free_belowLimit_unchanged() {
		let few = ["❤️", "😀", "🚀"]
		let result = FavoritesEntitlement.visibleFavorites(few, counts: [:], mode: .manual, isPlus: false)
		XCTAssertEqual(result, few)
	}

	// MARK: - visibleFavorites: Plus

	func testVisibleFavorites_plus_keepsAll_manual() {
		let result = FavoritesEntitlement.visibleFavorites(many, counts: [:], mode: .manual, isPlus: true)
		XCTAssertEqual(result, many)
	}

	func testVisibleFavorites_plus_appliesFrequencyOrder() {
		let favorites = ["❤️", "😀", "🚀", "🎉"]
		let result = FavoritesEntitlement.visibleFavorites(
			favorites,
			counts: ["❤️": 1, "😀": 4, "🚀": 10, "🎉": 7],
			mode: .frequency,
			isPlus: true
		)
		XCTAssertEqual(result, ["🚀", "🎉", "😀", "❤️"])
	}
}
