import Foundation
import Security
// `@preconcurrency`: `KeychainAccess.Keychain` predates `Sendable` annotations but wraps the
// thread-safe Security framework, so we treat it as concurrency-safe (see `KeychainPromoBacking`).
@preconcurrency import KeychainAccess

/// The durable anti-abuse record behind both free-Plus grants: which one-shot grants the device has
/// already consumed, and the single stacked *Plus trial expiry* they feed. Persisted in the Keychain
/// (survives reinstall best-effort) and mirrored cheaply into `AppGroupStore.promoPlusExpiresAt` for
/// the gating hot path.
public struct PromoTrialRecord: Codable, Sendable, Equatable {
	/// Whether the opt-in Welcome trial (+30 days) has been activated on this device. One-shot.
	public var welcomeConsumed: Bool
	/// Whether the cheat code promo bonus (+60 days) has been activated on this device. One-shot.
	public var cheatCodeConsumed: Bool
	/// The shared expiry both grants extend via `max(now, currentExpiry) + grantDays`. `nil` until the
	/// first grant. Never cleared once set — a lapsed expiry simply lies in the past, which keeps the
	/// idempotence flags meaningful (a consumed grant can't be re-taken after it expires).
	public var expiresAt: Date?

	public init(welcomeConsumed: Bool = false, cheatCodeConsumed: Bool = false, expiresAt: Date? = nil) {
		self.welcomeConsumed = welcomeConsumed
		self.cheatCodeConsumed = cheatCodeConsumed
		self.expiresAt = expiresAt
	}
}

/// Abstraction over the Keychain record so the grant math and idempotence are unit-testable without a
/// real Keychain (and its entitlements). Production is `PromoTrialStore`; tests inject an in-memory
/// backing. `Sendable` because both the keyboard extension and the host app hold one.
public protocol PromoTrialStoring: Sendable {
	/// The current record, default-constructed empty when nothing is stored (never optional).
	var record: PromoTrialRecord { get }
	/// Whether a promo grant is currently active against the system clock (`expiresAt` in the future).
	var isPromoActive: Bool { get }
	/// Activate the Welcome trial (+30 days). Idempotent: a second call returns the existing expiry and
	/// leaves the record untouched. Returns the (new or existing) expiry, or **`nil` if the durable
	/// Keychain write failed** — so a caller never publishes a grant that wasn't persisted.
	@discardableResult func consumeWelcome(now: Date) -> Date?
	/// Activate the cheat code promo bonus (+60 days), stacking onto any current expiry. Idempotent: a
	/// second call returns the existing expiry. Returns `nil` if the durable Keychain write failed.
	@discardableResult func consumeCheatCode(now: Date) -> Date?
}

public extension PromoTrialStoring {
	/// Grant lengths, named so the math can't drift between the store and its tests.
	static var welcomeGrantDays: Int { 30 }
	static var cheatCodeGrantDays: Int { 60 }
}

/// Minimal raw byte store the `PromoTrialStore` reads/writes through. The production conformer wraps
/// `KeychainAccess`; tests use an in-memory dictionary so the grant logic runs without entitlements.
public protocol PromoTrialKeychainBacking: Sendable {
	func data(forKey key: String) -> Data?
	/// Persist `data`. **Throws** on failure so the store never reports a one-shot grant that wasn't
	/// durably written (a swallowed write would defeat the anti-abuse record — review finding #3).
	func set(_ data: Data, forKey key: String) throws
	func removeAll()
}

/// Keychain-backed `PromoTrialStoring`. Stateless beyond its backing — `record` re-reads on every
/// access, so there's no cache to keep coherent across the host app ↔ extension processes that share
/// the access group. Reads happen only at activation and host-app launch (never the hot path), so the
/// per-access decode cost is irrelevant.
public final class PromoTrialStore: PromoTrialStoring, @unchecked Sendable {

	private let backing: PromoTrialKeychainBacking
	private static let recordKey = "promoTrialRecord"

	public init(backing: PromoTrialKeychainBacking) {
		self.backing = backing
	}

	// MARK: - PromoTrialStoring

	public var record: PromoTrialRecord {
		guard let data = backing.data(forKey: Self.recordKey),
			  let decoded = try? JSONDecoder().decode(PromoTrialRecord.self, from: data)
		else { return PromoTrialRecord() }
		return decoded
	}

	public var isPromoActive: Bool {
		guard let expiry = record.expiresAt else { return false }
		return Date() < expiry
	}

	@discardableResult
	public func consumeWelcome(now: Date) -> Date? {
		consume(now: now, addDays: Self.welcomeGrantDays, alreadyConsumed: \.welcomeConsumed) { $0.welcomeConsumed = true }
	}

	@discardableResult
	public func consumeCheatCode(now: Date) -> Date? {
		consume(now: now, addDays: Self.cheatCodeGrantDays, alreadyConsumed: \.cheatCodeConsumed) { $0.cheatCodeConsumed = true }
	}

	// MARK: - Grant math

	/// The single stacking rule shared by both grants: extend the *later* of "now" and the current
	/// expiry by `addDays`. Stacking on a running trial adds to its end; granting after a lapsed one
	/// starts fresh from now. Uses a flat 24h day — clock drift / DST is an accepted rounding error.
	public static func nextExpiry(currentExpiry: Date?, now: Date, addDays: Int) -> Date {
		let base = max(now, currentExpiry ?? now)
		return base.addingTimeInterval(TimeInterval(addDays) * 24 * 60 * 60)
	}

	// MARK: - Private

	private func consume(
		now: Date,
		addDays: Int,
		alreadyConsumed flag: KeyPath<PromoTrialRecord, Bool>,
		mark: (inout PromoTrialRecord) -> Void
	) -> Date? {
		var current = record
		// Idempotent: a consumed grant never grants again. Return the standing expiry untouched (already durable).
		if current[keyPath: flag] {
			return current.expiresAt ?? now
		}
		let newExpiry = Self.nextExpiry(currentExpiry: current.expiresAt, now: now, addDays: addDays)
		mark(&current)
		current.expiresAt = newExpiry
		// Only report success if the durable write landed — a failed write must NOT burn the one-shot
		// token or publish a grant (review finding #3). The in-memory record change is local and discarded.
		do {
			try persist(current)
		} catch {
			return nil
		}
		return newExpiry
	}

	private func persist(_ record: PromoTrialRecord) throws {
		let data = try JSONEncoder().encode(record)
		try backing.set(data, forKey: Self.recordKey)
	}
}

// MARK: - Production Keychain backing

/// The shared Keychain access group **name** (without the team prefix) that both the host app and the
/// keyboard extension declare in their `keychain-access-groups` entitlement. The two targets' *default*
/// groups differ (`…keymoji` vs `…keymoji.keyboard`), so an explicit shared group is required for
/// cross-process reads of "already consumed".
///
/// The team prefix is **not** hardcoded: the entitlement uses `$(AppIdentifierPrefix)` (codesign
/// team-prefixes it at sign time), and at runtime `KeychainPromoBacking` reads the prefix back from the
/// Keychain. So no team ID lives in source.
public let promoKeychainGroupName = "com.freedommartin.keymoji.shared"

/// `KeychainAccess`-backed conformer used in production. Lives behind `PromoTrialKeychainBacking` so
/// the store's grant logic stays testable without entitlements. `@unchecked Sendable`: the only stored
/// property is a `Keychain`, whose underlying Security framework calls are thread-safe.
public struct KeychainPromoBacking: PromoTrialKeychainBacking, @unchecked Sendable {

	private let keychain: Keychain

	/// - Parameter accessGroup: Override the shared group (tests). `nil` resolves the team-prefixed shared
	///   group at runtime; if that fails (e.g. simulator quirk) we fall back to the default access group —
	///   which *is* the shared group, since it's the app's only `keychain-access-groups` entry.
	public init(service: String = "com.freedommartin.keymoji.promo", accessGroup: String? = nil) {
		if let group = accessGroup ?? Self.sharedAccessGroup {
			self.keychain = Keychain(service: service, accessGroup: group)
		} else {
			self.keychain = Keychain(service: service)
		}
	}

	public func data(forKey key: String) -> Data? {
		try? keychain.getData(key)
	}

	public func set(_ data: Data, forKey key: String) throws {
		try keychain.set(data, key: key)
	}

	public func removeAll() {
		try? keychain.removeAll()
	}

	// MARK: - Runtime team-prefix resolution (no hardcoded team ID)

	/// Fully-qualified shared access group `<TeamPrefix>.<promoKeychainGroupName>`, resolved once.
	static let sharedAccessGroup: String? = {
		guard let prefix = teamPrefix() else { return nil }
		return "\(prefix).\(promoKeychainGroupName)"
	}()

	/// Reads this app's Keychain access-group prefix (the team / app-ID prefix) by probing a throwaway
	/// item and inspecting its resolved `kSecAttrAccessGroup`, instead of hardcoding the team ID. The
	/// probe item is added without an explicit group, so it lands in the app's default group; the prefix
	/// is the first dot-separated component (team IDs contain no dots).
	private static func teamPrefix() -> String? {
		let base: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrAccount as String: "keymoji.accessGroupProbe"
		]
		var query = base
		query[kSecReturnAttributes as String] = true
		query[kSecMatchLimit as String] = kSecMatchLimitOne

		var result: AnyObject?
		var status = SecItemCopyMatching(query as CFDictionary, &result)
		if status == errSecItemNotFound {
			var add = base
			add[kSecReturnAttributes as String] = true
			status = SecItemAdd(add as CFDictionary, &result)
		}
		guard status == errSecSuccess,
			  let attributes = result as? [String: Any],
			  let accessGroup = attributes[kSecAttrAccessGroup as String] as? String
		else { return nil }
		return accessGroup.components(separatedBy: ".").first
	}
}

public extension PromoTrialStore {
	/// Production store backed by the shared-access-group Keychain. Both processes construct their own;
	/// they read/write the same Keychain item.
	static func makeShared() -> PromoTrialStore {
		PromoTrialStore(backing: KeychainPromoBacking())
	}
}
