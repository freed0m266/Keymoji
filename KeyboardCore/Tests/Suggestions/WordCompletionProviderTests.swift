import XCTest
@testable import KeyboardCore

final class WordCompletionProviderTests: XCTestCase {

	private func makeProvider(
		recents: [(word: String, count: Int)] = [],
		checker: [String] = [],
		lexicon: [String] = []
	) -> WordCompletionProvider {
		WordCompletionProvider(
			textChecker: MockTextChecker(fallback: checker),
			systemLexicon: MockSystemLexicon(words: lexicon),
			recents: MockRecents(entries: recents)
		)
	}

	// MARK: - Source merge & ranking

	func testWeightedMerge_ordersByScore() {
		let provider = makeProvider(
			recents: [("hello", 10)],          // 0.55 + 0.05*10 → clamped 1.0
			checker: ["help", "helicopter"],   // idx0 → 0.9, idx1 → 0.4
			lexicon: ["hey"]                   // flat 0.3
		)
		let result = provider.suggestions(for: .test(before: "he"))
		XCTAssertEqual(result.map(\.displayText), ["hello", "help", "helicopter", "hey"])
		XCTAssertEqual(result.first?.score, 1.0)
		XCTAssertEqual(result.first(where: { $0.displayText == "help" })?.score, 0.9)
		XCTAssertEqual(result.first(where: { $0.displayText == "helicopter" })?.score ?? 0, 0.4, accuracy: 0.0001)
		XCTAssertEqual(result.first(where: { $0.displayText == "hey" })?.score, 0.3)
	}

	func testRecentsScore_clampedToOne() {
		let provider = makeProvider(recents: [("hello", 99)])
		XCTAssertEqual(provider.suggestions(for: .test(before: "he")).first?.score, 1.0)
	}

	func testAllChips_arePlainWordCompletions() {
		let result = makeProvider(checker: ["help"]).suggestions(for: .test(before: "he"))
		XCTAssertEqual(result.first?.renderStyle, .plain)
		XCTAssertEqual(result.first?.source, .wordCompletion)
		XCTAssertEqual(result.first?.replacementText, result.first?.displayText)
	}

	// MARK: - Self-match exclusion

	func testSelfMatch_excluded() {
		let provider = makeProvider(recents: [("hello", 3), ("hellofresh", 1)])
		let result = provider.suggestions(for: .test(before: "hello"))
		XCTAssertEqual(result.map(\.displayText), ["hellofresh"], "the fully-typed word is not offered back")
	}

	// MARK: - Case-insensitive dedupe

	func testDedupe_caseInsensitive_keepsHighestScore() {
		// Recents "Hello" (count 2 → 0.65) and checker "hello" (idx0 → 0.9) collapse to one chip.
		let provider = makeProvider(recents: [("Hello", 2)], checker: ["hello"])
		let result = provider.suggestions(for: .test(before: "he"))
		XCTAssertEqual(result.count, 1)
		XCTAssertEqual(result.first?.displayText, "Hello", "recents' base casing is preserved")
		XCTAssertEqual(result.first?.score, 0.9, "the higher (checker) score wins")
	}

	// MARK: - Gating

	func testSymbolsPage_returnsEmpty() {
		let provider = makeProvider(checker: ["help"])
		XCTAssertTrue(provider.suggestions(for: .test(before: "he", page: .symbols(.primary))).isEmpty)
	}

	func testNoActivePrefix_returnsEmpty() {
		let provider = makeProvider(checker: ["help"])
		XCTAssertTrue(provider.suggestions(for: .test(before: "hello ")).isEmpty)
		XCTAssertTrue(provider.suggestions(for: .test(before: nil)).isEmpty)
	}

	func testMidWordCursor_returnsEmpty() {
		let provider = makeProvider(checker: ["hello"])
		XCTAssertTrue(provider.suggestions(for: .test(before: "hel", after: "lo")).isEmpty)
	}

	func testShortcodeContext_suppressesWordCompletions() {
		// `:zz` — Slack itself has no match, but word completions must still stay out of the way
		// rather than offering completions for the stripped "zz".
		XCTAssertTrue(makeProvider(checker: ["zz", "zzz"]).suggestions(for: .test(before: ":zz")).isEmpty)
		// `:s` — below Slack's two-char typeahead threshold; still suppressed.
		XCTAssertTrue(makeProvider(checker: ["save", "smile"]).suggestions(for: .test(before: ":s")).isEmpty)
		// A bare word (no colon) is unaffected.
		XCTAssertFalse(makeProvider(checker: ["save"]).suggestions(for: .test(before: "sa")).isEmpty)
	}

	// MARK: - Smart capitalization (CAP3)

	func testCapitalizedPrefix_capitalizesChip() {
		let provider = makeProvider(recents: [("hello", 1)])
		let result = provider.suggestions(for: .test(before: "Hel", page: .letters(.upper)))
		XCTAssertEqual(result.first?.displayText, "Hello")
		XCTAssertEqual(result.first?.replacementText, "Hello", "tap inserts WYSIWYG")
	}

	func testCapsLock_uppercasesChip() {
		let provider = makeProvider(recents: [("hello", 1)])
		let result = provider.suggestions(for: .test(before: "HE", page: .letters(.capsLock)))
		XCTAssertEqual(result.first?.displayText, "HELLO")
	}

	func testLowercasePrefix_keepsLowercase() {
		let provider = makeProvider(checker: ["hello"])
		XCTAssertEqual(provider.suggestions(for: .test(before: "hel")).first?.displayText, "hello")
	}

	// MARK: - Lowercase base + directional diacritic variants

	/// Builds a provider whose recents return `fixed` for any non-empty prefix — models the real
	/// store's folded matches (which the provider consumes verbatim).
	private func provider(recentsFixed fixed: [(word: String, count: Int)]) -> WordCompletionProvider {
		WordCompletionProvider(
			textChecker: MockTextChecker(),
			systemLexicon: MockSystemLexicon(),
			recents: MockRecents(fixedMatches: fixed)
		)
	}

	func testDiacriticVariants_bothOffered_lowercaseMidSentence() {
		let result = provider(recentsFixed: [("rada", 2), ("ráda", 1)])
			.suggestions(for: .test(before: "rad"))
		XCTAssertEqual(Set(result.map(\.displayText)), ["rada", "ráda"], "both variants, lowercase display")
	}

	func testTypedIdenticalWord_dropsOnlyThatVariant_keepsAccentedOne() {
		// Typing the exact "rada" self-match-drops "rada" but leaves the accented "ráda" to offer.
		let result = provider(recentsFixed: [("rada", 2), ("ráda", 1)])
			.suggestions(for: .test(before: "rada"))
		XCTAssertEqual(result.map(\.displayText), ["ráda"])
	}

	func testStartOfSentence_capitalizesBothVariants() {
		let result = provider(recentsFixed: [("rada", 2), ("ráda", 1)])
			.suggestions(for: .test(before: "Rad", page: .letters(.upper)))
		XCTAssertEqual(Set(result.map(\.displayText)), ["Rada", "Ráda"], "leading capital by sentence position")
	}

	// MARK: - Additive multi-language completion (accent adds a language, task 65)

	private func multiLanguageProvider(_ byLanguage: [String: [String]]) -> WordCompletionProvider {
		WordCompletionProvider(
			textChecker: MockTextChecker(byLanguage: byLanguage),
			systemLexicon: MockSystemLexicon(),
			recents: MockRecents()
		)
	}

	func testMultiLanguage_mergesBothDictionaries() {
		// EN + CS are each queried once and the hits are merged into one ranked list.
		let provider = multiLanguageProvider(["en": ["help"], "cs": ["hejno", "helma"]])
		let result = provider.suggestions(for: .test(before: "he", languages: ["en", "cs"]))
		XCTAssertEqual(Set(result.map(\.displayText)), ["help", "hejno", "helma"])
	}

	func testMultiLanguage_dedupeKeepsMaxScoreAcrossLanguages() {
		// "slovo" is the best hit (idx0 → 0.9) in cs but the worst (idx1 → 0.4) in en; it collapses
		// to a single chip carrying the higher score, so neither language is privileged.
		let provider = multiLanguageProvider(["en": ["svet", "slovo"], "cs": ["slovo", "syn"]])
		let result = provider.suggestions(for: .test(before: "s", languages: ["en", "cs"]))
		XCTAssertEqual(result.filter { $0.displayText == "slovo" }.count, 1, "deduped to one chip")
		XCTAssertEqual(result.first { $0.displayText == "slovo" }?.score, 0.9, "the higher score wins")
	}

	func testSingleLanguage_onlyQueriesThatDictionary() {
		// Accent `.all` resolves to just `["en"]` — the cs dictionary is never consulted.
		let provider = multiLanguageProvider(["en": ["help"], "cs": ["hejno"]])
		let result = provider.suggestions(for: .test(before: "he", languages: ["en"]))
		XCTAssertEqual(result.map(\.displayText), ["help"])
	}

	func testEmptyLanguages_skipsCheckerButKeepsOtherSources() {
		// Defensive: the controller always supplies at least one language, but an empty list must
		// simply yield no checker hits while recents/lexicon still flow.
		let provider = makeProvider(recents: [("hello", 3)], checker: ["help"])
		let result = provider.suggestions(for: .test(before: "he", languages: []))
		XCTAssertEqual(result.map(\.displayText), ["hello"], "no checker hits; recents survive")
	}
}
