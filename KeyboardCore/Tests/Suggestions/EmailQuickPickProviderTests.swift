import XCTest
@testable import KeyboardCore

final class EmailQuickPickProviderTests: XCTestCase {

	private let emailEligibility = SuggestionEligibility(allowDisplay: true, learningContext: .emailAddress)

	private func makeProvider(_ all: [LearnedWord]) -> EmailQuickPickProvider {
		EmailQuickPickProvider(recents: MockRecents(allEntries: all))
	}

	private func word(_ word: String, count: Int, lastUsed: Double = 0) -> LearnedWord {
		LearnedWord(word: word, count: count, lastUsed: lastUsed)
	}

	// MARK: - Best-pick selection

	func testEmptyEmailField_offersHighestCountAddress() {
		let provider = makeProvider([
			word("rare@x.com", count: 1),
			word("daily@x.com", count: 9),
			word("sometimes@x.com", count: 3)
		])
		let result = provider.suggestions(for: .test(before: nil, eligibility: emailEligibility))
		XCTAssertEqual(result.map(\.displayText), ["daily@x.com"], "the most-used address wins")
	}

	func testTieOnCount_brokenByMostRecent() {
		let provider = makeProvider([
			word("old@x.com", count: 4, lastUsed: 100),
			word("new@x.com", count: 4, lastUsed: 500)
		])
		let result = provider.suggestions(for: .test(before: nil, eligibility: emailEligibility))
		XCTAssertEqual(result.map(\.displayText), ["new@x.com"], "equal counts → the more recent address")
	}

	func testSingleUseAddress_notOffered() {
		// Task 77 removed the email exemption: one prior use no longer clears the uniform threshold.
		let provider = makeProvider([word("once@x.com", count: 1)])
		XCTAssertTrue(provider.suggestions(for: .test(before: nil, eligibility: emailEligibility)).isEmpty)
	}

	func testAddressAtThreshold_offered() {
		// Two prior uses clear `minSuggestCount`, so the quick-pick offers the address.
		let provider = makeProvider([word("twice@x.com", count: 2)])
		XCTAssertEqual(provider.suggestions(for: .test(before: nil, eligibility: emailEligibility)).map(\.displayText), ["twice@x.com"])
	}

	func testBelowThresholdAddressesOnly_returnsEmpty() {
		// A pool of only single-use addresses now offers nothing — all are below `minSuggestCount`.
		let provider = makeProvider([word("a@x.com", count: 1), word("b@x.com", count: 1)])
		XCTAssertTrue(provider.suggestions(for: .test(before: nil, eligibility: emailEligibility)).isEmpty)
	}

	// MARK: - Chip shape

	func testChip_isPlainWordCompletion_insertingWholeAddress() {
		let provider = makeProvider([word("martin@x.com", count: 2)])
		let chip = provider.suggestions(for: .test(before: nil, eligibility: emailEligibility)).first
		XCTAssertEqual(chip?.renderStyle, .plain)
		XCTAssertEqual(chip?.source, .wordCompletion)
		XCTAssertEqual(chip?.replacementText, "martin@x.com", "tap inserts the whole address")
	}

	// MARK: - Silence conditions

	func testActivePrefix_staysSilent() {
		// Once the user starts typing, the normal prefix-match path owns it — quick-pick defers.
		let provider = makeProvider([word("martin@x.com", count: 5)])
		XCTAssertTrue(provider.suggestions(for: .test(before: "mar", eligibility: emailEligibility)).isEmpty)
	}

	func testMidAddressAfterBoundary_staysSilent() {
		// `@` and `.` are word boundaries, so `activeWordPrefix` reads nil here — but the field is *not*
		// empty, so the quick-pick must stay silent rather than append a whole saved address mid-input.
		let provider = makeProvider([word("martin@x.com", count: 5)])
		XCTAssertTrue(provider.suggestions(for: .test(before: "user@", eligibility: emailEligibility)).isEmpty)
		XCTAssertTrue(provider.suggestions(for: .test(before: "user@gmail.", eligibility: emailEligibility)).isEmpty)
	}

	func testContentAfterCaret_staysSilent() {
		// Caret at the start of an already-populated field: content after the caret means it's not empty.
		let provider = makeProvider([word("martin@x.com", count: 5)])
		XCTAssertTrue(provider.suggestions(for: .test(before: nil, after: "existing@x.com", eligibility: emailEligibility)).isEmpty)
	}

	func testNonEmailContext_staysSilent() {
		// In a prose field the quick-pick never fires, even with addresses in the pool.
		let provider = makeProvider([word("martin@x.com", count: 5)])
		XCTAssertTrue(provider.suggestions(for: .test(before: nil)).isEmpty)
	}

	func testNoLearnedAddresses_returnsEmpty() {
		// Words without an `@` are not addresses — nothing to offer.
		let provider = makeProvider([word("hello", count: 9), word("world", count: 4)])
		XCTAssertTrue(provider.suggestions(for: .test(before: nil, eligibility: emailEligibility)).isEmpty)
	}

	func testEmptyPool_returnsEmpty() {
		XCTAssertTrue(makeProvider([]).suggestions(for: .test(before: nil, eligibility: emailEligibility)).isEmpty)
	}
}
