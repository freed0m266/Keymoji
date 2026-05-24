import Foundation

/// Mutable runtime state of the keyboard held by `KeyboardViewController`.
/// `InputDispatcher` mutates this in-place; the view rebuilds layout from these values.
public struct KeyboardState: Sendable, Equatable {
	public var page: KeyboardPage
	public var returnKeyType: ReturnKeyType
	public var showNumberRow: Bool

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

	public init(
		page: KeyboardPage = .letters(.lower),
		returnKeyType: ReturnKeyType = .default,
		showNumberRow: Bool = true,
		lastInsertWasSpace: Bool = false,
		lastSpaceInsertedAt: Date? = nil,
		lastShiftTapAt: Date? = nil,
		autoCapitalized: Bool = false,
		keyboardWidth: CGFloat = 0
	) {
		self.page = page
		self.returnKeyType = returnKeyType
		self.showNumberRow = showNumberRow
		self.lastInsertWasSpace = lastInsertWasSpace
		self.lastSpaceInsertedAt = lastSpaceInsertedAt
		self.lastShiftTapAt = lastShiftTapAt
		self.autoCapitalized = autoCapitalized
		self.keyboardWidth = keyboardWidth
	}
}
