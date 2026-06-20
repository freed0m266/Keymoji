import Foundation
import KeymojiCore

/// Mutable runtime state of the keyboard held by `KeyboardViewController`.
/// `InputDispatcher` mutates this in-place; the view rebuilds layout from these values.
public struct KeyboardState: Sendable, Equatable {
	public var page: KeyboardPage
	public var returnKeyType: ReturnKeyType
	public var showNumberRow: Bool

	/// Whether the keyboard is currently in landscape (iPhone compact height). Tracked by
	/// `KeyboardViewController` from `traitCollection.verticalSizeClass`. Only affects whether the
	/// number row is shown (see `effectiveShowsNumberRow`); the stored `showNumberRow` preference is
	/// left untouched, so portrait restores the user's choice exactly.
	public var isLandscape: Bool

	/// The number row never appears in landscape — vertical space is too scarce, matching the native
	/// iOS keyboard (digits stay reachable via the `123` page). This is the value **every** consumer
	/// reads (the layout builder and both height calculations) so the host constraint and the SwiftUI
	/// content height can never drift apart. The user's `showNumberRow` preference still governs
	/// portrait unchanged.
	public var effectiveShowsNumberRow: Bool { showNumberRow && !isLandscape }

	/// User preference for the QWERTY/QWERTZ position of the Y and Z keys. Runtime copy of
	/// `AppGroupStore.letterLayout`, refreshed by `KeyboardViewController.viewWillAppear`.
	public var letterLayout: LetterLayout

	/// Active long-press diacritic set. Runtime copy of `AppGroupStore.letterAlternateSet`, refreshed
	/// by `KeyboardViewController.viewWillAppear` and the `.letterAlternateSet` Darwin notification.
	public var letterAlternateSet: LetterAlternateSet

	/// User preference for what a double-tap on space does. Runtime copy of
	/// `AppGroupStore.spaceDoubleTapAction`, refreshed by `KeyboardViewController.viewWillAppear`.
	public var spaceDoubleTapAction: SpaceDoubleTapAction

	/// Whether the most recently inserted character was a space. Drives the
	/// double-tap-space → ". " substitution.
	public var lastInsertWasSpace: Bool

	/// When the last space was inserted via `.space` action. `nil` after a non-space
	/// insertion or after a period-substitution (to prevent triple-tap chaining).
	public var lastSpaceInsertedAt: Date?

	/// When shift was last tapped. Used by `ShiftStateMachine` to detect double-tap → caps lock.
	public var lastShiftTapAt: Date?

	/// True when the current `letters(.upper)` page was driven by auto-cap detection (not a manual shift tap).
	/// Lets us cleanly revert the auto-promotion if the context changes (e.g., user deletes the period).
	public var autoCapitalized: Bool

	/// Width of the visible keyboard area in points. The hosting controller updates this from
	/// `view.bounds.width` in `viewDidLayoutSubviews`, which is the only authoritative source —
	/// `GeometryReader` inside the keyboard view turned out to under-report on some hosts.
	public var keyboardWidth: CGFloat

	/// Most-recently-used emojis (newest first). Drives the "Recently used" category in the
	/// emoji panel. Populated on viewWillAppear from `AppGroupStore` and updated after each
	/// emoji insertion. Capped at `KeyboardState.recentEmojisCapacity` by the dispatcher.
	public var recentEmojis: [String]

	/// User-curated favorites, ordered by preference. Drives the "Favorites" category in the
	/// emoji panel (pinned to the left when non-empty). Populated on `viewWillAppear` from
	/// `AppGroupStore` and updated when the user long-presses an emoji to toggle membership.
	public var favoriteEmojis: [String]

	/// How the favorites bar is ordered. Runtime mirror of `AppGroupStore.favoritesSortMode`,
	/// refreshed on `viewWillAppear` and on the `.favoritesSortMode` Darwin notification.
	public var favoritesSortMode: FavoritesSortMode

	/// Lifetime per-emoji insertion counts `{ emoji: count }`. Runtime mirror of
	/// `AppGroupStore.emojiUsageCounts`, bumped live on each emoji insertion to drive
	/// `.frequency` favorites ordering.
	public var emojiUsageCounts: [String: Int]

	/// Keymoji Plus **paid** entitlement. Runtime mirror of `AppGroupStore.isPlus`, refreshed on
	/// `viewWillAppear` and the `.isPlus` Darwin notification (live unlock after a purchase). Stays
	/// paid-only — never overwritten by promo. Gating reads `effectiveIsPlus`, not this.
	public var isPlus: Bool

	/// *Plus trial expiry* runtime mirror of `AppGroupStore.promoPlusExpiresAt`, refreshed on
	/// `viewWillAppear` and the `.promoPlusExpiresAt` Darwin notification (live unlock the instant a
	/// Welcome grant lands). `nil` when no promo grant is active.
	public var promoPlusExpiresAt: Date?

	/// *Effective* Plus — the single gating call for the keyboard: paid (`isPlus`) **or** an active
	/// promo trial (`promoPlusExpiresAt` in the future). Drives the favorites clamp and the long-press
	/// favorite-add gate so a promo unlocks the bar exactly like a paid purchase.
	public var effectiveIsPlus: Bool {
		KeymojiCore.effectiveIsPlus(paid: isPlus, promoExpiresAt: promoPlusExpiresAt, now: Date())
	}

	/// Maximum number of emojis tracked in `recentEmojis`. Keeps the recents tab to two short
	/// rows on iPhone portrait — long enough to be useful, short enough that it never scrolls.
	public static let recentEmojisCapacity = 30

	/// Current emoji-search query buffer. Populated by `InputDispatcher` while
	/// `page == .emojiSearch` and cleared on exit (`×` tap). Transient — not persisted to
	/// `AppGroupStore`, so the query never survives an extension restart.
	public var searchQuery: String

	/// Master toggle for the word-suggestion bar. Runtime mirror of `AppGroupStore.suggestionsEnabled`,
	/// refreshed on `viewWillAppear` and on the `.suggestionsEnabled` Darwin notification.
	public var suggestionsEnabled: Bool

	/// Eligibility of the focused field — whether the bar may show and how (if at all) typing
	/// feeds the personal recents pool. Re-evaluated by `KeyboardViewController.textDidChange`.
	public var currentEligibility: SuggestionEligibility

	/// Primary language of the focused field (`UITextInputMode.primaryLanguage`, e.g. "en-US"), or
	/// nil when unavailable. Passed to `UITextChecker`; providers fall back to "en".
	public var currentLanguage: String?

	public init(
		page: KeyboardPage = .letters(.lower),
		returnKeyType: ReturnKeyType = .default,
		showNumberRow: Bool = true,
		isLandscape: Bool = false,
		letterLayout: LetterLayout = .qwerty,
		letterAlternateSet: LetterAlternateSet = .all,
		spaceDoubleTapAction: SpaceDoubleTapAction = .insertPeriod,
		lastInsertWasSpace: Bool = false,
		lastSpaceInsertedAt: Date? = nil,
		lastShiftTapAt: Date? = nil,
		autoCapitalized: Bool = false,
		keyboardWidth: CGFloat = 0,
		recentEmojis: [String] = [],
		favoriteEmojis: [String] = [],
		favoritesSortMode: FavoritesSortMode = .manual,
		emojiUsageCounts: [String: Int] = [:],
		isPlus: Bool = false,
		promoPlusExpiresAt: Date? = nil,
		searchQuery: String = "",
		suggestionsEnabled: Bool = true,
		currentEligibility: SuggestionEligibility = .denied,
		currentLanguage: String? = nil
	) {
		self.page = page
		self.returnKeyType = returnKeyType
		self.showNumberRow = showNumberRow
		self.isLandscape = isLandscape
		self.letterLayout = letterLayout
		self.letterAlternateSet = letterAlternateSet
		self.spaceDoubleTapAction = spaceDoubleTapAction
		self.lastInsertWasSpace = lastInsertWasSpace
		self.lastSpaceInsertedAt = lastSpaceInsertedAt
		self.lastShiftTapAt = lastShiftTapAt
		self.autoCapitalized = autoCapitalized
		self.keyboardWidth = keyboardWidth
		self.recentEmojis = recentEmojis
		self.favoriteEmojis = favoriteEmojis
		self.favoritesSortMode = favoritesSortMode
		self.emojiUsageCounts = emojiUsageCounts
		self.isPlus = isPlus
		self.promoPlusExpiresAt = promoPlusExpiresAt
		self.searchQuery = searchQuery
		self.suggestionsEnabled = suggestionsEnabled
		self.currentEligibility = currentEligibility
		self.currentLanguage = currentLanguage
	}
}
