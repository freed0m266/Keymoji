import Foundation

/// Proactively offers the single best previously-typed email address in an email field, *before* the
/// user types anything (task 74, Fáze C).
///
/// The normal prefix-match path (`WordCompletionProvider`) already completes an address once the user
/// starts typing it; this fills the gap at the start of an empty field, where there's no prefix to
/// match on. It's deliberately a *single* chip: three long addresses truncated in one narrow bar
/// (`martin.svo…` ×3) are indistinguishable, so one readable best pick wins.
///
/// Active only when the field's learning context is `.emailAddress` **and** the field is empty — the
/// moment the user types anything, this goes silent and the prefix-match path takes over. Gating on an
/// *empty field* (rather than "no active word prefix") is what keeps the quick-pick from re-triggering
/// *mid-address*: with the whitespace-only tokenizer (task 79) a partial like `user@` or `user@x.` is
/// itself the active prefix, so the prefix-match path already completes it — prepending a whole saved
/// address there would be wrong. Gated by the same `WordCompletionProvider.minSuggestCount` as every other suggestion
/// (task 77 dropped the prior single-use exemption): an address is offered only once it's been typed at
/// least `minSuggestCount` times, so the quick-pick stays consistent with the uniform threshold.
public struct EmailQuickPickProvider: SuggestionProviding {
	private let recents: any PersonalRecentsReading

	public init(recents: any PersonalRecentsReading) {
		self.recents = recents
	}

	public func suggestions(for context: SuggestionContext) -> [Suggestion] {
		guard context.eligibility.learningContext == .emailAddress else { return [] }
		// Empty field only: any content (before *or* after the caret) means an address is being typed or
		// already present, so defer to the prefix-match path and never prepend/append a whole address.
		let before = (context.documentContextBeforeInput ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
		let after = (context.documentContextAfterInput ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
		guard before.isEmpty, after.isEmpty else { return [] }

		// One filtered pass over the pool (only reachable in a focused, prefix-less email field — not
		// per-keystroke): the highest-count `@` token at or above the uniform threshold (task 77), ties
		// broken by most-recent, then word for determinism.
		let best = recents.allLearnedWords()
			.filter { $0.word.contains("@") && $0.count >= WordCompletionProvider.minSuggestCount }
			.max { lhs, rhs in
				if lhs.count != rhs.count {
					return lhs.count < rhs.count
				}
				if lhs.lastUsed != rhs.lastUsed {
					return lhs.lastUsed < rhs.lastUsed
				}
				return lhs.word > rhs.word
			}
		guard let best else { return [] }

		return [Suggestion(
			id: "email:\(best.word)",
			displayText: best.word,
			replacementText: best.word,
			renderStyle: .plain,
			score: 1.0,
			source: .wordCompletion
		)]
	}
}
