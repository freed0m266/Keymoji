import Foundation
import KeymojiCore

/// Read access to the personal recents pool. The completion provider depends only on this narrow
/// protocol so it can be mocked in tests without touching the store.
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

/// Learns and persists the words a user types so they can be offered as completions.
///
/// Backed by `LearnedWordsIndex` (task 73): a single JSON file in the App Group container, loaded
/// once into an in-memory bucket index. `matches`/`learn` are off the old per-keystroke
/// decode/scan/encode path — see that type for the storage model. This struct stays the public face:
/// it owns the **learning policy** (lowercasing, length/shape filters, email vs. prose context) and
/// the cross-process invalidation ping; the index owns lookup, persistence, and eviction.
///
/// **PII-adjacent.** Entries can include names, slang, and (in email fields) whole addresses. The
/// pool is capped at `capacity`, lives only in the app's private shared container, never leaves the
/// device, and is wiped by the Settings "Clear learned words" button.
///
/// All state lives in the reference-typed index, so `learn`/`remove`/`clear` are not `mutating` —
/// marking them so would be misleading and force callers to hold the store in a `var`.
public struct PersonalRecentsStore: PersonalRecentsReading {

	/// Max distinct words retained. Beyond this, the index batch-trims by `(count, lastUsed)` on its
	/// next background write. Raised 1000 → 10000 (task 73): the keyboard must stay smooth at 10k.
	public static let capacity = 10_000
	/// In-memory headroom above `capacity` before the background write trims back down. Keeps eviction
	/// off the per-`learn` hot path.
	public static let evictionSlack = 256
	/// Shortest word learned from prose (LEN3). Below this, completion saves nothing meaningful.
	public static let minLength = 3
	/// Longest word learned from prose. Guards against pasted blobs polluting the pool.
	public static let maxLength = 25
	/// Hard ceiling for a whole-field email token (sanity guard against pasted multi-line junk).
	public static let maxEmailLength = 100

	/// File name for the pool inside its container subdirectory.
	private static let fileName = "recents.json"
	/// Container subdirectory holding the pool file.
	private static let subdirectory = "LearnedWords"

	private let index: LearnedWordsIndex

	// MARK: - Init

	/// Production initializer. Resolves the App Group container, shares one in-memory index per
	/// container (so every `PersonalRecentsStore` in a process sees the same pool), and clears the
	/// legacy UserDefaults blobs on first touch. `store` is used only for that one-time legacy cleanup.
	public init(store: AppGroupStore = .shared) {
		self.index = Self.sharedIndex(
			forDirectory: Self.containerDirectory(),
			capacity: Self.capacity,
			evictionSlack: Self.evictionSlack
		)
		Self.removeLegacyKeys(from: store)
	}

	/// Directory-injected initializer: a non-shared index rooted at `directory` (bypasses the
	/// process-wide registry). Each call gets a fresh index that loads from `directory/recents.json`, so
	/// two stores on the same directory verify real disk round-trips, and a custom `capacity` keeps
	/// eviction tests small and fast. Public so feature tests (e.g. `LearnedWordsEditorViewModel`) can
	/// inject an isolated, throwaway pool instead of touching the shared App Group container.
	public init(directory: URL, capacity: Int = PersonalRecentsStore.capacity, evictionSlack: Int = PersonalRecentsStore.evictionSlack) {
		let fileURL = directory.appendingPathComponent(Self.fileName)
		self.index = LearnedWordsIndex(fileURL: fileURL, capacity: capacity, evictionSlack: evictionSlack)
	}

	// MARK: - Read

	public func matches(prefix: String) -> [(word: String, count: Int)] {
		guard !prefix.isEmpty else { return [] }
		return Perf.measure("matches") { index.matches(prefix: prefix) }
	}

	/// Total distinct learned words. Drives the Settings counter.
	public var count: Int {
		index.count
	}

	/// All learned words, unsorted. The management screen owns the sort order.
	public func allLearnedWords() -> [LearnedWord] {
		index.allLearnedWords()
	}

	// MARK: - Write

	/// Learn one word. Idempotent: a repeat increments its count and refreshes its last-used time.
	/// Silently no-ops when the word fails the context's filters.
	///
	/// The word is canonicalized to **lowercase (diacritics preserved)** before storage, so "Ale" and
	/// "ale" collapse to a single "ale" entry while "rada" and "ráda" stay distinct. This is the store's
	/// invariant — both learning paths (prose and email) funnel through here.
	public func learn(_ word: String, fromContextType context: TextContextType, now: Date = Date()) {
		Perf.measure("learn") {
			let key = word.lowercased()
			guard passesFilters(key, context: context) else { return }
			index.learn(key, now: now.timeIntervalSince1970)
		}
	}

	/// Remove a single word from the pool. No-op if absent. Flushes to disk and pings the other process
	/// (host edit → running keyboard) so the change is picked up live.
	public func remove(_ word: String) {
		guard index.remove(word) else { return }
		index.flush()
		SettingsChangeNotifier.shared.post(.learnedWordsChanged)
	}

	/// Wipe the entire pool. Used by Settings → Clear learned words. Flushes + pings like `remove`.
	public func clear() {
		index.clear()
		index.flush()
		SettingsChangeNotifier.shared.post(.learnedWordsChanged)
	}

	/// Synchronously persist any pending learns. Called on `viewWillDisappear` so debounced writes
	/// aren't lost when the keyboard goes away.
	public func flush() {
		index.flush()
	}

	/// Re-read the pool from disk. Called on the `learnedWordsChanged` Darwin notification and on
	/// `viewWillAppear` so a host-app edit reflects in the running keyboard.
	public func reload() {
		index.reload()
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

	// MARK: - Container & legacy cleanup

	/// App Group container subdirectory holding the pool file. Falls back to caches if the container is
	/// unavailable (entitlement misconfig) so the keyboard still functions, just without cross-process
	/// sharing — matching `AppGroupStore`'s soft-fail posture.
	private static func containerDirectory() -> URL {
		let manager = FileManager.default
		let base = manager.containerURL(forSecurityApplicationGroupIdentifier: appGroupSuiteName)
			?? manager.urls(for: .cachesDirectory, in: .userDomainMask).first
			?? manager.temporaryDirectory
		let directory = base.appendingPathComponent(subdirectory, isDirectory: true)
		try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
		return directory
	}

	/// Drop the pre-task-73 UserDefaults blobs (`wordCompletionRecents` / `…LastUsed`). They're no
	/// longer read — the file store is the truth source — and there's no migration (pre-release).
	private static func removeLegacyKeys(from store: AppGroupStore) {
		if store.wordCompletionRecentsJSON != nil { store.wordCompletionRecentsJSON = nil }
		if store.wordCompletionRecentsLastUsedJSON != nil { store.wordCompletionRecentsLastUsedJSON = nil }
	}

	// MARK: - Shared index registry

	private static let registryLock = NSLock()
	/// One index per container directory, shared across all stores in the process. Guarded by
	/// `registryLock`.
	nonisolated(unsafe) private static var registry: [URL: LearnedWordsIndex] = [:]

	private static func sharedIndex(forDirectory directory: URL, capacity: Int, evictionSlack: Int) -> LearnedWordsIndex {
		let fileURL = directory.appendingPathComponent(fileName)
		registryLock.lock(); defer { registryLock.unlock() }
		if let existing = registry[fileURL] { return existing }
		let index = LearnedWordsIndex(fileURL: fileURL, capacity: capacity, evictionSlack: evictionSlack)
		registry[fileURL] = index
		return index
	}
}
