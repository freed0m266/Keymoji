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

	public init(
		page: KeyboardPage = .letters(.lower),
		returnKeyType: ReturnKeyType = .default,
		showNumberRow: Bool = true,
		lastInsertWasSpace: Bool = false,
		lastSpaceInsertedAt: Date? = nil
	) {
		self.page = page
		self.returnKeyType = returnKeyType
		self.showNumberRow = showNumberRow
		self.lastInsertWasSpace = lastInsertWasSpace
		self.lastSpaceInsertedAt = lastSpaceInsertedAt
	}
}
