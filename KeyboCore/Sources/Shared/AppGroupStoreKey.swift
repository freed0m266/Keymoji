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
	case recentEmojis
	case favoriteEmojis
}
