import XCTest
@testable import KeyboardCore

final class WordPrefixExtractorTests: XCTestCase {

	// MARK: - activeWordPrefix (boundary = whitespace/newline only, task 79)

	func testEndOfWord_returnsTrailingRun() {
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "Hello wor", after: nil), "wor")
	}

	func testSingleWord_returnsWholeWord() {
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "hel", after: nil), "hel")
	}

	func testApostrophe_isWordCharacter() {
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "don'", after: nil), "don'")
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "it's", after: nil), "it's")
	}

	func testHyphen_isWordCharacter() {
		// Whitespace-only boundary: the hyphen now stays in the token, so "well-known" is one word.
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "well-kno", after: nil), "well-kno")
	}

	func testDigits_areWordCharacters() {
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "ipv6", after: nil), "ipv6")
	}

	func testAllDigits_isAWord() {
		// Task 74: numbers tokenize as whole words (years, phones).
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "2026", after: nil), "2026")
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "Call 604", after: nil), "604")
	}

	func testAlphanumericNick_isAWord() {
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "freedom266", after: nil), "freedom266")
	}

	func testLeadingPunctuation_staysInPrefix_trimmedOnlyAtStore() {
		// A leading `+`/`(` is now part of the active prefix (whitespace-only boundary). It's the
		// store-side `wordCore` — not the tokenizer — that strips edge punctuation before learning.
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "+420604731026", after: nil), "+420604731026")
		XCTAssertEqual(WordPrefixExtractor.lastCompletedWord(in: "+420604731026 "), "+420604731026")
		XCTAssertEqual(WordPrefixExtractor.wordCore(of: "+420604731026"), "420604731026", "edge `+` trimmed for storage")
	}

	func testDiacritics_areWordCharacters() {
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "café", after: nil), "café")
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "naï", after: nil), "naï")
	}

	func testEmailThroughDots_staysOneToken() {
		// The whole point of task 79: an in-progress address survives the dots as a single prefix, so it
		// keeps prefix-matching a stored `sv.mar@email.cz` at every step.
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "sv.", after: nil), "sv.")
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "sv.mar", after: nil), "sv.mar")
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "sv.mar@e", after: nil), "sv.mar@e")
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "type sv.mar@email.cz", after: nil), "sv.mar@email.cz")
	}

	func testTrailingWhitespace_returnsNil() {
		// Only whitespace/newline ends a word now — trailing punctuation does not.
		XCTAssertNil(WordPrefixExtractor.activeWordPrefix(before: "Hello ", after: nil))
		XCTAssertNil(WordPrefixExtractor.activeWordPrefix(before: "Hello\n", after: nil))
	}

	func testTrailingPunctuation_isNoLongerABoundary() {
		// Punctuation stays in the token (it's trimmed only at the store gate, not here).
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "Hello.", after: nil), "Hello.")
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "(", after: nil), "(")
	}

	func testEmptyOrNil_returnsNil() {
		XCTAssertNil(WordPrefixExtractor.activeWordPrefix(before: "", after: nil))
		XCTAssertNil(WordPrefixExtractor.activeWordPrefix(before: nil, after: nil))
	}

	func testMidWordCursor_returnsNil() {
		// Caret between "hel" and "lo" — completing here would mangle the tail.
		XCTAssertNil(WordPrefixExtractor.activeWordPrefix(before: "hel", after: "lo"))
	}

	func testCursorBeforeWhitespace_isNotMidWord() {
		// Caret after "hel" with a space following is a legitimate completion point.
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: "hel", after: " world"), "hel")
	}

	func testColonPrefix_keptInToken() {
		// `:` is no longer a boundary, so the Slack-context buffer keeps the leading `:` in the prefix.
		// (The coordinator's Slack-priority rule, not the tokenizer, is what suppresses word completions.)
		XCTAssertEqual(WordPrefixExtractor.activeWordPrefix(before: ":sm", after: nil), ":sm")
	}

	// MARK: - lastCompletedWord (raw trailing run; punctuation trimmed later by wordCore)

	func testLastCompletedWord_afterSpace() {
		XCTAssertEqual(WordPrefixExtractor.lastCompletedWord(in: "Hello world "), "world")
	}

	func testLastCompletedWord_afterPunctuation_keepsPunctuation() {
		// The raw run now carries the trailing punctuation; `wordCore` strips it before learning.
		XCTAssertEqual(WordPrefixExtractor.lastCompletedWord(in: "Hello world."), "world.")
		XCTAssertEqual(WordPrefixExtractor.lastCompletedWord(in: "Wait, "), "Wait,")
	}

	func testLastCompletedWord_noTrailingBoundary_returnsTrailingWord() {
		XCTAssertEqual(WordPrefixExtractor.lastCompletedWord(in: "Hello world"), "world")
	}

	func testLastCompletedWord_onlyWhitespace_returnsNil() {
		XCTAssertNil(WordPrefixExtractor.lastCompletedWord(in: "   "))
		XCTAssertNil(WordPrefixExtractor.lastCompletedWord(in: ""))
		XCTAssertNil(WordPrefixExtractor.lastCompletedWord(in: nil))
	}

	func testLastCompletedWord_punctuationRun_returnedRaw() {
		// A pure-punctuation trailing run is returned as-is — `wordCore` is what drops it (→ nil).
		XCTAssertEqual(WordPrefixExtractor.lastCompletedWord(in: " . "), ".")
		XCTAssertNil(WordPrefixExtractor.wordCore(of: "."))
	}

	func testLastCompletedWord_preservesApostropheAndDiacritics() {
		XCTAssertEqual(WordPrefixExtractor.lastCompletedWord(in: "don't "), "don't")
		XCTAssertEqual(WordPrefixExtractor.lastCompletedWord(in: "café "), "café")
	}

	// MARK: - wordCore (edge non-alphanumeric trim)

	func testWordCore_trimsEdgePunctuation_keepsInternal() {
		XCTAssertEqual(WordPrefixExtractor.wordCore(of: "ahoj,"), "ahoj")
		XCTAssertEqual(WordPrefixExtractor.wordCore(of: "(hi)"), "hi")
		XCTAssertEqual(WordPrefixExtractor.wordCore(of: "well-known"), "well-known", "internal hyphen kept")
		XCTAssertEqual(WordPrefixExtractor.wordCore(of: "3.14"), "3.14", "internal dot kept")
		XCTAssertEqual(WordPrefixExtractor.wordCore(of: "sv.mar@email.cz"), "sv.mar@email.cz", "address untouched")
		XCTAssertEqual(WordPrefixExtractor.wordCore(of: "e.g."), "e.g", "only the trailing dot is trimmed")
	}

	func testWordCore_nilWhenNoAlphanumericContent() {
		XCTAssertNil(WordPrefixExtractor.wordCore(of: "..."))
		XCTAssertNil(WordPrefixExtractor.wordCore(of: ":"))
		XCTAssertNil(WordPrefixExtractor.wordCore(of: ""))
	}

	// MARK: - isEmailShaped (store-gate, whole-token `^…$` match)

	func testIsEmailShaped_acceptsFullAddresses() {
		XCTAssertTrue(WordPrefixExtractor.isEmailShaped("martin@gmail.com"))
		XCTAssertTrue(WordPrefixExtractor.isEmailShaped("sv.mar@email.cz"))
		XCTAssertTrue(WordPrefixExtractor.isEmailShaped("martin@company.co.uk"))
		XCTAssertTrue(WordPrefixExtractor.isEmailShaped("martin.svoboda026+tag@gmail.com"))
	}

	func testIsEmailShaped_rejectsNonAddresses() {
		XCTAssertFalse(WordPrefixExtractor.isEmailShaped("foo@bar"), "no TLD dot")
		XCTAssertFalse(WordPrefixExtractor.isEmailShaped("sv.mar@email"), "half-typed, no TLD")
		XCTAssertFalse(WordPrefixExtractor.isEmailShaped("e.g"), "no @")
		XCTAssertFalse(WordPrefixExtractor.isEmailShaped("u.s.a"), "no @")
		XCTAssertFalse(WordPrefixExtractor.isEmailShaped(""))
	}

	func testIsEmailShaped_requiresWholeTokenMatch() {
		// `^…$`-anchored: surrounding text means it's not a bare address token (the harvester passes the
		// already-isolated, edge-trimmed token, so embedded matches must not slip through).
		XCTAssertFalse(WordPrefixExtractor.isEmailShaped("at martin@gmail.com"))
		XCTAssertFalse(WordPrefixExtractor.isEmailShaped("martin@gmail.com is mine"))
	}

	func testIsEmailShaped_rejectsOverlongAddress() {
		let huge = String(repeating: "a", count: 95) + "@x.com" // > 100 chars
		XCTAssertFalse(WordPrefixExtractor.isEmailShaped(huge))
	}
}
