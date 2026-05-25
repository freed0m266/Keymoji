import Foundation

/// A horizontal row of keys. `id` is stable per row position (number row, letters row 1/2/3, bottom row)
/// to give SwiftUI ForEach a consistent identity across page/shift transitions.
///
/// `referenceWeight` lets a row (typically the ASDF letter row with 9 keys) render keys at the same
/// per-key width as a 10-weight row by symmetrically inset-padding both sides. `nil` keeps the
/// default "fill the entire row width" behavior.
public struct KeyboardRow: Identifiable, Sendable, Equatable {
	public let id: String
	public let keys: [Key]
	public let referenceWeight: Double?

	public var isNumberRow: Bool {
		id == "numberRow"
	}

	public init(id: String, keys: [Key], referenceWeight: Double? = nil) {
		self.id = id
		self.keys = keys
		self.referenceWeight = referenceWeight
	}
}
