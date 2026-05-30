import Foundation
@testable import KeyboardCore

// MARK: - Provider mocks

/// Returns a fixed completion list, optionally keyed by the queried partial word.
struct MockTextChecker: TextChecking {
	var byPrefix: [String: [String]] = [:]
	var fallback: [String] = []

	func completions(forPartialWord partialWord: String, language: String) -> [String] {
		byPrefix[partialWord] ?? fallback
	}
}

/// Prefix-filters a fixed word list (case-insensitive), mirroring the real `UILexicon` adapter.
struct MockSystemLexicon: SystemLexiconProviding {
	var words: [String] = []

	func entries(matchingPrefix prefix: String) -> [String] {
		words.filter { $0.lowercased().hasPrefix(prefix.lowercased()) }
	}
}

/// Prefix-filters a fixed `(word, count)` list, mirroring `PersonalRecentsStore.matches`.
struct MockRecents: PersonalRecentsReading {
	var entries: [(word: String, count: Int)] = []

	func matches(prefix: String) -> [(word: String, count: Int)] {
		entries.filter { $0.word.lowercased().hasPrefix(prefix.lowercased()) }
	}
}

/// Returns a fixed suggestion list regardless of context — for coordinator tests.
struct StubProvider: SuggestionProviding {
	var result: [Suggestion]

	func suggestions(for context: SuggestionContext) -> [Suggestion] { result }
}

// MARK: - Helpers

extension SuggestionContext {
	/// Convenience builder for tests — sensible eligible-prose defaults.
	static func test(
		before: String?,
		after: String? = nil,
		page: KeyboardPage = .letters(.lower),
		language: String? = "en"
	) -> SuggestionContext {
		SuggestionContext(
			documentContextBeforeInput: before,
			documentContextAfterInput: after,
			page: page,
			primaryLanguage: language,
			eligibility: SuggestionEligibility(allowDisplay: true, learningContext: .prose)
		)
	}
}

extension Suggestion {
	static func word(_ text: String, score: Double) -> Suggestion {
		Suggestion(
			id: "word:\(text)",
			displayText: text,
			replacementText: text,
			renderStyle: .plain,
			score: score,
			source: .wordCompletion
		)
	}

	static func pill(_ shortcode: String, _ emoji: String) -> Suggestion {
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
