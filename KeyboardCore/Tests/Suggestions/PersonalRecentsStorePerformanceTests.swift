import XCTest
import KeymojiCore
@testable import KeyboardCore

/// Task 73 — perf budget benchmarks. Exercise the two hot-path operations against a synthetic 10k
/// learned-words pool: `matches(prefix:)` (runs on every keystroke) and `learn()` (runs on every
/// word boundary).
///
/// These are wall-clock `measure` tests; the absolute numbers are machine-dependent (and the real
/// 120 Hz frame budget is verified on a physical device — see the task's "Jak testovat"). What
/// matters is the *shape*: `matches` no longer scales with pool size and does no per-keystroke JSON
/// decode or full-word folding, and `learn` is `O(1)` in-memory with the disk write deferred.
///
/// Baseline (pre-Phase-A UserDefaults/JSON store, old cap 1000, iPhone 17 sim): `matches` ≈ 2.5 ms,
/// `learn` ≈ 2.5 ms per call (100-call blocks averaged ~0.25 s). Post-Phase-A numbers are recorded
/// in the task file.
final class PersonalRecentsStorePerformanceTests: XCTestCase {

	/// Pool size the keyboard must stay smooth at (task 73 target).
	private static let poolSize = 10_000

	private var directory: URL!
	private var store: PersonalRecentsStore!

	override func setUpWithError() throws {
		try super.setUpWithError()
		directory = FileManager.default.temporaryDirectory
			.appendingPathComponent("keymoji.perf.\(UUID().uuidString)", isDirectory: true)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		store = PersonalRecentsStore(directory: directory)
		for index in 0..<Self.poolSize {
			store.learn(Self.syntheticWord(index), fromContextType: .prose)
		}
		store.flush()
	}

	override func tearDownWithError() throws {
		store = nil
		try? FileManager.default.removeItem(at: directory)
		directory = nil
		try super.tearDownWithError()
	}

	/// 4-letter lowercase words from a base-26 expansion of the index — all valid prose (≥3 letters,
	/// no digits), all distinct (26^4 ≫ 10k).
	private static func syntheticWord(_ index: Int) -> String {
		var n = index
		var chars: [Character] = []
		for _ in 0..<4 {
			chars.append(Character(UnicodeScalar(UInt8(97 + n % 26))))
			n /= 26
		}
		return String(chars)
	}

	/// `matches(prefix:)` on a full 10k pool — the per-keystroke completion lookup.
	func testPerformance_matches_at10k() {
		measure {
			for _ in 0..<100 { _ = store.matches(prefix: "ab") }
		}
	}

	/// `learn()` re-learning an existing word in a full 10k pool — the per-word-boundary hot path
	/// (in-memory only; the atomic write is debounced off this path).
	func testPerformance_learn_existingWord_at10k() {
		let word = Self.syntheticWord(0)
		measure {
			for _ in 0..<100 { store.learn(word, fromContextType: .prose) }
		}
	}
}
