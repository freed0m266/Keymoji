import Foundation

/// Thread-safe, file-backed in-memory index of the personal learned-words pool (task 73, Phase A).
///
/// Replaces the old per-keystroke "decode the whole UserDefaults JSON, then linearly scan every word
/// with a per-character diacritic fold" with:
///  - the pool loaded **once** into memory (truth source is a single JSON file in the App Group
///    container),
///  - an `O(1 hash + k)` prefix lookup via a bucket index keyed on the folded first character
///    (`k` = bucket size), and
///  - `O(1)` learns plus a **debounced, atomic background write** so the keystroke path never blocks
///    on disk.
///
/// **Match semantics are unchanged.** The bucket only narrows the candidate set to words whose folded
/// first character equals the prefix's — exactly the words `directionalPrefixMatch` could ever accept
/// (it rejects everything else at `i == 0`). Within a bucket the original directional, diacritic-aware
/// match runs verbatim, so `matches(prefix:)` returns a bit-identical set to the old full scan.
///
/// `@unchecked Sendable`: every access to the mutable index is serialized by `lock`; disk writes run
/// on a dedicated serial queue. `matches` is safe to call from a background task (Phase C).
final class LearnedWordsIndex: @unchecked Sendable {

	/// One stored word. `count`/`lastUsed` persist to disk; `folded` is the precomputed
	/// diacritic-stripped, lowercased form, recomputed on load so `matches` never folds the whole word.
	struct Entry {
		var count: Int
		var lastUsed: Double
		let folded: String
	}

	/// On-disk shape: `{ word: { count, lastUsed } }`. The folded form is derived on load, not stored.
	private struct PersistedEntry: Codable {
		let count: Int
		let lastUsed: Double
	}

	private let fileURL: URL
	private let capacity: Int
	/// Headroom above `capacity` the in-memory pool may grow to before a background write trims it back
	/// down. Keeps eviction off the per-`learn` hot path (amortized batch-trim). `flush()` always trims
	/// to exactly `capacity` regardless of slack.
	private let evictionSlack: Int

	private let lock = NSLock()
	/// word (lowercased, diacritics preserved) → entry.
	private var entries: [String: Entry] = [:]
	/// folded first character → the set of word keys whose folded first character is that string.
	private var buckets: [String: Set<String>] = [:]

	/// All disk I/O runs here, keeping the keystroke path off the filesystem.
	private let writeQueue = DispatchQueue(label: "com.freedommartin.keymoji.learnedwords.write", qos: .utility)
	private var pendingWrite: DispatchWorkItem?
	private var dirty = false
	/// Window over which successive learns coalesce into one atomic write.
	private static let writeDebounce: DispatchTimeInterval = .milliseconds(750)

	init(fileURL: URL, capacity: Int, evictionSlack: Int) {
		self.fileURL = fileURL
		self.capacity = capacity
		self.evictionSlack = evictionSlack
		loadFromDisk()
	}

	// MARK: - Folding (moved verbatim from PersonalRecentsStore)

	/// Fixed locale for diacritic folding. Deliberately *not* the user's locale: a Turkish locale folds
	/// `i`/`İ` and `ı`/`I` differently, which would make matching depend on device settings.
	private static let foldLocale = Locale(identifier: "en_US_POSIX")

	/// Lowercased, diacritic-stripped form of `s` (`"Čauko"` → `"cauko"`).
	static func fold(_ s: String) -> String {
		s.folding(options: .diacriticInsensitive, locale: foldLocale).lowercased()
	}

	/// Bucket discriminator for a word: the folded form of its first character. Two words land in the
	/// same bucket iff their first characters fold equal — which is exactly the precondition
	/// `directionalPrefixMatch` enforces at `i == 0`, so no possible match is ever bucketed away.
	private static func bucketKey(forFolded folded: String) -> String {
		guard let first = folded.first else { return "" }
		return String(first)
	}

	/// True when `prefix` matches the start of `word` under directional diacritic tolerance. Identical
	/// to the original `PersonalRecentsStore.directionalPrefixMatch`, but with the prefix's per-character
	/// folds/lowercasing hoisted out (computed once by the caller) so they aren't recomputed per
	/// candidate.
	private static func directionalPrefixMatch(
		prefixChars p: [Character],
		prefixFolded pFolded: [String],
		prefixLower pLower: [String],
		word: String
	) -> Bool {
		let w = Array(word)
		guard w.count >= p.count else { return false }
		for i in p.indices {
			let wc = w[i]
			guard pFolded[i] == fold(String(wc)) else { return false }      // base letter must match
			if pLower[i] != pFolded[i] && pLower[i] != String(wc).lowercased() { // prefix has a diacritic → strict
				return false
			}
		}
		return true
	}

	// MARK: - Read

	func matches(prefix: String) -> [(word: String, count: Int)] {
		let foldedPrefix = Self.fold(prefix)
		guard let firstFolded = foldedPrefix.first else { return [] }
		let bucket = String(firstFolded)
		let p = Array(prefix)
		let pFolded = p.map { Self.fold(String($0)) }
		let pLower = p.map { String($0).lowercased() }

		lock.lock(); defer { lock.unlock() }
		guard let keys = buckets[bucket] else { return [] }
		var result: [(word: String, count: Int)] = []
		for key in keys {
			guard let entry = entries[key] else { continue }
			// Cheap necessary pre-filter: `directionalPrefixMatch` can only accept a word whose folded
			// form starts with the folded prefix (when it accepts, every prefix char folds equal to the
			// corresponding word char, so the folded strings agree over the prefix). `folded` is
			// precomputed, so this is an allocation-free `String.hasPrefix` that skips most of the bucket
			// without re-folding each candidate. It never rejects a true match, so the result stays
			// bit-identical to the full scan; the exact directional check below remains authoritative.
			guard entry.folded.hasPrefix(foldedPrefix) else { continue }
			if Self.directionalPrefixMatch(prefixChars: p, prefixFolded: pFolded, prefixLower: pLower, word: key) {
				result.append((word: key, count: entry.count))
			}
		}
		return result
	}

	var count: Int {
		lock.lock(); defer { lock.unlock() }
		return entries.count
	}

	func allLearnedWords() -> [LearnedWord] {
		lock.lock(); defer { lock.unlock() }
		return entries.map { LearnedWord(word: $0.key, count: $0.value.count, lastUsed: $0.value.lastUsed) }
	}

	// MARK: - Write (hot path = O(1) + debounced disk)

	/// Learn `key` (already lowercased + filtered by `PersonalRecentsStore`). `O(1)` in-memory mutation
	/// plus a debounced atomic write — no synchronous decode/encode/disk.
	func learn(_ key: String, now: Double) {
		lock.lock()
		if var entry = entries[key] {
			entry.count += 1
			entry.lastUsed = now
			entries[key] = entry
		} else {
			let folded = Self.fold(key)
			entries[key] = Entry(count: 1, lastUsed: now, folded: folded)
			buckets[Self.bucketKey(forFolded: folded), default: []].insert(key)
		}
		dirty = true
		lock.unlock()
		scheduleWrite()
	}

	/// Remove one word. Returns whether anything was removed (callers skip the cross-process ping on a
	/// no-op). Flush is the caller's responsibility so the disk reflects the removal before any notify.
	func remove(_ key: String) -> Bool {
		lock.lock(); defer { lock.unlock() }
		guard let entry = entries.removeValue(forKey: key) else { return false }
		let bucket = Self.bucketKey(forFolded: entry.folded)
		buckets[bucket]?.remove(key)
		if buckets[bucket]?.isEmpty == true { buckets[bucket] = nil }
		dirty = true
		return true
	}

	/// Wipe the whole pool. Caller flushes to persist the empty file.
	func clear() {
		lock.lock(); defer { lock.unlock() }
		entries.removeAll()
		buckets.removeAll()
		dirty = true
	}

	private func scheduleWrite() {
		lock.lock()
		pendingWrite?.cancel()
		let work = DispatchWorkItem { [weak self] in self?.performWrite(forceTrim: false) }
		pendingWrite = work
		lock.unlock()
		writeQueue.asyncAfter(deadline: .now() + Self.writeDebounce, execute: work)
	}

	/// Synchronously flush any pending changes and trim to exactly `capacity`. Used on
	/// `viewWillDisappear`, and after host-app `remove`/`clear`, so the disk is authoritative before a
	/// cross-process notification fires. Serialized onto `writeQueue` so it can't race a debounced write.
	func flush() {
		lock.lock()
		pendingWrite?.cancel()
		pendingWrite = nil
		lock.unlock()
		writeQueue.sync { self.performWrite(forceTrim: true) }
	}

	/// Re-read the pool from disk, discarding any pending local write. Driven by the host-app
	/// `learnedWordsChanged` Darwin notification (and the extension's `viewWillAppear` baseline) so a
	/// host edit is reflected live.
	///
	/// The cancel runs *through* `writeQueue` (serial), so any debounced write already executing finishes
	/// first and no later one is left pending — without this, an in-flight stale snapshot could land on
	/// disk after the host's flushed edit and resurrect removed words. `loadFromDisk` then runs after the
	/// queue is idle and on the same (main) actor as `learn`, so nothing writes between the drain and the
	/// read. Last-writer-wins: the on-disk state (the host's change) supersedes any not-yet-flushed local
	/// learns — acceptable for the rare "editing while typing" overlap, and the keyboard also flushes on
	/// disappear so there are normally no pending writes when the host edits.
	func reload() {
		writeQueue.sync {
			lock.lock()
			pendingWrite?.cancel()
			pendingWrite = nil
			dirty = false
			lock.unlock()
		}
		loadFromDisk()
	}

	// MARK: - Eviction

	/// Drop the lowest-priority entries until the pool is back at `capacity`. Priority is the same
	/// `(count, lastUsed)` order the old per-learn eviction used; the final word tie-break keeps the
	/// alphabetically-earlier word, deterministically. Runs under `lock`, off the keystroke hot path
	/// (from a background write / flush).
	private func trimLocked() {
		guard entries.count > capacity else { return }
		let survivors = entries.sorted { lhs, rhs in
			if lhs.value.count != rhs.value.count { return lhs.value.count > rhs.value.count }
			if lhs.value.lastUsed != rhs.value.lastUsed { return lhs.value.lastUsed > rhs.value.lastUsed }
			return lhs.key < rhs.key
		}.prefix(capacity)

		var newEntries: [String: Entry] = [:]
		newEntries.reserveCapacity(survivors.count)
		var newBuckets: [String: Set<String>] = [:]
		for (key, entry) in survivors {
			newEntries[key] = entry
			newBuckets[Self.bucketKey(forFolded: entry.folded), default: []].insert(key)
		}
		entries = newEntries
		buckets = newBuckets
	}

	// MARK: - Persistence

	private func performWrite(forceTrim: Bool) {
		lock.lock()
		let overflowing = entries.count > capacity + evictionSlack
		let shouldTrim = forceTrim ? entries.count > capacity : overflowing
		if shouldTrim { trimLocked() }
		guard dirty || shouldTrim else { lock.unlock(); return }
		let snapshot = entries
		dirty = false
		lock.unlock()
		writeToDisk(snapshot)
	}

	private func loadFromDisk() {
		guard let data = readData(),
		      let decoded = try? JSONDecoder().decode([String: PersistedEntry].self, from: data)
		else { return }
		var newEntries: [String: Entry] = [:]
		newEntries.reserveCapacity(decoded.count)
		var newBuckets: [String: Set<String>] = [:]
		for (key, value) in decoded {
			let folded = Self.fold(key)
			newEntries[key] = Entry(count: value.count, lastUsed: value.lastUsed, folded: folded)
			newBuckets[Self.bucketKey(forFolded: folded), default: []].insert(key)
		}
		lock.lock()
		entries = newEntries
		buckets = newBuckets
		lock.unlock()
	}

	private func readData() -> Data? {
		let coordinator = NSFileCoordinator()
		var coordinationError: NSError?
		var data: Data?
		coordinator.coordinate(readingItemAt: fileURL, options: [], error: &coordinationError) { url in
			data = try? Data(contentsOf: url)
		}
		return data
	}

	private func writeToDisk(_ snapshot: [String: Entry]) {
		let persisted = snapshot.mapValues { PersistedEntry(count: $0.count, lastUsed: $0.lastUsed) }
		guard let data = try? JSONEncoder().encode(persisted) else { return }
		let coordinator = NSFileCoordinator()
		var coordinationError: NSError?
		coordinator.coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordinationError) { url in
			try? data.write(to: url, options: .atomic)
		}
	}
}
