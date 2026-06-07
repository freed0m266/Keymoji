import Foundation

/// Ordering of the favorites bar in the keyboard. Persisted as a string in `AppGroupStore`
/// under `favoritesSortMode`; unknown raw values fall back to the default (`.manual`).
public enum FavoritesSortMode: String, Sendable, CaseIterable {
	/// User's hand-curated drag order (default — preserves today's behavior).
	case manual
	/// Most-used emoji first, by lifetime insertion count, descending.
	case frequency
}
