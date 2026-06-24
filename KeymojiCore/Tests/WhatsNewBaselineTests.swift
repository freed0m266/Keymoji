import XCTest
@testable import KeymojiCore

final class WhatsNewBaselineTests: XCTestCase {

	// Plain (non-App-Group) suite — see `AppGroupStoreTests` for why we don't use the real App Group id.
	private static let testSuite = "keymoji.WhatsNewBaselineTests"
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

	// MARK: - Seed-on-absence

	func testSeedIfNeeded_writesCurrentVersionOnCleanState() {
		XCTAssertFalse(store.hasValue(forKey: .whatsNewVersion))

		WhatsNewBaseline.seedIfNeeded(appGroup: store)

		XCTAssertEqual(store.whatsNewVersion, WhatsNew.currentVersion)
		XCTAssertEqual(store.whatsNewVersion, 1)
	}

	// MARK: - Idempotence

	func testSeedIfNeeded_isIdempotent_secondCallDoesNotChangeValue() {
		WhatsNewBaseline.seedIfNeeded(appGroup: store)
		WhatsNewBaseline.seedIfNeeded(appGroup: store)
		XCTAssertEqual(store.whatsNewVersion, WhatsNew.currentVersion)
	}

	func testSeedIfNeeded_doesNotRegressHigherStoredVersion() {
		// A future build may have already advanced the baseline; re-running the seed must never lower it.
		store.whatsNewVersion = 7
		WhatsNewBaseline.seedIfNeeded(appGroup: store)
		XCTAssertEqual(store.whatsNewVersion, 7)
	}

	// MARK: - Absence detected by presence, not `== 0`

	func testSeedIfNeeded_leavesLegitimateStoredZeroUntouched() {
		// `0` is a present value, not "missing" — proves seed uses `hasValue`, not a `0` sentinel.
		store.setInteger(0, forKey: .whatsNewVersion)
		WhatsNewBaseline.seedIfNeeded(appGroup: store)
		XCTAssertEqual(store.whatsNewVersion, 0)
	}
}
