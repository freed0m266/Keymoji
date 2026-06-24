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
	/// Minimum learned `count` before a personal-recents word is *offered* (task 74, Fáze A). Learning
	/// still stores from the first sighting (`count == 1`); this is a hard cut on *display* only, so a
	/// one-off typo — or a one-shot sensitive number (OTP, code), almost always a singleton — is never
	/// surfaced, while a word/number/nick typed repeatedly is. Tunable: raise to suggest more
	/// conservatively. Applies only to the personal pool — `UITextChecker`/`UILexicon` are dictionary
	/// sources, not typo-prone, so the threshold never touches them.
	public static let minSuggestCount = 2

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
		// Word completion runs on the typing pages — letters *and* symbols (task 74, Fáze B): with a
		// number row the digits sit on `.letters`, but users without one type numbers/nicks on
		// `.symbols`, and the controller already treats both as suggestion-active. The emoji panels and
		// the locked numpad never complete words.
		switch context.page {
		case .letters, .symbols:
			break
		case .emojis, .emojiSearch, .emojiSearchSymbols, .numeric:
			return []
		}
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

		// Case-insensitive merge keyed on the lowercased word. The first writer's casing becomes
		// the base (recents run first), but recents are now stored lowercase, so the base is
		// effectively lowercase for learned words; later sources only raise the score. Display
		// casing is reapplied per-prefix at build time, mirroring what the user is typing.
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

		// (a) Personal recents: 0.55 + 0.05 · min(count, 10), clamped into [0, 1]. The `minSuggestCount`
		// gate (task 74, Fáze A) drops singletons here — they're learned but not yet trusted enough to
		// offer. The threshold is uniform across every field and token kind (task 77 removed the prior
		// email-address exemption), so addresses clear the same bar as prose. The merge below still
		// surfaces a sub-threshold word if a dictionary source vouches for it (real words aren't typos),
		// so the cut only ever removes pool-exclusive one-offs.
		for match in recents.matches(prefix: prefix) {
			guard match.count >= Self.minSuggestCount else { continue }
			let score = min(0.55 + 0.05 * Double(min(match.count, 10)), 1.0)
			consider(match.word, score: score)
		}

		// (b) UITextChecker completions — queried once per language and merged. The controller supplies
		// a single language today (the accent set's completion language; task 78), but the loop still
		// merges a multi-language list. Linear 0.9 (best) → 0.4 (worst) by ordinal position, scored
		// within each language; the case-insensitive dedupe in `consider` keeps the max when a word
		// surfaces in more than one dictionary, so neither language is privileged.
		for language in context.completionLanguages {
			let checkerHits = textChecker.completions(forPartialWord: prefix, language: language)
			for (index, word) in checkerHits.enumerated() {
				let score = 0.9 - 0.5 * Double(index) / Double(max(checkerHits.count - 1, 1))
				consider(word, score: score)
			}
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
