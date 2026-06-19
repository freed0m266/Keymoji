import XCTest
@testable import KeymojiCore

/// `forceFreeTier` masks a real (paid) entitlement to free inside the single entitlement writer
/// (`PurchaseService.applyEntitlement`), so a developer can simulate a free user without resetting
/// StoreKit. DEBUG-only — these symbols don't exist in Release (test bundles build Debug).
@MainActor
final class DebugOverridesTests: XCTestCase {

	// Isolated suites so the test touches neither the shared App Group nor `UserDefaults.standard`.
	private static let storeSuite = "keymoji.DebugOverridesTests.store"
	private static let overridesSuite = "keymoji.DebugOverridesTests.overrides"

	private var store: AppGroupStore!
	private var overridesDefaults: UserDefaults!

	override func setUp() {
		super.setUp()
		store = AppGroupStore(suiteName: Self.storeSuite)
		store.reset()
		overridesDefaults = UserDefaults(suiteName: Self.overridesSuite)
		DebugOverrides.defaults = overridesDefaults
		DebugOverrides.forceFreeTier = false
	}

	override func tearDown() {
		DebugOverrides.forceFreeTier = false
		DebugOverrides.defaults = .standard
		overridesDefaults.removePersistentDomain(forName: Self.overridesSuite)
		store.reset()
		super.tearDown()
	}

	func testForceFreeTier_masksOwnedEntitlement_thenRestoresWhenOff() {
		let service = PurchaseService(store: store, notifier: SettingsChangeNotifier())

		// Mask on: an owned entitlement reads as free everywhere (mirror + observable).
		DebugOverrides.forceFreeTier = true
		service.applyEntitlementForTesting(true)
		XCTAssertFalse(store.isPlus, "force-free should mask the App Group mirror")
		XCTAssertFalse(service.isPlus, "force-free should mask the observable isPlus")

		// Mask off: the true (owned) entitlement is re-applied — real Plus comes back.
		DebugOverrides.forceFreeTier = false
		service.applyEntitlementForTesting(true)
		XCTAssertTrue(store.isPlus)
		XCTAssertTrue(service.isPlus)
	}

	func testForceFreeTier_defaultsToFalse() {
		XCTAssertFalse(DebugOverrides.forceFreeTier)
	}
}
