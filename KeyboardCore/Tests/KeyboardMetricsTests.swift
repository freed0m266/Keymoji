import XCTest
import KeymojiCore
@testable import KeyboardCore

/// Bottom-up sizing model (task 52): cap heights are fixed and the total keyboard height is *derived*.
/// These tests pin the derivation so the SwiftUI frame and the host UIInputView constraint — both of
/// which call `KeyboardMetrics.keyboardHeight` — stay in agreement and can't silently drift.
final class KeyboardMetricsTests: XCTestCase {

	// MARK: - Row slots

	func testRowSlotHeight_numberRowIsShorterThanStandardRow() {
		let standard = KeyboardMetrics.rowSlotHeight(isNumberRow: false)
		let number = KeyboardMetrics.rowSlotHeight(isNumberRow: true)
		XCTAssertEqual(standard, KeyboardMetrics.keyCapHeight + KeyboardMetrics.rowGap)
		XCTAssertEqual(number, KeyboardMetrics.numberRowCapHeight + KeyboardMetrics.rowGap)
		XCTAssertLessThan(number, standard, "Number row is intentionally a touch shorter")
	}

	func testSuggestionBarFootprint_isBarHeightPlusGap() {
		XCTAssertEqual(
			KeyboardMetrics.suggestionBarFootprint,
			KeyboardMetrics.suggestionBarHeight + KeyboardMetrics.suggestionBarGap
		)
	}

	// MARK: - keyboardHeight derivation

	func testKeyboardHeight_lettersWithNumberRow_sumsAllRowSlots() {
		let layout = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
		// number + 3 letter rows + bottom row.
		let expected = KeyboardMetrics.rowSlotHeight(isNumberRow: true)
			+ 4 * KeyboardMetrics.rowSlotHeight(isNumberRow: false)
		XCTAssertEqual(KeyboardMetrics.keyboardHeight(for: layout, showsSuggestionBar: false), expected)
	}

	func testKeyboardHeight_lettersWithoutNumberRow_sumsBodyAndBottom() {
		let layout = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: false, returnKeyType: .default)
		// 3 letter rows + bottom row.
		let expected = 4 * KeyboardMetrics.rowSlotHeight(isNumberRow: false)
		XCTAssertEqual(KeyboardMetrics.keyboardHeight(for: layout, showsSuggestionBar: false), expected)
	}

	func testKeyboardHeight_suggestionBarAddsItsFootprint() {
		let layout = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
		let without = KeyboardMetrics.keyboardHeight(for: layout, showsSuggestionBar: false)
		let with = KeyboardMetrics.keyboardHeight(for: layout, showsSuggestionBar: true)
		XCTAssertEqual(with - without, KeyboardMetrics.suggestionBarFootprint)
	}

	func testKeyboardHeight_lettersAndSymbolsAreEqual_whenNoBar() {
		// Same row count, same cap heights — the keys are now the same height across pages. The only
		// resting difference between letters and symbols is the bar (which symbols never show).
		for showNumber in [true, false] {
			let letters = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: showNumber, returnKeyType: .default)
			let symbols = LayoutBuilder.layout(page: .symbols(.primary), showNumberRow: showNumber, returnKeyType: .default)
			XCTAssertEqual(
				KeyboardMetrics.keyboardHeight(for: letters, showsSuggestionBar: false),
				KeyboardMetrics.keyboardHeight(for: symbols, showsSuggestionBar: false)
			)
		}
	}

	func testKeyboardHeight_emojiSearch_dropsNumberRowAndAddsChrome() {
		let layout = LayoutBuilder.layout(page: .emojiSearch, showNumberRow: true, returnKeyType: .default)
		// Number row is dropped in search mode → 3 letter rows + bottom row, plus the search chrome.
		let expected = 4 * KeyboardMetrics.rowSlotHeight(isNumberRow: false)
			+ KeyboardMetrics.emojiSearchChromeHeight
		XCTAssertEqual(KeyboardMetrics.keyboardHeight(for: layout, showsSuggestionBar: false), expected)
	}

	func testKeyboardHeight_emojiPage_matchesLettersPageOfSameNumberRowPreference() {
		// The emoji page renders a panel in place of the letter rows, but its height must match a
		// letters page (sans bar) so the panel keeps today's footprint — even though `layout.rows`
		// only carries the bottom row.
		for showNumber in [true, false] {
			let emoji = LayoutBuilder.layout(page: .emojis, showNumberRow: showNumber, returnKeyType: .default)
			let letters = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: showNumber, returnKeyType: .default)
			XCTAssertEqual(
				KeyboardMetrics.keyboardHeight(for: emoji, showsSuggestionBar: false),
				KeyboardMetrics.keyboardHeight(for: letters, showsSuggestionBar: false),
				"Emoji page (showNumberRow: \(showNumber)) must size like the equivalent letters page"
			)
		}
	}

	func testKeyboardHeight_emojiPage_ignoresSuggestionBar() {
		// The emoji page never shows the suggestion bar, so the flag must not change its height.
		let layout = LayoutBuilder.layout(page: .emojis, showNumberRow: true, returnKeyType: .default)
		XCTAssertEqual(
			KeyboardMetrics.keyboardHeight(for: layout, showsSuggestionBar: true),
			KeyboardMetrics.keyboardHeight(for: layout, showsSuggestionBar: false)
		)
	}

	func testKeyboardHeight_scalesWithCapHeight() {
		// Total height is a pure sum of row slots (+ bar / chrome), so it tracks `keyCapHeight` directly:
		// raising the cap by `delta` raises every standard row slot — and the total — by the same delta
		// per standard row. This pins the bottom-up contract without mutating the constant.
		let layout = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: false, returnKeyType: .default)
		let standardRows = layout.rows.filter { !$0.isNumberRow }.count
		let total = KeyboardMetrics.keyboardHeight(for: layout, showsSuggestionBar: false)
		XCTAssertEqual(total, CGFloat(standardRows) * (KeyboardMetrics.keyCapHeight + KeyboardMetrics.rowGap))
	}
}
