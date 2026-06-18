import XCTest
import KeymojiCore
@testable import KeyboardCore

/// Bottom-up sizing model (task 52) generalized to a constant per-setting keyboard height (task 61):
/// cap heights are fixed, every page is sized to one `canonicalHeight`, and the total is *derived* with
/// no `showsSuggestionBar` term. These tests pin the derivation so the SwiftUI frame and the host
/// UIInputView constraint — both of which call `KeyboardMetrics.keyboardHeight` — stay in agreement and
/// can't silently drift, and so the height is decoupled from whether the suggestion bar is shown.
final class KeyboardMetricsTests: XCTestCase {

	/// All pages a real keyboard can be on, at both number-row preferences. The exhaustive matrix the
	/// host-vs-view and constant-height tests sweep.
	private static let allPages: [KeyboardPage] = [
		.letters(.lower), .letters(.upper), .letters(.capsLock),
		.symbols(.primary), .symbols(.alternate),
		.emojis,
		.emojiSearch, .emojiSearchSymbols(.primary),
		.numeric(.integer), .numeric(.decimal)
	]

	private func layout(_ page: KeyboardPage, showNumberRow: Bool) -> KeyboardLayout {
		LayoutBuilder.layout(page: page, showNumberRow: showNumberRow, returnKeyType: .default)
	}

	// MARK: - Row slots

	func testRowSlotHeight_numberRowIsShorterThanStandardRow() {
		let standard = KeyboardMetrics.rowSlotHeight(isNumberRow: false)
		let number = KeyboardMetrics.rowSlotHeight(isNumberRow: true)
		XCTAssertEqual(standard, KeyboardMetrics.keyCapHeight + KeyboardMetrics.rowGap)
		XCTAssertEqual(number, KeyboardMetrics.numberRowCapHeight + KeyboardMetrics.rowGap)
		XCTAssertLessThan(number, standard, "Number row is intentionally a touch shorter")
	}

	func testTopRegionHeight_isBarHeightPlusGap() {
		// The bar (40) + gap (2) are an internal detail of how the suggestion bar fills the 42pt region.
		XCTAssertEqual(
			KeyboardMetrics.topRegionHeight,
			KeyboardMetrics.suggestionBarHeight + KeyboardMetrics.suggestionBarGap
		)
	}

	// MARK: - canonicalHeight

	func testCanonicalHeight_isNumberRowPlusQwertyRowsPlusTopRegion() {
		let withRow = KeyboardMetrics.canonicalHeight(showsNumberRow: true)
		let withoutRow = KeyboardMetrics.canonicalHeight(showsNumberRow: false)
		XCTAssertEqual(
			withRow,
			KeyboardMetrics.rowSlotHeight(isNumberRow: true)
				+ KeyboardMetrics.qwertyRowsHeight
				+ KeyboardMetrics.topRegionHeight
		)
		XCTAssertEqual(withoutRow, KeyboardMetrics.qwertyRowsHeight + KeyboardMetrics.topRegionHeight)
		XCTAssertEqual(withRow - withoutRow, KeyboardMetrics.rowSlotHeight(isNumberRow: true),
			"The only difference between the two is the number-row slot")
	}

	func testQwertyRowsHeight_isFourStandardRowSlots() {
		XCTAssertEqual(KeyboardMetrics.qwertyRowsHeight, 4 * KeyboardMetrics.rowSlotHeight(isNumberRow: false))
	}

	// MARK: - keyboardHeight derivation

	func testKeyboardHeight_lettersWithNumberRow_isCanonical() {
		let letters = layout(.letters(.lower), showNumberRow: true)
		// number + 3 letter rows + bottom row + reserved top region.
		let expected = KeyboardMetrics.rowSlotHeight(isNumberRow: true)
			+ 4 * KeyboardMetrics.rowSlotHeight(isNumberRow: false)
			+ KeyboardMetrics.topRegionHeight
		XCTAssertEqual(KeyboardMetrics.keyboardHeight(for: letters), expected)
		XCTAssertEqual(KeyboardMetrics.keyboardHeight(for: letters), KeyboardMetrics.canonicalHeight(showsNumberRow: true))
	}

	func testKeyboardHeight_lettersWithoutNumberRow_isCanonical() {
		let letters = layout(.letters(.lower), showNumberRow: false)
		// 3 letter rows + bottom row + reserved top region (no number row).
		let expected = 4 * KeyboardMetrics.rowSlotHeight(isNumberRow: false) + KeyboardMetrics.topRegionHeight
		XCTAssertEqual(KeyboardMetrics.keyboardHeight(for: letters), expected)
		XCTAssertEqual(KeyboardMetrics.keyboardHeight(for: letters), KeyboardMetrics.canonicalHeight(showsNumberRow: false))
	}

	// MARK: - Constant height across pages (task 61)

	func testKeyboardHeight_lettersSymbolsEmojiAreEqual_perNumberRowState() {
		// The headline invariant: letters == symbols == emoji at a given number-row preference, so
		// switching pages never makes the keyboard jump.
		for showNumber in [true, false] {
			let letters = KeyboardMetrics.keyboardHeight(for: layout(.letters(.lower), showNumberRow: showNumber))
			let symbols = KeyboardMetrics.keyboardHeight(for: layout(.symbols(.primary), showNumberRow: showNumber))
			let emoji = KeyboardMetrics.keyboardHeight(for: layout(.emojis, showNumberRow: showNumber))
			XCTAssertEqual(letters, symbols, "letters and symbols must match (number row \(showNumber))")
			XCTAssertEqual(letters, emoji, "emoji must match letters (number row \(showNumber))")
			XCTAssertEqual(letters, KeyboardMetrics.canonicalHeight(showsNumberRow: showNumber))
		}
	}

	func testKeyboardHeight_emojiPage_growsToCanonical_overOldPanelOnlyHeight() {
		// Task 61 raises the emoji page by the top-region footprint (+42) vs. its old panel-only height,
		// and that space goes into the panel. Assert it now equals the canonical letters height exactly.
		for showNumber in [true, false] {
			let emoji = KeyboardMetrics.keyboardHeight(for: layout(.emojis, showNumberRow: showNumber))
			let oldPanelOnly = KeyboardMetrics.canonicalHeight(showsNumberRow: showNumber) - KeyboardMetrics.topRegionHeight
			XCTAssertEqual(emoji - oldPanelOnly, KeyboardMetrics.topRegionHeight,
				"Emoji page gains exactly the top-region footprint (number row \(showNumber))")
		}
	}

	// MARK: - Emoji-search

	func testKeyboardHeight_emojiSearchWithNumberRow_matchesCanonical() {
		// Number row ON gives the chrome enough headroom (90 ≥ 86 floor) to expand so emoji-search sits
		// at exactly the canonical height — the old 4pt drift vs. letters disappears.
		for page: KeyboardPage in [.emojiSearch, .emojiSearchSymbols(.primary)] {
			let search = KeyboardMetrics.keyboardHeight(for: layout(page, showNumberRow: true))
			XCTAssertEqual(search, KeyboardMetrics.canonicalHeight(showsNumberRow: true),
				"emoji-search must match the canonical height when the number row is on (\(page))")
		}
	}

	func testKeyboardHeight_emojiSearchWithoutNumberRow_floorsAtMinChrome_andIsTaller() {
		// Number row OFF leaves only 42pt above the rows — less than the irreducible 86pt chrome — so the
		// chrome floors at its minimum and emoji-search is the one page allowed to be taller than letters.
		let search = KeyboardMetrics.keyboardHeight(for: layout(.emojiSearch, showNumberRow: false))
		let expected = KeyboardMetrics.qwertyRowsHeight + KeyboardMetrics.emojiSearchMinChrome
		XCTAssertEqual(search, expected)
		XCTAssertGreaterThan(search, KeyboardMetrics.canonicalHeight(showsNumberRow: false),
			"With no number row, emoji-search exceeds letters by the chrome's irreducible minimum")
	}

	func testKeyboardHeight_emojiSearchChrome_neverShrinksBelowFloor() {
		// Whatever the number-row state, the derived chrome is at least the floor — never clipped short.
		for showNumber in [true, false] {
			let search = KeyboardMetrics.keyboardHeight(for: layout(.emojiSearch, showNumberRow: showNumber))
			let chrome = search - KeyboardMetrics.qwertyRowsHeight
			XCTAssertGreaterThanOrEqual(chrome, KeyboardMetrics.emojiSearchMinChrome)
		}
	}

	// MARK: - Numeric numpad (task 59)

	func testKeyboardHeight_numericPad_matchesNumberRowlessLetters_regardlessOfPreference() {
		// The numpad always drops the number row (it *is* digits), so its four real rows + the reserved
		// top region equal a number-row-less letters page — whatever `showNumberRow` the caller passes.
		// This is why the host height "resolves itself" with no special-casing in `KeyboardMetrics`.
		let expected = KeyboardMetrics.canonicalHeight(showsNumberRow: false)
		for kind in [NumericKind.integer, .decimal] {
			for showNumber in [true, false] {
				let pad = KeyboardMetrics.keyboardHeight(for: layout(.numeric(kind), showNumberRow: showNumber))
				XCTAssertEqual(pad, expected, "numeric(\(kind)) must match number-row-less letters (showNumberRow=\(showNumber))")
			}
		}
	}

	// MARK: - Decoupling from the suggestion bar (task 61)

	func testKeyboardHeight_isIndependentOfSuggestionFieldState() {
		// The height formula no longer takes a `showsSuggestionBar` flag — there is a single value per
		// (page, number row), so it is by construction the same whether suggestions are enabled, disabled,
		// or the field is ineligible. Pin that there's exactly one height for the canonical letters page.
		for showNumber in [true, false] {
			let letters = layout(.letters(.lower), showNumberRow: showNumber)
			XCTAssertEqual(KeyboardMetrics.keyboardHeight(for: letters), KeyboardMetrics.canonicalHeight(showsNumberRow: showNumber))
		}
	}

	// MARK: - Host == view (anti-drift)

	func testKeyboardHeight_isPureFunctionOfLayout_acrossEveryPageAndNumberRowState() {
		// The host constraint (`desiredKeyboardHeight`) and the SwiftUI frame both call this single
		// function with the same built layout, so equal layouts must yield equal heights — the structural
		// guarantee that replaced the old fragile `showsSuggestionBar` parity. Sweep the full matrix.
		for page in Self.allPages {
			for showNumber in [true, false] {
				let a = KeyboardMetrics.keyboardHeight(for: layout(page, showNumberRow: showNumber))
				let b = KeyboardMetrics.keyboardHeight(for: layout(page, showNumberRow: showNumber))
				XCTAssertEqual(a, b, "Height must be a pure function of the layout (\(page), number row \(showNumber))")
				XCTAssertGreaterThan(a, 0)
			}
		}
	}

	// MARK: - Bottom-up contract

	func testKeyboardHeight_scalesWithCapHeight() {
		// Total height is a pure sum of row slots (+ top region), so it tracks `keyCapHeight` directly:
		// raising the cap raises every standard row slot — and the total — by the same delta per row.
		let letters = layout(.letters(.lower), showNumberRow: false)
		let standardRows = letters.rows.filter { !$0.isNumberRow }.count
		let total = KeyboardMetrics.keyboardHeight(for: letters)
		XCTAssertEqual(
			total,
			CGFloat(standardRows) * (KeyboardMetrics.keyCapHeight + KeyboardMetrics.rowGap) + KeyboardMetrics.topRegionHeight
		)
	}
}
