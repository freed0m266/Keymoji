import XCTest
import Observation
@testable import KeymojiCore

// File-scope test doubles. `StubPurchase` must not be a *nested private* type — the `@Observable`
// macro emits a file-scope extension that can't see a type nested-and-private inside the test class.

private final class InMemoryPromoBacking: PromoTrialKeychainBacking, @unchecked Sendable {
	private var storage: [String: Data] = [:]
	func data(forKey key: String) -> Data? { storage[key] }
	func set(_ data: Data, forKey key: String) { storage[key] = data }
	func removeAll() { storage.removeAll() }
}

/// Minimal `PurchaseServicing` stub — the activator only reads `isPlus` (the paid flag).
@Observable
@MainActor
private final class StubPurchase: PurchaseServicing {
	var isPlus: Bool
	var displayPrice: String?
	var isProductLoaded = true
	init(isPlus: Bool) { self.isPlus = isPlus }
	func loadProducts() async {}
	func purchase() async -> PurchaseOutcome { .success }
	func restore() async -> Bool { isPlus }
	func refreshEntitlement() async {}
}

@MainActor
final class WelcomeTrialActivatorTests: XCTestCase {

	private let suiteName = "keymoji.WelcomeTrialActivatorTests"
	private var appGroup: AppGroupStore!
	private var promoStore: PromoTrialStore!
	private var notifier: SettingsChangeNotifier!

	override func setUp() {
		super.setUp()
		appGroup = AppGroupStore(suiteName: suiteName)
		appGroup.reset()
		promoStore = PromoTrialStore(backing: InMemoryPromoBacking())
		notifier = SettingsChangeNotifier()
	}

	override func tearDown() {
		appGroup.reset()
		super.tearDown()
	}

	private func makeActivator(paid: Bool) -> WelcomeTrialActivator {
		WelcomeTrialActivator(
			promoStore: promoStore,
			appGroup: appGroup,
			notifier: notifier,
			purchaseService: StubPurchase(isPlus: paid)
		)
	}

	// MARK: - Tests

	func testActivate_fresh_grantsExpiryAndMirrorsToAppGroup() async {
		let activator = makeActivator(paid: false)
		let posted = expectation(description: ".promoPlusExpiresAt posted")
		let token = notifier.addObserver(for: .promoPlusExpiresAt) { posted.fulfill() }

		let expiry = activator.activate()

		XCTAssertNotNil(expiry)
		XCTAssertTrue(promoStore.record.welcomeConsumed)
		XCTAssertEqual(appGroup.promoPlusExpiresAt, expiry)
		await fulfillment(of: [posted], timeout: 2.0)
		_ = token
	}

	func testActivate_secondCall_returnsNilAndDoesNotRegrant() {
		let activator = makeActivator(paid: false)
		let first = activator.activate()
		let appGroupAfterFirst = appGroup.promoPlusExpiresAt

		let second = activator.activate()

		XCTAssertNotNil(first)
		XCTAssertNil(second, "Welcome is one-shot — a second activate must be a no-op")
		// The mirror is unchanged by the rejected second activation.
		XCTAssertEqual(appGroup.promoPlusExpiresAt, appGroupAfterFirst)
	}

	func testActivate_whenPaid_returnsNilAndConsumesNothing() {
		let activator = makeActivator(paid: true)

		let result = activator.activate()

		XCTAssertNil(result, "Paid Plus overrides — the gift isn't spent")
		XCTAssertFalse(promoStore.record.welcomeConsumed)
		XCTAssertNil(appGroup.promoPlusExpiresAt)
	}

	func testActivate_doesNotPostWhenRejected() async {
		let activator = makeActivator(paid: false)
		_ = activator.activate()   // consume welcome

		// A second (rejected) activation must not post — otherwise the keyboard would churn.
		let unwanted = expectation(description: "no post on rejected activation")
		unwanted.isInverted = true
		let token = notifier.addObserver(for: .promoPlusExpiresAt) { unwanted.fulfill() }

		let second = activator.activate()

		XCTAssertNil(second)
		await fulfillment(of: [unwanted], timeout: 0.5)
		_ = token
	}
}
