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

	// MARK: - String array

	public func stringArray(forKey key: AppGroupStoreKey) -> [String] {
		suite.stringArray(forKey: key.rawValue) ?? []
	}

	public func setStringArray(_ value: [String], forKey key: AppGroupStoreKey) {
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

	/// Keyboard click sound toggle. Defaults to `false` — Apple's stock setting in
	/// Settings → Sounds & Haptics also ships off; matching that avoids surprising users.
	var keyClickSoundEnabled: Bool {
		get { bool(forKey: .keyClickSoundEnabled, default: false) }
		set { setBool(newValue, forKey: .keyClickSoundEnabled) }
	}

	var onboardingComplete: Bool {
		get { bool(forKey: .onboardingComplete, default: false) }
		set { setBool(newValue, forKey: .onboardingComplete) }
	}

	var appearance: AppearancePreference {
		get {
			guard let raw = string(forKey: .appearance) else { return .system }
			return AppearancePreference(rawValue: raw) ?? .system
		}
		set { setString(newValue.rawValue, forKey: .appearance) }
	}

	/// What happens on a double-tap of the space key. Defaults to `.insertPeriod`
	/// (Apple-stock ". " substitution). Unknown raw values fall back to the default —
	/// defensive against corrupted defaults or future renames.
	var spaceDoubleTapAction: SpaceDoubleTapAction {
		get {
			guard let raw = string(forKey: .spaceDoubleTapAction) else { return .insertPeriod }
			return SpaceDoubleTapAction(rawValue: raw) ?? .insertPeriod
		}
		set { setString(newValue.rawValue, forKey: .spaceDoubleTapAction) }
	}

	/// Positional layout of the alphabetic keys. Defaults to `.qwerty`. Unknown raw values
	/// fall back to the default — defensive against corrupted defaults or future renames.
	var letterLayout: LetterLayout {
		get {
			guard let raw = string(forKey: .letterLayout) else { return .qwerty }
			return LetterLayout(rawValue: raw) ?? .qwerty
		}
		set { setString(newValue.rawValue, forKey: .letterLayout) }
	}

	/// Most-recently-used emojis, newest first. Updated by the keyboard extension after each
	/// emoji insertion; read by the extension on `viewWillAppear` to seed the recents tab.
	var recentEmojis: [String] {
		get { stringArray(forKey: .recentEmojis) }
		set { setStringArray(newValue, forKey: .recentEmojis) }
	}

	/// User-curated favorite emojis, ordered by preference (first = leftmost in the panel).
	/// Edited from the host app's Settings screen and toggled by long-press on the emoji panel;
	/// read by the keyboard extension on `viewWillAppear` to drive the "Favorites" tab.
	var favoriteEmojis: [String] {
		get { stringArray(forKey: .favoriteEmojis) }
		set { setStringArray(newValue, forKey: .favoriteEmojis) }
	}

	/// Master toggle for the word-suggestion bar. Defaults to `true` (DEF-ON) — word completion is
	/// the headline feature; users who don't want it turn it off in Settings → Suggestions.
	var suggestionsEnabled: Bool {
		get { bool(forKey: .suggestionsEnabled, default: true) }
		set { setBool(newValue, forKey: .suggestionsEnabled) }
	}

	/// JSON `{ "word": count }` of the personal word-completion recents pool. Read/decoded on
	/// demand and re-encoded per learned word by `PersonalRecentsStore`.
	var wordCompletionRecentsJSON: String? {
		get { string(forKey: .wordCompletionRecents) }
		set { setString(newValue, forKey: .wordCompletionRecents) }
	}

	/// JSON `{ "word": unixTimestamp }` mirroring `wordCompletionRecentsJSON`. Lets LRU eviction
	/// break ties on least-recently-used so a stale-but-frequent word doesn't evict a fresh one.
	var wordCompletionRecentsLastUsedJSON: String? {
		get { string(forKey: .wordCompletionRecentsLastUsed) }
		set { setString(newValue, forKey: .wordCompletionRecentsLastUsed) }
	}
}
