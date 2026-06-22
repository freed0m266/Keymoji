import Foundation

/// Typed keys for the App Group `UserDefaults` suite shared between the host app and the keyboard extension.
/// String raw value is what's actually stored — changing a case's `rawValue` is a migration.
public enum AppGroupStoreKey: String, Sendable, CaseIterable {
	case showNumberRow
	case hapticFeedbackEnabled
	case keyClickSoundEnabled
	case onboardingComplete
	case appearance
	case spaceDoubleTapAction
	case letterLayout
	/// Active long-press diacritic set (`LetterAlternateSet` raw value). When unset, the typed
	/// accessor derives a default from the device locale instead of returning a fixed value.
	case letterAlternateSet
	case recentEmojis
	case favoriteEmojis
	/// Favorites bar ordering (`FavoritesSortMode` raw value). Defaults to `.manual`.
	case favoritesSortMode
	/// JSON `{ "emoji": count }` of lifetime emoji insertion counts, driving `.frequency` ordering.
	case emojiUsageCounts
	case suggestionsEnabled
	/// JSON `{ "word": count }` of the personal word-completion recents pool.
	case wordCompletionRecents
	/// JSON `{ "word": unixTimestamp }` mirroring `wordCompletionRecents`, used for LRU eviction.
	case wordCompletionRecentsLastUsed
	/// Keymoji Plus entitlement mirror (`Bool`). Written by the host app's `PurchaseService` after a
	/// purchase/restore/entitlement refresh; read (never written) by the keyboard extension, which has
	/// no StoreKit code. Its dedicated Darwin channel live-unlocks a running keyboard right after a buy.
	case isPlus
	/// *Plus trial expiry* mirror (`Date?` as an epoch-seconds string). Cheap hot-path copy of the
	/// Keychain-owned expiry set by the Welcome trial. Written by the host app (Welcome activation) and
	/// read (never written) by the keyboard extension; its Darwin channel live-unlocks a running keyboard
	/// the instant a grant lands. See `effectiveIsPlus`.
	case promoPlusExpiresAt
	/// **Darwin channel only — no stored value.** Posted by the host app after it edits the learned-words
	/// pool (`PersonalRecentsStore.remove` / `clear`) so the running keyboard reloads its in-memory index
	/// from disk (task 73). The pool lives in a file in the App Group container, not UserDefaults, so this
	/// key never backs a `UserDefaults` entry — it only names a notification.
	case learnedWordsChanged
}
