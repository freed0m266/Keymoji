import Foundation

/// Adapts the existing `SlackEmojiSuggester` to the `SuggestionProviding` protocol so the Slack
/// shortcode typeahead and word completion share one bar and one coordinator.
///
/// Produces `.pill` chips whose `displayText` is the shortcode and whose `replacementText` is the
/// emoji glyph (the pill renders both). `score` is a flat `1.0`: the coordinator's priority rule
/// returns Slack chips wholesale whenever this provider is non-empty, so the score never actually
/// competes — it's set high only for clarity.
public struct SlackSuggestionProvider: SuggestionProviding {
	private let table: [String: String]
	private let limit: Int

	public init(
		table: [String: String] = SlackEmojiTable.defaultTable,
		limit: Int = SlackEmojiSuggester.defaultLimit
	) {
		self.table = table
		self.limit = limit
	}

	public func suggestions(for context: SuggestionContext) -> [Suggestion] {
		guard case .letters = context.page else { return [] }
		return SlackEmojiSuggester
			.suggestions(forContext: context.documentContextBeforeInput, table: table, limit: limit)
			.map { suggestion in
				Suggestion(
					id: "slack:\(suggestion.shortcode)",
					displayText: suggestion.shortcode,
					replacementText: suggestion.emoji,
					renderStyle: .pill,
					score: 1.0,
					source: .slack
				)
			}
	}
}
