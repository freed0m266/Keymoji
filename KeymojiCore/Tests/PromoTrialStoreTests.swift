import XCTest
@testable import KeymojiCore

final class PromoTrialStoreTests: XCTestCase {

	/// In-memory `PromoTrialKeychainBacking` so the grant math and idempotence run without a real
	/// Keychain (which would need entitlements the test bundle doesn't ship).
	private final class InMemoryBacking: PromoTrialKeychainBacking, @unchecked Sendable {
		private var storage: [String: Data] = [:]
		func data(forKey key: String) -> Data? { storage[key] }
		func set(_ data: Data, forKey key: String) { storage[key] = data }
		func removeAll() { storage.removeAll() }
	}

	private var backing: InMemoryBacking!
	private var store: PromoTrialStore!
	private let day: TimeInterval = 24 * 60 * 60

	override func setUp() {
		super.setUp()
		backing = InMemoryBacking()
		store = PromoTrialStore(backing: backing)
	}

	override func tearDown() {
		store = nil
		backing = nil
		super.tearDown()
	}

	// MARK: - Defaults

	func testEmptyRecord_defaultsToUnconsumedNoExpiry() {
		let record = store.record
		XCTAssertFalse(record.welcomeConsumed)
		XCTAssertFalse(record.cheatCodeConsumed)
		XCTAssertNil(record.expiresAt)
		XCTAssertFalse(store.isPromoActive)
	}

	// MARK: - nextExpiry math

	func testNextExpiry_firstGrant_fromNil_startsFromNow() {
		let t = Date(timeIntervalSince1970: 1_000_000)
		let result = PromoTrialStore.nextExpiry(currentExpiry: nil, now: t, addDays: 30)
		XCTAssertEqual(result, t.addingTimeInterval(30 * day))
	}

	func testNextExpiry_afterExpiredTrial_startsFromNow() {
		let t = Date(timeIntervalSince1970: 1_000_000)
		let expired = t.addingTimeInterval(-1 * day)
		let result = PromoTrialStore.nextExpiry(currentExpiry: expired, now: t, addDays: 60)
		XCTAssertEqual(result, t.addingTimeInterval(60 * day))
	}

	func testNextExpiry_duringRunningTrial_stacksOntoExpiry() {
		let t = Date(timeIntervalSince1970: 1_000_000)
		let running = t.addingTimeInterval(20 * day)   // day 10 of a 30-day trial
		let result = PromoTrialStore.nextExpiry(currentExpiry: running, now: t, addDays: 60)
		XCTAssertEqual(result, t.addingTimeInterval(80 * day))   // 20 remaining + 60 granted
	}

	// MARK: - consumeWelcome

	func testConsumeWelcome_fresh_grants30DaysFromNow() {
		let t = Date(timeIntervalSince1970: 1_000_000)
		let expiry = store.consumeWelcome(now: t)
		XCTAssertEqual(expiry, t.addingTimeInterval(30 * day))
		XCTAssertTrue(store.record.welcomeConsumed)
		XCTAssertFalse(store.record.cheatCodeConsumed)
		XCTAssertEqual(store.record.expiresAt, expiry)
	}

	func testConsumeWelcome_isIdempotent() {
		let t = Date(timeIntervalSince1970: 1_000_000)
		let first = store.consumeWelcome(now: t)
		// A second call (e.g. double tap in Settings) returns the same expiry, no extra grant.
		let second = store.consumeWelcome(now: t.addingTimeInterval(5 * day))
		XCTAssertEqual(second, first)
		XCTAssertTrue(store.record.welcomeConsumed)
		XCTAssertEqual(store.record.expiresAt, first)
	}

	// MARK: - consumeCheatCode

	func testConsumeCheatCode_fresh_grants60DaysFromNow() {
		let t = Date(timeIntervalSince1970: 1_000_000)
		let expiry = store.consumeCheatCode(now: t)
		XCTAssertEqual(expiry, t.addingTimeInterval(60 * day))
		XCTAssertTrue(store.record.cheatCodeConsumed)
		XCTAssertFalse(store.record.welcomeConsumed)
	}

	func testConsumeCheatCode_isIdempotent() {
		let t = Date(timeIntervalSince1970: 1_000_000)
		let first = store.consumeCheatCode(now: t)
		let second = store.consumeCheatCode(now: t.addingTimeInterval(10 * day))
		XCTAssertEqual(second, first)
	}

	// MARK: - Stacking across grants

	func testCheatCode_stacksOntoRunningWelcome() {
		let t = Date(timeIntervalSince1970: 1_000_000)
		let welcomeExpiry = store.consumeWelcome(now: t)           // t + 30d
		// 10 days into the welcome trial, type cheat code.
		let t2 = t.addingTimeInterval(10 * day)
		let stacked = store.consumeCheatCode(now: t2)
		XCTAssertEqual(stacked, welcomeExpiry.addingTimeInterval(60 * day))   // (t+30d) + 60d
		XCTAssertTrue(store.record.welcomeConsumed)
		XCTAssertTrue(store.record.cheatCodeConsumed)
		XCTAssertEqual(store.record.expiresAt, stacked)
	}

	func testCheatCode_afterExpiredWelcome_startsFreshFromNow() {
		let t = Date(timeIntervalSince1970: 1_000_000)
		_ = store.consumeWelcome(now: t)                            // t + 30d
		// 40 days later the welcome trial has lapsed; cheat code starts a fresh 60-day grant.
		let t2 = t.addingTimeInterval(40 * day)
		let fresh = store.consumeCheatCode(now: t2)
		XCTAssertEqual(fresh, t2.addingTimeInterval(60 * day))
	}

	// MARK: - isPromoActive

	func testIsPromoActive_trueWhileGrantInFuture() {
		// Grant 30 days from "now" using the real clock so the live `isPromoActive` check sees a future.
		_ = store.consumeWelcome(now: Date())
		XCTAssertTrue(store.isPromoActive)
	}

	// MARK: - Persistence round-trip

	func testRecord_roundTripsThroughBacking() {
		let t = Date(timeIntervalSince1970: 1_000_000)
		let expiry = store.consumeWelcome(now: t)
		// A fresh store over the same backing sees the persisted record (mirrors host ↔ extension sharing).
		let reopened = PromoTrialStore(backing: backing)
		XCTAssertTrue(reopened.record.welcomeConsumed)
		XCTAssertEqual(reopened.record.expiresAt, expiry)
	}
}
