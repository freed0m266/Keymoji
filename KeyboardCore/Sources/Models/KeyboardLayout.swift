import Foundation

/// A fully-resolved keyboard snapshot ready to render. Produced by `LayoutBuilder` as a pure function of inputs.
public struct KeyboardLayout: Sendable, Equatable {
	public let page: KeyboardPage
	public let rows: [KeyboardRow]
	public let showsNumberRow: Bool
	public let returnKeyType: ReturnKeyType

	public init(
		page: KeyboardPage,
		rows: [KeyboardRow],
		showsNumberRow: Bool,
		returnKeyType: ReturnKeyType
	) {
		self.page = page
		self.rows = rows
		self.showsNumberRow = showsNumberRow
		self.returnKeyType = returnKeyType
	}
}
