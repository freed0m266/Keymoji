import XCTest
import KeyboCore
@testable import KeyboardCore

final class PersonalRecentsStoreTests: XCTestCase {

	private var suiteName: String!
	private var appStore: AppGroupStore!
	private var store: PersonalRecentsStore!

	override func setUp() {
		super.setUp()
		suiteName = "keybo.tests.recents.\(UUID().uuidString)"
		appStore = AppGroupStore(suiteName: suiteName)
		store = PersonalRecentsStore(store: appStore)
	}

	override func tearDown() {
		appStore.reset()
		UserDefaults().removePersistentDomain(forName: suiteName)
		store = nil
		appStore = nil
		suiteName = nil
		super.tearDown()
	}

	// MARK: - Learn & match

	func testLearn_thenMatch() {
		store.learn("hello", fromContextType: .prose)
		let matches = store.matches(prefix: "hel")
		XCTAssertEqual(matches.map(\.word), ["hello"])
		XCTAssertEqual(matches.first?.count, 1)
	}

	func testLearn_isIdempotent_incrementsCount() {
		store.learn("hello", fromContextType: .prose)
		store.learn("hello", fromContextType: .prose)
		store.learn("hello", fromContextType: .prose)
		XCTAssertEqual(store.matches(prefix: "hello").first?.count, 3)
		XCTAssertEqual(store.count, 1)
	}

	func testMatch_isCaseInsensitive() {
		store.learn("Hello", fromContextType: .prose)
		XCTAssertEqual(store.matches(prefix: "hel").map(\.word), ["Hello"])
		XCTAssertEqual(store.matches(prefix: "HE").map(\.word), ["Hello"])
	}

	func testMatch_emptyPrefix_returnsNothing() {
		store.learn("hello", fromContextType: .prose)
		XCTAssertTrue(store.matches(prefix: "").isEmpty)
	}

	// MARK: - Filters

	func testFilter_tooShort_skipped() {
		store.learn("ab", fromContextType: .prose)
		XCTAssertEqual(store.count, 0)
	}

	func testFilter_minLength_kept() {
		store.learn("abc", fromContextType: .prose)
		XCTAssertEqual(store.count, 1)
	}

	func testFilter_tooLong_skipped() {
		store.learn(String(repeating: "a", count: 26), fromContextType: .prose)
		XCTAssertEqual(store.count, 0)
	}

	func testFilter_allDigits_skipped() {
		store.learn("2026", fromContextType: .prose)
		XCTAssertEqual(store.count, 0)
	}

	func testFilter_mixedAlphanumeric_skipped() {
		store.learn("ipv6", fromContextType: .prose)
		store.learn("h2o", fromContextType: .prose)
		XCTAssertEqual(store.count, 0)
	}

	func testFilter_denied_neverLearns() {
		store.learn("password", fromContextType: .denied)
		XCTAssertEqual(store.count, 0)
	}

	// MARK: - Email context bypasses prose filters

	func testEmail_learnsWholeAddress_despiteLengthAndMix() {
		let email = "martin.svoboda026@gmail.com"
		store.learn(email, fromContextType: .emailAddress)
		XCTAssertEqual(store.matches(prefix: "martin").map(\.word), [email])
	}

	func testEmail_overSanityCap_skipped() {
		let huge = String(repeating: "a", count: 50) + "@" + String(repeating: "b", count: 60) + ".com"
		store.learn(huge, fromContextType: .emailAddress)
		XCTAssertEqual(store.count, 0)
	}

	// MARK: - Eviction

	func testEviction_dropsLowestCountFirst() {
		// Fill to capacity with count-2 words (via the filter-free email context for simple test
		// strings), then add a count-1 newcomer over the cap; the low-count newcomer is evicted.
		let now = Date(timeIntervalSince1970: 1_000)
		for index in 0..<PersonalRecentsStore.capacity {
			let word = "word\(index)@x.com"
			store.learn(word, fromContextType: .emailAddress, now: now)
			store.learn(word, fromContextType: .emailAddress, now: now)
		}
		XCTAssertEqual(store.count, PersonalRecentsStore.capacity)
		store.learn("newcomer@x.com", fromContextType: .emailAddress, now: now.addingTimeInterval(10))
		// Still at capacity, and the freshly-added single-count word lost (lowest count).
		XCTAssertEqual(store.count, PersonalRecentsStore.capacity)
		XCTAssertTrue(store.matches(prefix: "newcomer").isEmpty)
	}

	func testEviction_breaksCountTieByLeastRecentlyUsed() {
		let base = Date(timeIntervalSince1970: 1_000)
		for index in 0..<PersonalRecentsStore.capacity {
			// Each word count 1; earlier indices get earlier (older) timestamps.
			store.learn("alpha\(index)@x.com", fromContextType: .emailAddress, now: base.addingTimeInterval(Double(index)))
		}
		store.learn("newcomer@x.com", fromContextType: .emailAddress, now: base.addingTimeInterval(10_000))
		// All counts equal (1), so the least-recently-used (oldest timestamp = alpha0) is evicted.
		XCTAssertTrue(store.matches(prefix: "alpha0@").isEmpty, "oldest entry should be evicted on a count tie")
		XCTAssertFalse(store.matches(prefix: "newcomer").isEmpty)
	}

	// MARK: - Clear

	func testClear_wipesEverything() {
		store.learn("hello", fromContextType: .prose)
		store.learn("world", fromContextType: .prose)
		XCTAssertEqual(store.count, 2)
		store.clear()
		XCTAssertEqual(store.count, 0)
		XCTAssertTrue(store.matches(prefix: "hel").isEmpty)
	}

	// MARK: - Persistence round-trips through a second instance

	func testPersistence_survivesNewStoreInstance() {
		store.learn("hello", fromContextType: .prose)
		let reopened = PersonalRecentsStore(store: appStore)
		XCTAssertEqual(reopened.matches(prefix: "hel").first?.count, 1)
	}
}
