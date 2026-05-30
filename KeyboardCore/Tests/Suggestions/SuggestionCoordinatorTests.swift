import XCTest
@testable import KeyboardCore

final class SuggestionCoordinatorTests: XCTestCase {

	// MARK: - Slack priority

	func testSlackNonEmpty_winsWholesale_overWordCompletions() {
		let slack = StubProvider(result: [.pill("smile", "😄"), .pill("smiley", "😃")])
		let words = StubProvider(result: [.word("smitten", score: 0.9), .word("smith", score: 0.8)])
		let coordinator = SuggestionCoordinator(providers: [slack, words], limit: 3)
		let result = coordinator.suggestions(for: .test(before: ":smi"))
		XCTAssertEqual(result.map(\.source), [.slack, .slack])
		XCTAssertEqual(result.map(\.displayText), ["smile", "smiley"])
	}

	func testSlack_notTruncatedByWordLimit() {
		// The `limit` applies to word completions, not the Slack typeahead (which is already capped
		// by the suggester). Five pills survive a limit of 3.
		let pills = (0..<5).map { Suggestion.pill("code\($0)", "🙂") }
		let coordinator = SuggestionCoordinator(providers: [StubProvider(result: pills)], limit: 3)
		XCTAssertEqual(coordinator.suggestions(for: .test(before: ":co")).count, 5)
	}

	// MARK: - Word-completion fallback

	func testNoSlack_mergesAndSortsByScore() {
		let provider = StubProvider(result: [
			.word("beta", score: 0.5),
			.word("alpha", score: 0.9),
			.word("gamma", score: 0.7)
		])
		let result = SuggestionCoordinator(providers: [provider], limit: 3).suggestions(for: .test(before: "x"))
		XCTAssertEqual(result.map(\.displayText), ["alpha", "gamma", "beta"])
	}

	func testLimit_enforced() {
		let provider = StubProvider(result: [
			.word("a", score: 0.9), .word("b", score: 0.8),
			.word("c", score: 0.7), .word("d", score: 0.6)
		])
		XCTAssertEqual(SuggestionCoordinator(providers: [provider], limit: 3).suggestions(for: .test(before: "x")).count, 3)
	}

	func testFewerThanLimit_returnsWhatWeHave() {
		let provider = StubProvider(result: [.word("only", score: 0.9)])
		XCTAssertEqual(SuggestionCoordinator(providers: [provider], limit: 3).suggestions(for: .test(before: "x")).count, 1)
	}

	func testDedupe_caseInsensitive_acrossProviders() {
		let p1 = StubProvider(result: [.word("Hello", score: 0.9)])
		let p2 = StubProvider(result: [.word("hello", score: 0.4)])
		let result = SuggestionCoordinator(providers: [p1, p2], limit: 3).suggestions(for: .test(before: "he"))
		XCTAssertEqual(result.count, 1)
		XCTAssertEqual(result.first?.score, 0.9, "the higher-scored representative is kept")
	}

	func testEmptyProviders_returnEmpty() {
		let coordinator = SuggestionCoordinator(providers: [StubProvider(result: [])], limit: 3)
		XCTAssertTrue(coordinator.suggestions(for: .test(before: "x")).isEmpty)
	}
}
