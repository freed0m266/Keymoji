import XCTest
@testable import KeymojiCore

@MainActor
final class CheatCodeActivatorTests: XCTestCase {

	private final class InMemoryBacking: PromoTrialKeychainBacking, @unchecked Sendable {
		private var storage: [String: Data] = [:]
		func data(forKey key: String) -> Data? { storage[key] }
		func set(_ data: Data, forKey key: String) { storage[key] = data }
		func removeAll() { storage.removeAll() }
	}

	private let suiteName = "keymoji.CheatCodeActivatorTests"
	private var appGroup: AppGroupStore!
	private var promoStore: PromoTrialStore!
	private var notifier: SettingsChangeNotifier!
	private let day: TimeInterval = 24 * 60 * 60

	override func setUp() {
		super.setUp()
		appGroup = AppGroupStore(suiteName: suiteName)
		appGroup.reset()
		promoStore = PromoTrialStore(backing: InMemoryBacking())
		notifier = SettingsChangeNotifier()
	}

	override func tearDown() {
		appGroup.reset()
		super.tearDown()
	}

	private func makeActivator() -> CheatCodeActivator {
		CheatCodeActivator(promoStore: promoStore, appGroup: appGroup, notifier: notifier)
	}

	func testActivate_cold_grants60DaysAndMirrors() {
		let t = Date(timeIntervalSince1970: 1_000_000)
		let outcome = makeActivator().activate(now: t)

		guard case let .granted(expiry, wasExtension) = outcome else {
			return XCTFail("expected .granted, got \(outcome)")
		}
		XCTAssertEqual(expiry, t.addingTimeInterval(60 * day))
		XCTAssertFalse(wasExtension, "no trial was running → cold unlock")
		XCTAssertTrue(promoStore.record.cheatCodeConsumed)
		XCTAssertEqual(appGroup.promoPlusExpiresAt, expiry)
	}

	func testActivate_duringRunningWelcomeTrial_extends() {
		let t = Date(timeIntervalSince1970: 1_000_000)
		let welcomeExpiry = promoStore.consumeWelcome(now: t)   // trial running: t+30d
		appGroup.promoPlusExpiresAt = welcomeExpiry

		let t2 = t.addingTimeInterval(10 * day)
		let outcome = makeActivator().activate(now: t2)

		guard case let .granted(expiry, wasExtension) = outcome else {
			return XCTFail("expected .granted, got \(outcome)")
		}
		XCTAssertTrue(wasExtension, "a trial was running → extension")
		XCTAssertEqual(expiry, welcomeExpiry.addingTimeInterval(60 * day))   // stacked
	}

	func testActivate_afterExpiredTrial_isColdNotExtension() {
		let t = Date(timeIntervalSince1970: 1_000_000)
		_ = promoStore.consumeWelcome(now: t)   // t+30d
		let t2 = t.addingTimeInterval(40 * day) // welcome lapsed

		let outcome = makeActivator().activate(now: t2)
		guard case let .granted(_, wasExtension) = outcome else {
			return XCTFail("expected .granted, got \(outcome)")
		}
		XCTAssertFalse(wasExtension, "trial already lapsed → cold, not extension")
	}

	func testActivate_secondTime_isAlreadyUsed() {
		let t = Date(timeIntervalSince1970: 1_000_000)
		_ = makeActivator().activate(now: t)
		let outcome = makeActivator().activate(now: t.addingTimeInterval(day))
		XCTAssertEqual(outcome, .alreadyUsed)
	}

	func testActivate_whenPaid_isAlreadyHavePlus_andDoesNotConsume() {
		appGroup.isPlus = true   // paid mirror
		let outcome = makeActivator().activate(now: Date())
		XCTAssertEqual(outcome, .alreadyHavePaidPlus)
		XCTAssertFalse(promoStore.record.cheatCodeConsumed, "paid → token not spent")
		XCTAssertNil(appGroup.promoPlusExpiresAt)
	}
}
