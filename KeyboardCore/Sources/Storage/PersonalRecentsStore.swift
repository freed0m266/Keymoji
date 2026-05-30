import Foundation
import KeyboCore

/// Read access to the personal recents pool. The completion provider depends only on this narrow
/// protocol so it can be mocked in tests without touching `AppGroupStore`.
public protocol PersonalRecentsReading: Sendable {
	/// Words whose case-insensitive form starts with `prefix`, paired with their learned count.
	func matches(prefix: String) -> [(word: String, count: Int)]
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
	public static let capacity = 500
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

	public func matches(prefix: String) -> [(word: String, count: Int)] {
		guard !prefix.isEmpty else { return [] }
		let loweredPrefix = prefix.lowercased()
		return loadCounts()
			.filter { $0.key.lowercased().hasPrefix(loweredPrefix) }
			.map { (word: $0.key, count: $0.value) }
	}

	/// Total distinct learned words. Drives the Settings counter.
	public var count: Int {
		loadCounts().count
	}

	// MARK: - Write

	/// Learn one word. Idempotent: a repeat increments its count and refreshes its last-used time.
	/// Silently no-ops when the word fails the context's filters. Evicts the lowest-priority entry
	/// when the pool would exceed `capacity`.
	public func learn(_ word: String, fromContextType context: TextContextType, now: Date = Date()) {
		guard passesFilters(word, context: context) else { return }

		var counts = loadCounts()
		var lastUsed = loadLastUsed()

		counts[word, default: 0] += 1
		lastUsed[word] = now.timeIntervalSince1970

		evictIfNeeded(counts: &counts, lastUsed: &lastUsed)

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
