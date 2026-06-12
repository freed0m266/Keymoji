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
}
