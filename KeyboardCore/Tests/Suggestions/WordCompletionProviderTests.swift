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
			recents: [("hello", 10)],          // 0.55 + 0.05*10 + 0.2 boost → 1.25
			checker: ["help", "helicopter"],   // idx0 → 0.9, idx1 → 0.4
			lexicon: ["hey"]                   // flat 0.3
		)
		let result = provider.suggestions(for: .test(before: "he"))
		XCTAssertEqual(result.map(\.displayText), ["hello", "help", "helicopter", "hey"])
		XCTAssertEqual(result.first?.score ?? 0, 1.25, accuracy: 0.0001)
		XCTAssertEqual(result.first(where: { $0.displayText == "help" })?.score, 0.9)
		XCTAssertEqual(result.first(where: { $0.displayText == "helicopter" })?.score ?? 0, 0.4, accuracy: 0.0001)
		XCTAssertEqual(result.first(where: { $0.displayText == "hey" })?.score, 0.3)
	}

	func testRecentsScore_countContributionSaturatesAtTen_noUpperClamp() {
		// The count term saturates at `min(count, 10)`, but there's no `[0, 1]` clamp (task 80): a
		// count-99 word scores 0.55 + 0.05*10 + 0.2 = 1.25, the same as count 10, and is free to exceed 1.0.
		let provider = makeProvider(recents: [("hello", 99)])
		XCTAssertEqual(provider.suggestions(for: .test(before: "he")).first?.score ?? 0, 1.25, accuracy: 0.0001)
	}

	func testAllChips_arePlainWordCompletions() {
		let result = makeProvider(checker: ["help"]).suggestions(for: .test(before: "he"))
		XCTAssertEqual(result.first?.renderStyle, .plain)
		XCTAssertEqual(result.first?.source, .wordCompletion)
		XCTAssertEqual(result.first?.replacementText, result.first?.displayText)
	}

	// MARK: - Self-match exclusion

	func testSelfMatch_excluded() {
		// Both counts ≥ minSuggestCount so the assertion isolates self-match exclusion from the threshold.
		let provider = makeProvider(recents: [("hello", 3), ("hellofresh", 2)])
		let result = provider.suggestions(for: .test(before: "hello"))
		XCTAssertEqual(result.map(\.displayText), ["hellofresh"], "the fully-typed word is not offered back")
	}

	// MARK: - Case-insensitive dedupe

	func testDedupe_caseInsensitive_keepsHighestScore() {
		// Recents "Hello" (count 2 → 0.85 boosted) and checker "hello" (idx0 → 0.9) collapse to one chip.
		let provider = makeProvider(recents: [("Hello", 2)], checker: ["hello"])
		let result = provider.suggestions(for: .test(before: "he"))
		XCTAssertEqual(result.count, 1)
		XCTAssertEqual(result.first?.displayText, "Hello", "recents' base casing is preserved")
		XCTAssertEqual(result.first?.score, 0.9, "the higher (checker) score wins")
	}

	// MARK: - Personal-recents soft boost & crossover (task 80)

	func testPersonalBoost_countTwo_yieldsTopSlotToBestDictionaryHit_butBeatsWeakerOnes() {
		// A freshly-learned word (count 2 → 0.85) sits just under the best `UITextChecker` hit (0.9),
		// so the dictionary keeps the top slot — but 0.85 still outranks every weaker checker hit.
		let provider = makeProvider(
			recents: [("hello", 2)],                       // 0.85
			checker: ["help", "held", "helm", "helix"]     // 0.9, 0.733, 0.567, 0.4
		)
		let result = provider.suggestions(for: .test(before: "hel"))
		XCTAssertEqual(result.map(\.displayText), ["help", "hello", "held", "helm", "helix"])
	}

	func testPersonalBoost_countThree_tiesBestDictionaryHitExactly_notAStrictWin() {
		// count 3 → 0.90 must land *exactly* on the dictionary top (0.9), a genuine tie — not the
		// 0.90000…13 binary-FP dust that would strictly outrank it and pull the crossover down to count 3.
		let provider = makeProvider(recents: [("hello", 3)], checker: ["help"])
		let score = provider.suggestions(for: .test(before: "hel")).first(where: { $0.displayText == "hello" })?.score
		XCTAssertEqual(score, 0.9, "count-3 score is exactly the dictionary top, so count 4 is the firm crossover")
	}

	func testPersonalBoost_countFour_winsTopSlotOverBestDictionaryHit() {
		// The crossover: at count 4 (0.95) the learned word overtakes the best dictionary hit (0.9).
		let provider = makeProvider(recents: [("hello", 4)], checker: ["help"])
		let result = provider.suggestions(for: .test(before: "hel"))
		XCTAssertEqual(result.map(\.displayText), ["hello", "help"])
		XCTAssertEqual(result.first?.score ?? 0, 0.95, accuracy: 0.0001)
	}

	func testTwoLearnedWords_sortByCountAboveEight_clampDoesNotFlatten() {
		// Without the old `[0, 1]` clamp, two high-count words keep distinct scores and sort by count
		// (count 10 → 1.25 over count 9 → 1.20). Order is count-driven, *opposite* to the alphabetical
		// tie-break the clamp would have forced when both saturated at 1.0.
		let provider = makeProvider(recents: [("helium", 9), ("helmet", 10)])
		let result = provider.suggestions(for: .test(before: "hel"))
		XCTAssertEqual(result.map(\.displayText), ["helmet", "helium"])
	}

	// MARK: - Display threshold (minSuggestCount, Fáze A)

	func testRecentsBelowThreshold_notOffered() {
		// A count-1 personal word (a one-off typo, or a singleton OTP/code) is learned but never shown.
		let provider = makeProvider(recents: [("freedom266", 1)])
		XCTAssertTrue(provider.suggestions(for: .test(before: "free")).isEmpty)
	}

	func testRecentsAtThreshold_offered() {
		// The same word at count 2 clears the bar and is offered.
		let provider = makeProvider(recents: [("freedom266", 2)])
		XCTAssertEqual(provider.suggestions(for: .test(before: "free")).map(\.displayText), ["freedom266"])
	}

	func testBelowThreshold_stillSurfacesWhenDictionaryVouches() {
		// A sub-threshold personal singleton that's also a real dictionary word still shows — the cut
		// only removes pool-exclusive one-offs, never words a dictionary source confirms.
		let provider = makeProvider(recents: [("hello", 1)], checker: ["hello"])
		XCTAssertEqual(provider.suggestions(for: .test(before: "hel")).map(\.displayText), ["hello"])
	}

	func testEmailContext_singleUseAddress_heldBackByUniformThreshold() {
		// Task 77 removed the address exemption: a once-typed address is now gated by the same
		// `minSuggestCount` as prose — held back in an email field exactly as in any other.
		let email = SuggestionEligibility(allowDisplay: true, learningContext: .emailAddress)
		let provider = makeProvider(recents: [("martin@x.com", 1)])
		XCTAssertTrue(provider.suggestions(for: .test(before: "mar", eligibility: email)).isEmpty)
		// Same in a prose field — no field-specific special-casing remains either way.
		XCTAssertTrue(provider.suggestions(for: .test(before: "mar")).isEmpty)
	}

	func testEmailContext_addressAtThreshold_offered() {
		// Two uses clear the threshold; the address then completes from its prefix in an email field.
		let email = SuggestionEligibility(allowDisplay: true, learningContext: .emailAddress)
		let provider = makeProvider(recents: [("martin@x.com", 2)])
		let result = provider.suggestions(for: .test(before: "mar", eligibility: email))
		XCTAssertEqual(result.map(\.displayText), ["martin@x.com"])
	}

	// MARK: - Gating

	func testSymbolsPage_returnsSuggestions() {
		// Fáze B: completions now run on `.symbols` too (numbers/nicks for users without a number row).
		let provider = makeProvider(recents: [("604593010", 3)])
		let result = provider.suggestions(for: .test(before: "604", page: .symbols(.primary)))
		XCTAssertEqual(result.map(\.displayText), ["604593010"])
	}

	func testEmojiPage_returnsEmpty() {
		let provider = makeProvider(checker: ["help"])
		XCTAssertTrue(provider.suggestions(for: .test(before: "he", page: .emojis)).isEmpty)
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
		let provider = makeProvider(recents: [("hello", 2)])
		let result = provider.suggestions(for: .test(before: "Hel", page: .letters(.upper)))
		XCTAssertEqual(result.first?.displayText, "Hello")
		XCTAssertEqual(result.first?.replacementText, "Hello", "tap inserts WYSIWYG")
	}

	func testCapsLock_uppercasesChip() {
		let provider = makeProvider(recents: [("hello", 2)])
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
		// Both ≥ minSuggestCount so the threshold doesn't drop a variant out from under the assertion.
		let result = provider(recentsFixed: [("rada", 2), ("ráda", 2)])
			.suggestions(for: .test(before: "rad"))
		XCTAssertEqual(Set(result.map(\.displayText)), ["rada", "ráda"], "both variants, lowercase display")
	}

	func testTypedIdenticalWord_dropsOnlyThatVariant_keepsAccentedOne() {
		// Typing the exact "rada" self-match-drops "rada" but leaves the accented "ráda" to offer.
		let result = provider(recentsFixed: [("rada", 2), ("ráda", 2)])
			.suggestions(for: .test(before: "rada"))
		XCTAssertEqual(result.map(\.displayText), ["ráda"])
	}

	func testStartOfSentence_capitalizesBothVariants() {
		let result = provider(recentsFixed: [("rada", 2), ("ráda", 2)])
			.suggestions(for: .test(before: "Rad", page: .letters(.upper)))
		XCTAssertEqual(Set(result.map(\.displayText)), ["Rada", "Ráda"], "leading capital by sentence position")
	}

	// MARK: - Multi-language completion merge (provider still merges if given several; task 78)
	//
	// The controller supplies a single completion language today (task 78 / ADR 0002), but the
	// provider keeps its multi-language merge so the `[String]` API stays future-proof. These tests
	// exercise that retained contract directly by handing it more than one language.

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
		// One language in, one dictionary queried — the others are never consulted. This is the
		// everyday path now that the controller resolves a single completion language (task 78).
		let provider = multiLanguageProvider(["en": ["help"], "cs": ["hejno"]])
		let result = provider.suggestions(for: .test(before: "he", languages: ["en"]))
		XCTAssertEqual(result.map(\.displayText), ["help"])
	}

	func testRecents_areLanguageAgnostic() {
		// Learned words aren't filtered by the completion language: an English word the user actually
		// typed still surfaces under a Czech completion language. This is the softening that makes the
		// single-language model acceptable (task 78 / ADR 0002) — accent users keep their real recents.
		let provider = makeProvider(recents: [("hello", 3)], checker: [])
		let result = provider.suggestions(for: .test(before: "he", languages: ["cs"]))
		XCTAssertEqual(result.map(\.displayText), ["hello"])
	}

	func testEmptyLanguages_skipsCheckerButKeepsOtherSources() {
		// Defensive: the controller always supplies at least one language, but an empty list must
		// simply yield no checker hits while recents/lexicon still flow.
		let provider = makeProvider(recents: [("hello", 3)], checker: ["help"])
		let result = provider.suggestions(for: .test(before: "he", languages: []))
		XCTAssertEqual(result.map(\.displayText), ["hello"], "no checker hits; recents survive")
	}
}
