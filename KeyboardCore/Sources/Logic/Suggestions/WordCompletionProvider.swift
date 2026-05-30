import Foundation

/// Wrapper over `UITextChecker.completions(forPartialWord:in:language:)`. Implemented in the
/// extension target (`KeyboardCore` stays UIKit-free); mocked in tests.
public protocol TextChecking: Sendable {
	/// Ordered completion candidates for `partialWord` in `language` (best first), or `[]`.
	func completions(forPartialWord partialWord: String, language: String) -> [String]
}

/// Wrapper over `UILexicon` (Apple's supplementary lexicon: text-replacement shortcuts, contact
/// names, etc.). Implemented in the extension target; mocked in tests.
public protocol SystemLexiconProviding: Sendable {
	/// Lexicon expansions whose trigger or expansion starts with `prefix` (case-insensitive).
	func entries(matchingPrefix prefix: String) -> [String]
}

/// Prefix-match word completion from three sources, merged by weighted score:
/// 1. personal recents — the strongest signal (frequency-weighted),
/// 2. `UITextChecker` system completions — ordinal-weighted (best candidate highest), and
/// 3. `UILexicon` supplementary entries — a flat low weight.
///
/// No fuzzy/spell correction (`UITextChecker.guesses` is deliberately never used) and no next-word
/// prediction — empty prefix returns nothing. A future `NextWordPredictionProvider` slots in beside
/// this without restructuring (the coordinator is source-agnostic).
public struct WordCompletionProvider: SuggestionProviding {
	private let textChecker: any TextChecking
	private let systemLexicon: any SystemLexiconProviding
	private let recents: any PersonalRecentsReading

	public init(
		textChecker: any TextChecking,
		systemLexicon: any SystemLexiconProviding,
		recents: any PersonalRecentsReading
	) {
		self.textChecker = textChecker
		self.systemLexicon = systemLexicon
		self.recents = recents
	}

	public func suggestions(for context: SuggestionContext) -> [Suggestion] {
		guard case .letters = context.page else { return [] }
		guard let prefix = WordPrefixExtractor.activeWordPrefix(
			before: context.documentContextBeforeInput,
			after: context.documentContextAfterInput
		) else { return [] }
		guard !prefix.isEmpty else { return [] }
		// Stay out of the way while the user is composing a Slack shortcode (`:xxx`). The tokenizer
		// strips the leading `:`, so we detect the shortcode context directly — with `minLength: 1`
		// so even `:s` (below Slack's own typeahead threshold) or `:zz` (no Slack match) suppress
		// word completions instead of offering "s"/"zz".
		if SlackEmojiSuggester.activeShortcodePrefix(
			in: context.documentContextBeforeInput ?? "",
			minLength: 1
		) != nil {
			return []
		}

		let language = context.primaryLanguage ?? "en"

		// Case-insensitive merge keyed on the lowercased word. The first writer's casing becomes
		// the base (recents run first, so a learned proper-noun casing survives); later sources
		// only raise the score. Display casing is reapplied per-prefix at build time.
		var merged: [String: (score: Double, base: String)] = [:]
		func consider(_ word: String, score: Double) {
			guard !word.isEmpty else { return }
			let key = word.lowercased()
			if let existing = merged[key] {
				if score > existing.score { merged[key] = (score, existing.base) }
			} else {
				merged[key] = (score, word)
			}
		}

		// (a) Personal recents: 0.55 + 0.05 · min(count, 10), clamped into [0, 1].
		for match in recents.matches(prefix: prefix) {
			let score = min(0.55 + 0.05 * Double(min(match.count, 10)), 1.0)
			consider(match.word, score: score)
		}

		// (b) UITextChecker completions: linear 0.9 (best) → 0.4 (worst) by ordinal position.
		let checkerHits = textChecker.completions(forPartialWord: prefix, language: language)
		for (index, word) in checkerHits.enumerated() {
			let score = 0.9 - 0.5 * Double(index) / Double(max(checkerHits.count - 1, 1))
			consider(word, score: score)
		}

		// (c) UILexicon supplementary entries: flat 0.3.
		for word in systemLexicon.entries(matchingPrefix: prefix) {
			consider(word, score: 0.3)
		}

		// Drop self-matches: the user has already typed the whole word, nothing to complete.
		merged[prefix.lowercased()] = nil

		return merged
			.map { _, value -> Suggestion in
				let display = Self.displayCapitalization(for: value.base, prefix: prefix, context: context)
				return Suggestion(
					id: "word:\(display)",
					displayText: display,
					replacementText: display,
					renderStyle: .plain,
					score: value.score,
					source: .wordCompletion
				)
			}
			.sorted { lhs, rhs in
				if lhs.score != rhs.score { return lhs.score > rhs.score }
				return lhs.displayText < rhs.displayText
			}
	}

	/// Smart capitalization (CAP3): the chip mirrors the casing the user is typing so a tap inserts
	/// WYSIWYG. All-caps prefix (or caps lock) → uppercase; capitalized prefix (or one-shot
	/// shift) → leading capital; otherwise the candidate's own base casing.
	static func displayCapitalization(for candidate: String, prefix: String, context: SuggestionContext) -> String {
		let shift: ShiftState? = {
			if case .letters(let state) = context.page { return state }
			return nil
		}()

		let prefixIsAllCaps = prefix.count >= 2
			&& prefix.contains(where: { $0.isLetter })
			&& prefix == prefix.uppercased() && prefix != prefix.lowercased()
		if shift == .capsLock || prefixIsAllCaps {
			return candidate.uppercased()
		}

		let prefixIsCapitalized = prefix.first?.isUppercase == true
		if shift == .upper || prefixIsCapitalized {
			return candidate.capitalizedFirstLetter()
		}

		return candidate
	}
}

private extension String {
	/// Uppercases only the first character, leaving the remainder untouched (so "iPhone"-style
	/// internal capitals in a learned word survive). Distinct from `.capitalized`, which lowercases
	/// the tail.
	func capitalizedFirstLetter() -> String {
		guard let first else { return self }
		return first.uppercased() + dropFirst()
	}
}
