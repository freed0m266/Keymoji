import Foundation
import KeyboCore

/// Mutable runtime state of the keyboard held by `KeyboardViewController`.
/// `InputDispatcher` mutates this in-place; the view rebuilds layout from these values.
public struct KeyboardState: Sendable, Equatable {
	public var page: KeyboardPage
	public var returnKeyType: ReturnKeyType
	public var showNumberRow: Bool

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

	/// Maximum number of emojis tracked in `recentEmojis`. Keeps the recents tab to two short
	/// rows on iPhone portrait — long enough to be useful, short enough that it never scrolls.
	public static let recentEmojisCapacity = 30

	public init(
		page: KeyboardPage = .letters(.lower),
		returnKeyType: ReturnKeyType = .default,
		showNumberRow: Bool = true,
		spaceDoubleTapAction: SpaceDoubleTapAction = .insertPeriod,
		lastInsertWasSpace: Bool = false,
		lastSpaceInsertedAt: Date? = nil,
		lastShiftTapAt: Date? = nil,
		autoCapitalized: Bool = false,
		keyboardWidth: CGFloat = 0,
		recentEmojis: [String] = [],
		favoriteEmojis: [String] = []
	) {
		self.page = page
		self.returnKeyType = returnKeyType
		self.showNumberRow = showNumberRow
		self.spaceDoubleTapAction = spaceDoubleTapAction
		self.lastInsertWasSpace = lastInsertWasSpace
		self.lastSpaceInsertedAt = lastSpaceInsertedAt
		self.lastShiftTapAt = lastShiftTapAt
		self.autoCapitalized = autoCapitalized
		self.keyboardWidth = keyboardWidth
		self.recentEmojis = recentEmojis
		self.favoriteEmojis = favoriteEmojis
	}
}
