import Foundation

/// Merges the output of registered providers into the single ranked list the bar renders.
///
/// Priority rule: if any provider returns Slack chips, those win wholesale (in provider order,
/// already capped by the Slack suggester) — a user mid-`:shortcode:` wants emoji, not words. With
/// no Slack chips, the remaining suggestions are deduped case-insensitively (best score kept),
/// sorted by score then text, and capped at `limit`. Fewer than `limit` candidates → fewer chips
/// (F2: empty slots are simply absent, never padded).
public struct SuggestionCoordinator: Sendable {
	private let providers: [any SuggestionProviding]
	private let limit: Int

	public init(providers: [any SuggestionProviding], limit: Int = 3) {
		self.providers = providers
		self.limit = limit
	}

	public func suggestions(for context: SuggestionContext) -> [Suggestion] {
		let all = providers.flatMap { $0.suggestions(for: context) }

		let slack = all.filter { $0.source == .slack }
		if !slack.isEmpty {
			return slack
		}

		// Dedupe case-insensitively, keeping the highest-scoring representative per word.
		var best: [String: Suggestion] = [:]
		for suggestion in all where suggestion.source != .slack {
			let key = suggestion.displayText.lowercased()
			if let existing = best[key], existing.score >= suggestion.score { continue }
			best[key] = suggestion
		}

		return best.values
			.sorted { lhs, rhs in
				if lhs.score != rhs.score { return lhs.score > rhs.score }
				return lhs.displayText < rhs.displayText
			}
			.prefix(limit)
			.map { $0 }
	}
}
