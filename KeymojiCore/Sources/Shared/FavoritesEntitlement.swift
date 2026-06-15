import Foundation

/// The freemium boundary for the favorites personalization layer. Pure value logic shared by the
/// host app's favorites editor (gating + upsell), onboarding (selection cap), and the keyboard
/// extension (display clamp), so all three agree on exactly what a free user sees and can keep.
///
/// Keeping this StoreKit-free and in `KeymojiCore` lets the keyboard extension reuse it without
/// linking StoreKit — the extension only reads the `AppGroupStore.isPlus` mirror.
public enum FavoritesEntitlement {

	/// How many favorites a free (non-Plus) user may keep — one bar page, hand-ordered. Plus removes
	/// the cap entirely. Named constant so the editor, onboarding, and keyboard clamp can't drift.
	public static let freeFavoritesLimit = 6

	/// Whether a user with the given entitlement may add one more favorite to `current`.
	/// Plus is unbounded; free is capped at `freeFavoritesLimit`.
	public static func canAddFavorite(currentCount: Int, isPlus: Bool) -> Bool {
		isPlus || currentCount < freeFavoritesLimit
	}

	/// Favorites visible to a user with the given entitlement, in final display order.
	///
	/// Free users are clamped to the first `freeFavoritesLimit` stored favorites and **always** see
	/// manual order (frequency auto-sort is Plus-only); Plus users see the full set in their chosen
	/// `mode`. Pure — testable without StoreKit. The clamp never mutates stored `favorites`, so a
	/// Plus → free transition (e.g. entitlement still loading after reinstall) hides extras without
	/// losing them; they reappear on the next refresh.
	public static func visibleFavorites(
		_ favorites: [String],
		counts: [String: Int],
		mode: FavoritesSortMode,
		isPlus: Bool
	) -> [String] {
		let clamped = isPlus ? favorites : Array(favorites.prefix(freeFavoritesLimit))
		let effectiveMode = isPlus ? mode : .manual
		return FavoritesOrdering.ordered(clamped, counts: counts, mode: effectiveMode)
	}
}
