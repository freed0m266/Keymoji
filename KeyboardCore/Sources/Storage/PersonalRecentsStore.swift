import Foundation
import KeymojiCore

/// Read access to the personal recents pool. The completion provider depends only on this narrow
/// protocol so it can be mocked in tests without touching `AppGroupStore`.
public protocol PersonalRecentsReading: Sendable {
	/// Stored words that `prefix` matches, paired with their learned count. Matching is
	/// case-insensitive and *directionally* diacritic-tolerant: a prefix character written **without**
	/// a diacritic matches any word character with the same base letter (`c` → `c` or `č`), while a
	/// prefix character written **with** a diacritic matches only that exact accented letter
	/// (`č` → `č`, never `c`). Words are stored lowercased, so there are no case duplicates.
	func matches(prefix: String) -> [(word: String, count: Int)]
}

/// One learned word with its frequency and last-used time. Drives the management screen.
public struct LearnedWord: Sendable, Equatable {
	public let word: String
	public let count: Int
	/// Seconds since 1970, from the last-used map. Used only for recency sorting.
	public let lastUsed: Double

	public init(word: String, count: Int, lastUsed: Double) {
		self.word = word
		self.count = count
		self.lastUsed = lastUsed
	}
}

/// Learns and persists the words a user types so they can be offered as completions. Backed by two
/// JSON blobs in `AppGroupStore`: a `{word: count}` frequency map and a parallel `{word: timestamp}`
/// last-used map that breaks LRU-eviction ties.
///
/// **PII-adjacent.** Entries can include names, slang, and (in email fields) whole addresses. The
/// pool is capped at `capacity`, lives only in the app's private shared container, never leaves the
/// device, and is wiped by the Settings "Clear learned words" button.
///
/// Note: `learn`/`clear` are *not* `mutating` (despite the task sketch). All state lives in the
/// reference-typed `AppGroupStore`, so the struct itself never changes — marking them `mutating`
/// would be misleading and force callers to hold the store in a `var`.
public struct PersonalRecentsStore: PersonalRecentsReading {

	/// Max distinct words retained. Beyond this, LRU eviction by `(count, lastUsed)` kicks in.
	public static let capacity = 1000
	/// Shortest word learned from prose (LEN3). Below this, completion saves nothing meaningful.
	public static let minLength = 3
	/// Longest word learned from prose. Guards against pasted blobs polluting the pool.
	public static let maxLength = 25
	/// Hard ceiling for a whole-field email token (sanity guard against pasted multi-line junk).
	public static let maxEmailLength = 100

	private let store: AppGroupStore

	public init(store: AppGroupStore = .shared) {
		self.store = store
	}

	// MARK: - Read

	/// Fixed locale for diacritic folding. Deliberately *not* the user's locale: a Turkish locale
	/// folds `i`/`İ` and `ı`/`I` differently, which would make matching depend on device settings.
	private static let foldLocale = Locale(identifier: "en_US_POSIX")

	/// Lowercased, diacritic-stripped form of `s` (`"Čauko"` → `"cauko"`).
	private static func fold(_ s: String) -> String {
		s.folding(options: .diacriticInsensitive, locale: foldLocale).lowercased()
	}

	/// True when `prefix` matches the start of `word` under directional diacritic tolerance:
	///  - a prefix character without a diacritic matches any word character sharing its base letter
	///    (`c` → `c` or `č`),
	///  - a prefix character with a diacritic matches only that exact accented letter, case-insensitively
	///    (`č` → `č`/`Č`, never `c`).
	/// Comparison is per-`Character`; Czech accented letters are precomposed single grapheme clusters,
	/// so folding decomposes them to their base (`č`→`c`).
	private static func directionalPrefixMatch(prefix: String, word: String) -> Bool {
		let p = Array(prefix), w = Array(word)
		guard w.count >= p.count else { return false }
		for i in p.indices {
			let pc = p[i], wc = w[i]
			let pcFolded = fold(String(pc))
			guard pcFolded == fold(String(wc)) else { return false }      // base letter must match
			let pcLower = String(pc).lowercased()
			if pcLower != pcFolded && pcLower != String(wc).lowercased() { // prefix carries a diacritic → strict
				return false
			}
		}
		return true
	}

	public func matches(prefix: String) -> [(word: String, count: Int)] {
		guard !prefix.isEmpty else { return [] }
		return loadCounts()
			.filter { Self.directionalPrefixMatch(prefix: prefix, word: $0.key) }
			.map { (word: $0.key, count: $0.value) }
	}

	/// Total distinct learned words. Drives the Settings counter.
	public var count: Int {
		loadCounts().count
	}

	/// All learned words, unsorted. The management screen owns the sort order.
	public func allLearnedWords() -> [LearnedWord] {
		let counts = loadCounts()
		let lastUsed = loadLastUsed()
		return counts.map { LearnedWord(word: $0.key, count: $0.value, lastUsed: lastUsed[$0.key] ?? 0) }
	}

	// MARK: - Write

	/// Learn one word. Idempotent: a repeat increments its count and refreshes its last-used time.
	/// Silently no-ops when the word fails the context's filters. Evicts the lowest-priority entry
	/// when the pool would exceed `capacity`.
	///
	/// The word is canonicalized to **lowercase (diacritics preserved)** before storage, so "Ale"
	/// and "ale" collapse to a single "ale" entry while "rada" and "ráda" stay distinct. This is the
	/// store's invariant — both learning paths (prose and email) funnel through here.
	public func learn(_ word: String, fromContextType context: TextContextType, now: Date = Date()) {
		let key = word.lowercased()
		guard passesFilters(key, context: context) else { return }

		var counts = loadCounts()
		var lastUsed = loadLastUsed()

		counts[key, default: 0] += 1
		lastUsed[key] = now.timeIntervalSince1970

		evictIfNeeded(counts: &counts, lastUsed: &lastUsed)

		save(counts: counts, lastUsed: lastUsed)
	}

	/// Remove a single word from both maps. No-op if absent. Keeps the count and last-used maps
	/// in sync, exactly like `learn`. The keyboard reads recents live, so the next keystroke sees
	/// the change without a cross-process ping.
	public func remove(_ word: String) {
		var counts = loadCounts()
		var lastUsed = loadLastUsed()
		guard counts[word] != nil || lastUsed[word] != nil else { return }
		counts[word] = nil
		lastUsed[word] = nil
		save(counts: counts, lastUsed: lastUsed)
	}

	/// Wipe the entire pool (both maps). Used by Settings → Clear learned words.
	public func clear() {
		store.wordCompletionRecentsJSON = nil
		store.wordCompletionRecentsLastUsedJSON = nil
	}

	// MARK: - Filters

	private func passesFilters(_ word: String, context: TextContextType) -> Bool {
		switch context {
		case .denied:
			return false
		case .emailAddress:
			// Whole-field email tokens skip the prose length/shape filters (an address is longer
			// than 25 chars and mixes letters + digits). Only the sanity ceiling applies; the `@`
			// check is the caller's responsibility (it owns the field semantics).
			return !word.isEmpty && word.count <= Self.maxEmailLength
		case .prose:
			guard word.count >= Self.minLength, word.count <= Self.maxLength else { return false }
			let hasDigit = word.contains { $0.isNumber }
			let hasLetter = word.contains { $0.isLetter }
			if hasDigit && !hasLetter { return false } // all-digit (123, 2026)
			if hasDigit && hasLetter { return false }   // mixed alphanumeric (ipv6, h2o)
			return true
		}
	}

	// MARK: - Eviction

	private func evictIfNeeded(counts: inout [String: Int], lastUsed: inout [String: Double]) {
		while counts.count > Self.capacity {
			// Lowest count first, then least-recently-used; stable final tie-break on the word
			// keeps eviction deterministic for tests.
			guard let victim = counts.keys.min(by: { lhs, rhs in
				let lc = counts[lhs] ?? 0, rc = counts[rhs] ?? 0
				if lc != rc { return lc < rc }
				let lu = lastUsed[lhs] ?? 0, ru = lastUsed[rhs] ?? 0
				if lu != ru { return lu < ru }
				return lhs < rhs
			}) else { break }
			counts[victim] = nil
			lastUsed[victim] = nil
		}
	}

	// MARK: - Persistence

	private func loadCounts() -> [String: Int] {
		decode(store.wordCompletionRecentsJSON) ?? [:]
	}

	private func loadLastUsed() -> [String: Double] {
		decode(store.wordCompletionRecentsLastUsedJSON) ?? [:]
	}

	private func save(counts: [String: Int], lastUsed: [String: Double]) {
		store.wordCompletionRecentsJSON = encode(counts)
		store.wordCompletionRecentsLastUsedJSON = encode(lastUsed)
	}

	private func decode<T: Decodable>(_ json: String?) -> T? {
		guard let json, let data = json.data(using: .utf8) else { return nil }
		return try? JSONDecoder().decode(T.self, from: data)
	}

	private func encode<T: Encodable>(_ value: T) -> String? {
		guard let data = try? JSONEncoder().encode(value) else { return nil }
		return String(data: data, encoding: .utf8)
	}
}
