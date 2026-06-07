import Foundation

/// Single source of the favorites-bar ordering logic, shared between the keyboard extension
/// and the host app's favorites editor so both render identical order. A pure presentation
/// sort — it never mutates the stored manual order.
public enum FavoritesOrdering {
	/// Returns `favorites` ordered for display. `.manual` → unchanged. `.frequency` → by `counts`
	/// descending; emojis with equal or missing count keep their relative order in `favorites`
	/// (stable tie-break → deterministic, and zero-count favorites stay in manual order on day one).
	public static func ordered(
		_ favorites: [String],
		counts: [String: Int],
		mode: FavoritesSortMode
	) -> [String] {
		guard mode == .frequency else { return favorites }
		return favorites.enumerated().sorted { lhs, rhs in
			let lc = counts[lhs.element] ?? 0
			let rc = counts[rhs.element] ?? 0
			if lc != rc { return lc > rc }
			return lhs.offset < rhs.offset   // stable: preserve manual order on ties
		}.map(\.element)
	}
}
