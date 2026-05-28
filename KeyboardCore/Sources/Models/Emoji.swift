import Foundation

/// One emoji entry surfaced by `EmojiCatalog`. Carries everything search needs to rank a glyph:
/// the canonical CLDR name (for tier-1/2 ranking), keyword annotations (tier-3), and the source
/// category. Slack shortcodes are intentionally not a field — `SlackEmojiTable` stays the single
/// source of truth there, queried alongside the catalog by `EmojiSearchIndex`.
public struct Emoji: Sendable, Equatable, Hashable, Identifiable {
	public let glyph: String
	public let name: String
	public let keywords: [String]
	public let category: EmojiCategory

	public var id: String { glyph }

	public init(glyph: String, name: String, keywords: [String], category: EmojiCategory) {
		self.glyph = glyph
		self.name = name
		self.keywords = keywords
		self.category = category
	}
}
