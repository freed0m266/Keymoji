import Foundation

/// A horizontal row of keys. `id` is stable per row position (number row, letters row 1/2/3, bottom row)
/// to give SwiftUI ForEach a consistent identity across page/shift transitions.
public struct KeyboardRow: Identifiable, Sendable, Equatable {
	public let id: String
	public let keys: [Key]

	public init(id: String, keys: [Key]) {
		self.id = id
		self.keys = keys
	}
}
