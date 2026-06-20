import XCTest
@testable import KeymojiCore

final class PromoTrialStoreTests: XCTestCase {

	/// In-memory `PromoTrialKeychainBacking` so the grant math and idempotence run without a real
	/// Keychain (which would need entitlements the test bundle doesn't ship).
	private final class InMemoryBacking: PromoTrialKeychainBacking, @unchecked Sendable {
		private var storage: [String: Data] = [:]
		func data(forKey key: String) -> Data? { storage[key] }
		func set(_ data: Data, forKey key: String) throws { storage[key] = data }
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
		XCTAssertNil(record.expiresAt)
		XCTAssertFalse(store.isPromoActive)
	}

	// MARK: - consumeWelcome

	func testConsumeWelcome_fresh_grants30DaysFromNow() {
		let t = Date(timeIntervalSince1970: 1_000_000)
		let expiry = store.consumeWelcome(now: t)
		XCTAssertEqual(expiry, t.addingTimeInterval(30 * day))
		XCTAssertTrue(store.record.welcomeConsumed)
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
