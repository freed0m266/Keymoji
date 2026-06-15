import XCTest
@testable import KeymojiCore

final class AppGroupStoreTests: XCTestCase {

	// Plain (non-App-Group) suite name — App Group identifiers require matching entitlements
	// on the test bundle, which we don't ship. A regular suite gives us isolated, portable defaults.
	private static let testSuite = "keymoji.AppGroupStoreTests"
	private var store: AppGroupStore!

	override func setUp() {
		super.setUp()
		store = AppGroupStore(suiteName: Self.testSuite)
		store.reset()
	}

	override func tearDown() {
		store.reset()
		super.tearDown()
	}

	// MARK: - Default values

	func testShowNumberRow_defaultsToTrue() {
		XCTAssertTrue(store.showNumberRow)
	}

	func testHapticFeedbackEnabled_defaultsToTrue() {
		XCTAssertTrue(store.hapticFeedbackEnabled)
	}

	func testOnboardingComplete_defaultsToFalse() {
		XCTAssertFalse(store.onboardingComplete)
	}

	func testIsPlus_defaultsToFalse() {
		XCTAssertFalse(store.isPlus)
	}

	// MARK: - Set / get

	func testShowNumberRow_canBeDisabled() {
		store.showNumberRow = false
		XCTAssertFalse(store.showNumberRow)
	}

	func testHapticFeedbackEnabled_canBeDisabled() {
		store.hapticFeedbackEnabled = false
		XCTAssertFalse(store.hapticFeedbackEnabled)
	}

	func testOnboardingComplete_canBeMarked() {
		store.onboardingComplete = true
		XCTAssertTrue(store.onboardingComplete)
	}

	func testIsPlus_roundTrips() {
		store.isPlus = true
		XCTAssertTrue(store.isPlus)
		store.isPlus = false
		XCTAssertFalse(store.isPlus)
	}

	// MARK: - Default fallback distinguishes unset from `false`

	func testBoolDefault_returnsDefaultWhenUnset() {
		XCTAssertTrue(store.bool(forKey: .showNumberRow, default: true))
		XCTAssertFalse(store.bool(forKey: .showNumberRow, default: false))
	}

	func testBoolDefault_returnsStoredFalse_notDefault() {
		store.setBool(false, forKey: .showNumberRow)
		// Default is `true`, but a stored `false` wins.
		XCTAssertFalse(store.bool(forKey: .showNumberRow, default: true))
	}

	// MARK: - Reset

	func testReset_clearsAllKeys() {
		store.showNumberRow = false
		store.hapticFeedbackEnabled = false
		store.onboardingComplete = true

		store.reset()

		XCTAssertTrue(store.showNumberRow)
		XCTAssertTrue(store.hapticFeedbackEnabled)
		XCTAssertFalse(store.onboardingComplete)
	}

	// MARK: - Cross-instance visibility

	func testSecondInstance_seesValueFromFirst() {
		store.hapticFeedbackEnabled = false
		let other = AppGroupStore(suiteName: Self.testSuite)
		XCTAssertFalse(other.hapticFeedbackEnabled)
	}

	// MARK: - Favorite emojis

	func testFavoriteEmojis_defaultsToEmpty() {
		XCTAssertEqual(store.favoriteEmojis, [])
	}

	func testFavoriteEmojis_roundTripsAndPreservesOrder() {
		store.favoriteEmojis = ["❤️", "😀", "🚀"]
		XCTAssertEqual(store.favoriteEmojis, ["❤️", "😀", "🚀"])
	}

	func testFavoriteEmojis_resetClearsList() {
		store.favoriteEmojis = ["😀"]
		store.reset()
		XCTAssertEqual(store.favoriteEmojis, [])
	}

	// MARK: - Favorites sort mode

	func testFavoritesSortMode_defaultsToManual() {
		XCTAssertEqual(store.favoritesSortMode, .manual)
	}

	func testFavoritesSortMode_persistsRawValue() {
		store.favoritesSortMode = .frequency
		XCTAssertEqual(store.favoritesSortMode, .frequency)
		// Verify a second instance reads the same persisted raw string.
		let other = AppGroupStore(suiteName: Self.testSuite)
		XCTAssertEqual(other.favoritesSortMode, .frequency)
	}

	func testFavoritesSortMode_unknownRawValueFallsBackToManual() {
		store.setString("nonsense", forKey: .favoritesSortMode)
		XCTAssertEqual(store.favoritesSortMode, .manual)
	}

	// MARK: - Letter alternate set

	func testLetterAlternateSet_unset_returnsDetectedDefault() {
		// No stored value → the getter computes the locale-derived default rather than a fixed one.
		// (Migration path for existing users: absence of the key means "follow detection".)
		XCTAssertEqual(store.letterAlternateSet, LetterAlternateSet.detectedDefault())
	}

	func testLetterAlternateSet_roundTrip() {
		store.letterAlternateSet = .german
		XCTAssertEqual(store.letterAlternateSet, .german)
		// A second instance reads the same persisted raw string.
		let other = AppGroupStore(suiteName: Self.testSuite)
		XCTAssertEqual(other.letterAlternateSet, .german)
	}

	func testLetterAlternateSet_unknownRawValue_returnsDetectedDefault() {
		store.setString("nonsense", forKey: .letterAlternateSet)
		XCTAssertEqual(store.letterAlternateSet, LetterAlternateSet.detectedDefault())
	}

	func testLetterAlternateSet_resetRestoresDetectedDefault() {
		store.letterAlternateSet = .french
		store.reset()
		XCTAssertEqual(store.letterAlternateSet, LetterAlternateSet.detectedDefault())
	}

	// MARK: - Emoji usage counts

	func testEmojiUsageCounts_defaultsToEmpty() {
		XCTAssertEqual(store.emojiUsageCounts, [:])
	}

	func testEmojiUsageCounts_jsonRoundTrips() {
		store.emojiUsageCounts = ["🚀": 3, "❤️": 7]
		XCTAssertEqual(store.emojiUsageCounts, ["🚀": 3, "❤️": 7])
	}

	func testEmojiUsageCounts_resetClearsCounts() {
		store.emojiUsageCounts = ["😀": 1]
		store.reset()
		XCTAssertEqual(store.emojiUsageCounts, [:])
	}
}
