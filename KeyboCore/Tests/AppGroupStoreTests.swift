import XCTest
@testable import KeyboCore

final class AppGroupStoreTests: XCTestCase {

	// Plain (non-App-Group) suite name — App Group identifiers require matching entitlements
	// on the test bundle, which we don't ship. A regular suite gives us isolated, portable defaults.
	private static let testSuite = "keybo.AppGroupStoreTests"
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
}
