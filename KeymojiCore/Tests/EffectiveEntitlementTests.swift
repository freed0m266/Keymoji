import XCTest
@testable import KeymojiCore

final class EffectiveEntitlementTests: XCTestCase {

	private let now = Date(timeIntervalSince1970: 1_000_000)

	func testPaid_isAlwaysPlus_regardlessOfExpiry() {
		XCTAssertTrue(effectiveIsPlus(paid: true, promoExpiresAt: nil, now: now))
		XCTAssertTrue(effectiveIsPlus(paid: true, promoExpiresAt: now.addingTimeInterval(-1), now: now))
		XCTAssertTrue(effectiveIsPlus(paid: true, promoExpiresAt: now.addingTimeInterval(1), now: now))
	}

	func testPromoInFuture_isPlus() {
		let future = now.addingTimeInterval(60 * 60)
		XCTAssertTrue(effectiveIsPlus(paid: false, promoExpiresAt: future, now: now))
	}

	func testPromoInPast_isNotPlus() {
		let past = now.addingTimeInterval(-1)
		XCTAssertFalse(effectiveIsPlus(paid: false, promoExpiresAt: past, now: now))
	}

	func testExpiryExactlyNow_isNotPlus() {
		// `now < expiry` is strict — an expiry that has just been reached is no longer active.
		XCTAssertFalse(effectiveIsPlus(paid: false, promoExpiresAt: now, now: now))
	}

	func testNoPromoNoPaid_isNotPlus() {
		XCTAssertFalse(effectiveIsPlus(paid: false, promoExpiresAt: nil, now: now))
	}
}
