import Foundation

/// Suite name used by the App Group `UserDefaults` shared between host app and keyboard extension.
/// Must match the `com.apple.security.application-groups` entitlement on both targets.
public let appGroupSuiteName = "group.com.freedommartin.keybo"

/// Wrapper over `UserDefaults(suiteName:)` for cross-process preferences. Soft-fails to standard
/// defaults in RELEASE if the App Group suite can't be opened (entitlements misconfig); crashes in
/// DEBUG so the dev sees the misconfig immediately.
///
/// `@unchecked Sendable`: the only stored property is `UserDefaults`, which Apple documents as
/// thread-safe for concurrent reads/writes despite not formally adopting `Sendable`.
public final class AppGroupStore: @unchecked Sendable {

	public static let shared = AppGroupStore()

	private let suite: UserDefaults

	public init(suiteName: String = appGroupSuiteName) {
		guard let suite = UserDefaults(suiteName: suiteName) else {
			#if DEBUG
			fatalError("Failed to open UserDefaults(suiteName: \(suiteName)). Check App Group entitlements.")
			#else
			self.suite = .standard
			return
			#endif
		}
		self.suite = suite
	}

	// MARK: - Bool

	public func bool(forKey key: AppGroupStoreKey, default defaultValue: Bool) -> Bool {
		// `UserDefaults.bool(forKey:)` returns `false` for missing keys — indistinguishable from a stored `false`.
		// Probe `object(forKey:)` first to tell "unset" from "set to false" and return the right default.
		guard suite.object(forKey: key.rawValue) != nil else { return defaultValue }
		return suite.bool(forKey: key.rawValue)
	}

	public func setBool(_ value: Bool, forKey key: AppGroupStoreKey) {
		suite.set(value, forKey: key.rawValue)
	}

	// MARK: - String

	public func string(forKey key: AppGroupStoreKey) -> String? {
		suite.string(forKey: key.rawValue)
	}

	public func setString(_ value: String?, forKey key: AppGroupStoreKey) {
		suite.set(value, forKey: key.rawValue)
	}

	// MARK: - Debug reset

	/// Removes all Keybo-managed keys from the suite. Used by tests and developer reset flows.
	public func reset() {
		for key in AppGroupStoreKey.allCases {
			suite.removeObject(forKey: key.rawValue)
		}
	}
}

// MARK: - Typed accessors

public extension AppGroupStore {
	var showNumberRow: Bool {
		get { bool(forKey: .showNumberRow, default: true) }
		set { setBool(newValue, forKey: .showNumberRow) }
	}

	var hapticFeedbackEnabled: Bool {
		get { bool(forKey: .hapticFeedbackEnabled, default: true) }
		set { setBool(newValue, forKey: .hapticFeedbackEnabled) }
	}

	var onboardingComplete: Bool {
		get { bool(forKey: .onboardingComplete, default: false) }
		set { setBool(newValue, forKey: .onboardingComplete) }
	}
}
