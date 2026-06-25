import XCTest
import KeymojiCore
@testable import KeyboardCore

final class PersonalRecentsStoreTests: XCTestCase {

	private var tempDirs: [URL] = []
	private var directory: URL!
	private var store: PersonalRecentsStore!

	override func setUpWithError() throws {
		try super.setUpWithError()
		directory = makeTempDir()
		store = PersonalRecentsStore(directory: directory)
	}

	override func tearDownWithError() throws {
		store = nil
		directory = nil
		for dir in tempDirs { try? FileManager.default.removeItem(at: dir) }
		tempDirs = []
		try super.tearDownWithError()
	}

	// MARK: - Test helpers

	private func makeTempDir() -> URL {
		let dir = FileManager.default.temporaryDirectory
			.appendingPathComponent("keymoji.recents.\(UUID().uuidString)", isDirectory: true)
		try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		tempDirs.append(dir)
		return dir
	}

	/// A store with a small capacity in its own temp directory, for fast/clear eviction tests.
	private func makeStore(capacity: Int) -> PersonalRecentsStore {
		PersonalRecentsStore(directory: makeTempDir(), capacity: capacity, evictionSlack: 0)
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
		// Stored lowercase regardless of typed casing; prefix matches case-insensitively.
		store.learn("Hello", fromContextType: .prose)
		XCTAssertEqual(store.matches(prefix: "hel").map(\.word), ["hello"])
		XCTAssertEqual(store.matches(prefix: "HE").map(\.word), ["hello"])
	}

	func testMatch_emptyPrefix_returnsNothing() {
		store.learn("hello", fromContextType: .prose)
		XCTAssertTrue(store.matches(prefix: "").isEmpty)
	}

	// MARK: - Lowercase canonicalization (no case duplicates)

	func testLearn_caseVariants_collapseToOneLowercaseEntry() {
		store.learn("Ale", fromContextType: .prose)
		store.learn("ale", fromContextType: .prose)
		XCTAssertEqual(store.count, 1)
		let matches = store.matches(prefix: "al")
		XCTAssertEqual(matches.map(\.word), ["ale"])
		XCTAssertEqual(matches.first?.count, 2)
	}

	func testLearn_storesDiacriticsLowercased() {
		store.learn("Čauko", fromContextType: .prose)
		XCTAssertEqual(store.allLearnedWords().map(\.word), ["čauko"])
	}

	// MARK: - Directional diacritic-tolerant matching

	func testMatch_prefixWithoutDiacritics_isLenient() {
		store.learn("čauko", fromContextType: .prose)
		XCTAssertEqual(store.matches(prefix: "cauk").map(\.word), ["čauko"])
	}

	func testMatch_prefixWithDiacritics_isStrict() {
		store.learn("čauko", fromContextType: .prose)
		store.learn("cauko", fromContextType: .prose)
		// Accented prefix must match only the accented stored form.
		XCTAssertEqual(store.matches(prefix: "čauk").map(\.word), ["čauko"])
	}

	func testMatch_baselinePrefix_returnsBothDiacriticVariants() {
		store.learn("rada", fromContextType: .prose)
		store.learn("ráda", fromContextType: .prose)
		XCTAssertEqual(Set(store.matches(prefix: "rad").map(\.word)), ["rada", "ráda"])
	}

	func testMatch_uppercaseAccentlessPrefix_stillMatchesAccentedWord() {
		store.learn("čauko", fromContextType: .prose)
		XCTAssertEqual(store.matches(prefix: "CAU").map(\.word), ["čauko"])
	}

	func testMatch_asciiPrefix_unaffectedByFold() {
		// Regression: pure-ASCII matching behaves exactly as before, now on lowercase keys.
		store.learn("Hello", fromContextType: .prose)
		store.learn("help", fromContextType: .prose)
		XCTAssertEqual(Set(store.matches(prefix: "hel").map(\.word)), ["hello", "help"])
		XCTAssertTrue(store.matches(prefix: "wor").isEmpty)
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

	func testFilter_allDigits_nowLearned() {
		// Task 74: numbers (years, phones) are learned from prose. The display-side `minSuggestCount`
		// threshold — not a learn-time reject — is what keeps one-off codes from being offered.
		store.learn("2026", fromContextType: .prose)
		store.learn("604593010", fromContextType: .prose)
		XCTAssertEqual(Set(store.allLearnedWords().map(\.word)), ["2026", "604593010"])
	}

	func testFilter_mixedAlphanumeric_nowLearned() {
		// Task 74: alphanumeric nicks (`freedom266`) and tokens (`ipv6`, `h2o`) are learned, not rejected.
		store.learn("freedom266", fromContextType: .prose)
		store.learn("ipv6", fromContextType: .prose)
		store.learn("h2o", fromContextType: .prose)
		XCTAssertEqual(Set(store.allLearnedWords().map(\.word)), ["freedom266", "ipv6", "h2o"])
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

	// MARK: - Eviction (amortized batch-trim, normalized by flush)

	func testEviction_dropsLowestCountFirst() {
		let small = makeStore(capacity: 5)
		let now = Date(timeIntervalSince1970: 1_000)
		// Fill capacity with count-2 words (via the filter-free email context for simple test strings).
		for index in 0..<5 {
			small.learn("word\(index)@x.com", fromContextType: .emailAddress, now: now)
			small.learn("word\(index)@x.com", fromContextType: .emailAddress, now: now)
		}
		// Add a count-1 newcomer over the cap; the batch-trim (forced by flush) evicts the low-count one.
		small.learn("newcomer@x.com", fromContextType: .emailAddress, now: now.addingTimeInterval(10))
		small.flush()
		XCTAssertEqual(small.count, 5)
		XCTAssertTrue(small.matches(prefix: "newcomer").isEmpty)
	}

	func testEviction_breaksCountTieByLeastRecentlyUsed() {
		let small = makeStore(capacity: 5)
		let base = Date(timeIntervalSince1970: 1_000)
		for index in 0..<5 {
			// Each word count 1; earlier indices get earlier (older) timestamps.
			small.learn("alpha\(index)@x.com", fromContextType: .emailAddress, now: base.addingTimeInterval(Double(index)))
		}
		small.learn("newcomer@x.com", fromContextType: .emailAddress, now: base.addingTimeInterval(10_000))
		small.flush()
		// All counts equal (1), so the least-recently-used (oldest timestamp = alpha0) is evicted.
		XCTAssertTrue(small.matches(prefix: "alpha0@").isEmpty, "oldest entry should be evicted on a count tie")
		XCTAssertFalse(small.matches(prefix: "newcomer").isEmpty)
	}

	func testEviction_batchTrim_keepsHighestPriorityEntries() {
		let small = makeStore(capacity: 3)
		let now = Date(timeIntervalSince1970: 1_000)
		// Distinct counts so survivor priority is unambiguous.
		let plan: [(word: String, count: Int)] = [
			("aaa", 5), ("bbb", 4), ("ccc", 3), ("ddd", 2), ("eee", 1)
		]
		for entry in plan {
			for _ in 0..<entry.count { small.learn(entry.word, fromContextType: .prose, now: now) }
		}
		small.flush()
		XCTAssertEqual(small.count, 3)
		XCTAssertEqual(Set(small.allLearnedWords().map(\.word)), ["aaa", "bbb", "ccc"])
	}

	// MARK: - Offerable count (task 81: Settings counter = words at/above the suggest threshold)

	func testCountAtLeast_countsOnlyEntriesAtOrAboveThreshold() {
		// 5 words used twice (offerable) + 3 used once (sub-threshold singletons).
		for index in 0..<5 {
			store.learn("word\(index)", fromContextType: .prose)
			store.learn("word\(index)", fromContextType: .prose)
		}
		for index in 0..<3 {
			store.learn("once\(index)", fromContextType: .prose)
		}
		XCTAssertEqual(store.count, 8, "total counts every distinct word")
		XCTAssertEqual(store.count(atLeast: 2), 5, "offerable count excludes the singletons")
	}

	func testCountAtLeast_onlySingletons_isZero() {
		store.learn("alpha", fromContextType: .prose)
		store.learn("bravo", fromContextType: .prose)
		XCTAssertEqual(store.count, 2)
		XCTAssertEqual(store.count(atLeast: 2), 0, "a pool of only singletons offers nothing")
	}

	func testCountAtLeast_emptyStore_isZero() {
		XCTAssertEqual(store.count(atLeast: 2), 0)
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

	// MARK: - List & remove

	func testAllLearnedWords_returnsCountsAndLastUsed() {
		store.learn("hello", fromContextType: .prose, now: Date(timeIntervalSince1970: 100))
		store.learn("hello", fromContextType: .prose, now: Date(timeIntervalSince1970: 200))
		store.learn("world", fromContextType: .prose, now: Date(timeIntervalSince1970: 300))

		let words = store.allLearnedWords()
		XCTAssertEqual(Set(words.map(\.word)), ["hello", "world"])
		let hello = words.first { $0.word == "hello" }
		XCTAssertEqual(hello?.count, 2)
		XCTAssertEqual(hello?.lastUsed, 200)
		let world = words.first { $0.word == "world" }
		XCTAssertEqual(world?.count, 1)
		XCTAssertEqual(world?.lastUsed, 300)
	}

	func testAllLearnedWords_emptyStore_returnsEmpty() {
		XCTAssertTrue(store.allLearnedWords().isEmpty)
	}

	func testRemove_deletesFromBothMaps_leavingOthersUntouched() {
		store.learn("hello", fromContextType: .prose, now: Date(timeIntervalSince1970: 100))
		store.learn("hello", fromContextType: .prose, now: Date(timeIntervalSince1970: 200))
		store.learn("world", fromContextType: .prose, now: Date(timeIntervalSince1970: 300))

		store.remove("hello")

		XCTAssertEqual(store.count, 1)
		XCTAssertTrue(store.matches(prefix: "hel").isEmpty)
		let remaining = store.allLearnedWords()
		XCTAssertEqual(remaining.map(\.word), ["world"])
		XCTAssertEqual(remaining.first?.count, 1)
		XCTAssertEqual(remaining.first?.lastUsed, 300)
	}

	func testRemove_absentWord_isNoOp() {
		store.learn("hello", fromContextType: .prose)
		store.remove("missing")
		XCTAssertEqual(store.count, 1)
		XCTAssertEqual(store.matches(prefix: "hel").first?.count, 1)
	}

	// MARK: - Persistence round-trips through a fresh on-disk read

	func testPersistence_survivesNewStoreInstance() {
		store.learn("hello", fromContextType: .prose)
		store.flush()
		// A second store over the same directory loads the file fresh from disk (non-shared index).
		let reopened = PersonalRecentsStore(directory: directory)
		XCTAssertEqual(reopened.matches(prefix: "hel").first?.count, 1)
	}

	// MARK: - Cross-process invalidation (host edit → keyboard reload)

	func testReload_picksUpExternalEdits() {
		// Two independent stores over the same file model the host app + the running keyboard.
		let shared = makeTempDir()
		let host = PersonalRecentsStore(directory: shared)
		let keyboard = PersonalRecentsStore(directory: shared)

		host.learn("hello", fromContextType: .prose)
		host.learn("world", fromContextType: .prose)
		host.flush()

		keyboard.reload()
		XCTAssertEqual(Set(keyboard.allLearnedWords().map(\.word)), ["hello", "world"])

		// Host removes one (writes disk synchronously); keyboard reloads and sees the change.
		host.remove("hello")
		keyboard.reload()
		XCTAssertEqual(keyboard.allLearnedWords().map(\.word), ["world"])

		// Host clears everything; keyboard reloads to empty.
		host.clear()
		keyboard.reload()
		XCTAssertTrue(keyboard.allLearnedWords().isEmpty)
	}
}
