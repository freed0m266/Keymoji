import KeyboardCore

/// Builders for `Suggestion` fixtures used across the KeyboardUI snapshot suites.
extension Suggestion {
	static func plainChip(_ text: String, score: Double) -> Suggestion {
		Suggestion(
			id: "word:\(text)",
			displayText: text,
			replacementText: text,
			renderStyle: .plain,
			score: score,
			source: .wordCompletion
		)
	}

	static func pillChip(_ shortcode: String, _ emoji: String) -> Suggestion {
		Suggestion(
			id: "slack:\(shortcode)",
			displayText: shortcode,
			replacementText: emoji,
			renderStyle: .pill,
			score: 1.0,
			source: .slack
		)
	}
}
