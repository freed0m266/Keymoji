import XCTest
import KeymojiCore
@testable import KeyboardCore

final class LayoutBuilderTests: XCTestCase {

	// MARK: - Row counts

	func testLettersLower_withNumberRow_hasFiveRows() {
		let layout = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
		XCTAssertEqual(layout.rows.count, 5)
	}

	func testLettersLower_withoutNumberRow_hasFourRows() {
		let layout = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: false, returnKeyType: .default)
		XCTAssertEqual(layout.rows.count, 4)
	}

	func testSymbolsPrimary_withNumberRow_hasFiveRows() {
		let layout = LayoutBuilder.layout(page: .symbols(.primary), showNumberRow: true, returnKeyType: .default)
		XCTAssertEqual(layout.rows.count, 5)
	}

	func testSymbolsPrimary_withoutNumberRow_hasFourRows() {
		let layout = LayoutBuilder.layout(page: .symbols(.primary), showNumberRow: false, returnKeyType: .default)
		XCTAssertEqual(layout.rows.count, 4)
	}

	func testSymbolsAlternate_withNumberRow_hasFiveRows() {
		let layout = LayoutBuilder.layout(page: .symbols(.alternate), showNumberRow: true, returnKeyType: .default)
		XCTAssertEqual(layout.rows.count, 5)
	}

	/// Explicit invariant from task 15 — the visual height of the keyboard must not change when
	/// the user switches between letters and either symbol page. Any future refactor that
	/// introduces an asymmetry should fail this test.
	func testLayoutHeight_lettersAndSymbolsHaveEqualRowCount() {
		for showNumber in [true, false] {
			let letters = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: showNumber, returnKeyType: .default).rows.count
			let primary = LayoutBuilder.layout(page: .symbols(.primary), showNumberRow: showNumber, returnKeyType: .default).rows.count
			let alternate = LayoutBuilder.layout(page: .symbols(.alternate), showNumberRow: showNumber, returnKeyType: .default).rows.count
			XCTAssertEqual(letters, primary, "letters and primary symbols rows mismatch (numberRow=\(showNumber))")
			XCTAssertEqual(letters, alternate, "letters and alternate symbols rows mismatch (numberRow=\(showNumber))")
		}
	}

	// MARK: - Number row

	func testNumberRow_hasTenDigitKeys() {
		let layout = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
		let numberRow = layout.rows.first { $0.id == "numberRow" }
		XCTAssertNotNil(numberRow)
		XCTAssertEqual(numberRow?.keys.count, 10)
		let primaries = numberRow?.keys.compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(primaries, ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"])
	}

	func testNumberRow_hasNoAlternates() {
		// Task 69 dropped the digit long-press shortcuts (`1→!` … `0→)`): no digit carries alternates.
		let layout = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
		let numberRow = layout.rows.first { $0.id == "numberRow" }!
		for key in numberRow.keys {
			XCTAssertTrue(key.alternates.isEmpty, "digit \(key.id) must have no long-press alternates")
		}
	}

	// MARK: - Letters lower

	func testLettersLower_row1_hasQwertyuiop() {
		let row = letterRow(at: "letters.row1", page: .letters(.lower))
		let chars = row.keys.compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(chars, ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"])
	}

	func testLettersLower_row2_hasAsdfghjkl() {
		let row = letterRow(at: "letters.row2", page: .letters(.lower))
		XCTAssertEqual(row.keys.count, 9)
		let chars = row.keys.compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(chars, ["a", "s", "d", "f", "g", "h", "j", "k", "l"])
	}

	func testLettersLower_row3_hasShiftLettersDelete() {
		let row = letterRow(at: "letters.row3", page: .letters(.lower))
		XCTAssertEqual(row.keys.count, 9)
		XCTAssertEqual(row.keys.first?.action, .shift)
		XCTAssertEqual(row.keys.last?.action, .backspace)
		let middle = row.keys.dropFirst().dropLast().compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(middle, ["z", "x", "c", "v", "b", "n", "m"])
	}

	// MARK: - Letters upper / caps lock

	func testLettersUpper_primaryIsUppercase() {
		let row = letterRow(at: "letters.row1", page: .letters(.upper))
		let chars = row.keys.compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(chars, ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"])
	}

	func testLettersUpper_alternatesAreUppercase() {
		let row = letterRow(at: "letters.row1", page: .letters(.upper))
		let eKey = row.keys.first { $0.id == "letter.e" }
		XCTAssertNotNil(eKey)
		let alternates = eKey?.alternates.compactMap { content -> String? in
			if case .text(let t) = content { return t }
			return nil
		}
		// Accents only (task 69 dropped the base-letter cell), all uppercased when shifted.
		XCTAssertEqual(alternates, ["É", "Ě", "È", "Ê", "Ë", "Ē", "Ė", "Ę"])
	}

	func testLettersCapsLock_primaryIsUppercase() {
		let row = letterRow(at: "letters.row1", page: .letters(.capsLock))
		let chars = row.keys.compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(chars, ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"])
	}

	func testLettersUpper_shiftKeyShowsShiftFill() {
		let row = letterRow(at: "letters.row3", page: .letters(.upper))
		let shiftKey = row.keys.first!
		XCTAssertEqual(shiftKey.primary, .symbol(.shiftFill))
	}

	func testLettersCapsLock_shiftKeyShowsCapsLockFill() {
		let row = letterRow(at: "letters.row3", page: .letters(.capsLock))
		let shiftKey = row.keys.first!
		XCTAssertEqual(shiftKey.primary, .symbol(.capsLockFill))
	}

	// MARK: - Letter alternates (default `.all` set)

	func testLetterE_allSet_hasCzechDiacriticsNoBase() {
		// Task 69: the popover holds accents only — no base-letter cell. The first accent leads.
		let row = letterRow(at: "letters.row1", page: .letters(.lower))
		let eKey = row.keys.first { $0.id == "letter.e" }!
		let alternates = eKey.alternates.compactMap { content -> String? in
			if case .text(let t) = content { return t }
			return nil
		}
		XCTAssertEqual(alternates.first, "é")
		XCTAssertEqual(alternates[safe: 1], "ě")
		XCTAssertFalse(alternates.contains("e"), "base letter must not appear in the popover (task 69)")
	}

	func testLetterB_hasNoAlternates() {
		let row = letterRow(at: "letters.row3", page: .letters(.lower))
		let bKey = row.keys.first { $0.id == "letter.b" }!
		XCTAssertTrue(bKey.alternates.isEmpty)
	}

	func testLetterA_allSet_hasEightAccentsNoBase() {
		// `.all` keeps the legacy 8 accents for `a`; with the base cell dropped (task 69) that's
		// exactly 8 popover cells, the first being the leading accent (not the base `a`).
		let row = letterRow(at: "letters.row2", page: .letters(.lower))
		let aKey = row.keys.first { $0.id == "letter.a" }!
		XCTAssertEqual(aKey.alternates.count, 8)
		XCTAssertEqual(aKey.alternates.first, .text("á"))
	}

	// MARK: - Symbols page primary

	func testSymbolsPrimary_withNumberRow_rowA_hasBracketsAndMath() {
		// Rich config (number row carries the digits): the primary page leads with brackets, as today.
		let row = symbolRow(at: "symbols.primary.rowA", page: .symbols(.primary), showNumberRow: true)
		let chars = row.keys.compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(chars, ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="])
	}

	func testSymbolsPrimary_withoutNumberRow_rowA_hasDigits() {
		// Native config (no number row): digits move to the primary symbol page so they stay typeable —
		// the core bug fix. (`symbolRow` defaults to `showNumberRow: false`.)
		let row = symbolRow(at: "symbols.primary.rowA", page: .symbols(.primary))
		let chars = row.keys.compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(chars, ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"])
	}

	func testSymbolsPrimary_digitsHaveNoAlternates() {
		// The digit row on the symbol page shares `makeDigitKeys()`, so it inherits the task-69
		// removal of digit long-press shortcuts — no key carries an alternate.
		let row = symbolRow(at: "symbols.primary.rowA", page: .symbols(.primary))
		for key in row.keys {
			XCTAssertTrue(key.alternates.isEmpty, "digit \(key.id) must have no long-press alternates")
		}
	}

	func testSymbolsPrimary_digitRow_usesStandardKeyHeight() {
		// The digit row must NOT carry the `"numberRow"` ID — that ID is what drives the shorter
		// number-row cap height (`KeyboardRow.isNumberRow`). A standard `symbols.primary.rowA` ID keeps
		// the digits at the full key height, aligned with the symbol row beneath them.
		let row = symbolRow(at: "symbols.primary.rowA", page: .symbols(.primary))
		XCTAssertEqual(row.id, "symbols.primary.rowA")
		XCTAssertFalse(row.isNumberRow)
	}

	func testSymbolsPrimary_rowB_hasPunctuation() {
		let row = symbolRow(at: "symbols.primary.rowB", page: .symbols(.primary))
		let chars = row.keys.compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(chars, ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""])
	}

	func testSymbolsPrimary_rowC_hasAltTogglePunctAndDelete() {
		let row = symbolRow(at: "symbols.primary.rowC", page: .symbols(.primary))
		XCTAssertEqual(row.keys.first?.primary, .text("#+="))
		XCTAssertEqual(row.keys.first?.action, .switchPage(.symbols(.alternate)))
		XCTAssertEqual(row.keys.last?.action, .backspace)
		let middle = row.keys.dropFirst().dropLast().compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(middle, [".", ",", "?", "!", "'"])
	}

	// MARK: - Symbols page alternate

	func testSymbolsAlternate_withNumberRow_rowA_hasUnderscoresPipesAndCurrency() {
		// Rich config: the alternate (`#+=`) page leads with underscores/pipes/currency, as today.
		let row = symbolRow(at: "symbols.alternate.rowA", page: .symbols(.alternate), showNumberRow: true)
		let chars = row.keys.compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(chars, ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "·"])
	}

	func testSymbolsAlternate_withNumberRow_rowB_hasLegalAndTypography() {
		// Rich config: the legal & typographic glyph row lives on the alternate page row B, as today.
		// (In native config there's no slot for it — covered by the absence in the test below.)
		let row = symbolRow(at: "symbols.alternate.rowB", page: .symbols(.alternate), showNumberRow: true)
		let chars = row.keys.compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(chars, ["°", "§", "¶", "©", "®", "™", "–", "—", "•", "…"])
	}

	func testSymbolsAlternate_withoutNumberRow_hasBracketsThenUnderscores() {
		// Native config: brackets get displaced off the primary page (digits took it), landing on the
		// alternate page row A; row B carries underscores/pipes/currency. The legal/typography glyphs
		// (`° § ¶ …`) have no slot in native config — accepted (task 66 ADR: native iOS drops them too).
		let rowA = symbolRow(at: "symbols.alternate.rowA", page: .symbols(.alternate))
		let rowAChars = rowA.keys.compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(rowAChars, ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="])

		let rowB = symbolRow(at: "symbols.alternate.rowB", page: .symbols(.alternate))
		let rowBChars = rowB.keys.compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(rowBChars, ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "·"])
	}

	func testSymbolsAlternate_rowC_hasPrimaryToggleAndDelete() {
		let row = symbolRow(at: "symbols.alternate.rowC", page: .symbols(.alternate))
		XCTAssertEqual(row.keys.first?.primary, .text("123"))
		XCTAssertEqual(row.keys.first?.action, .switchPage(.symbols(.primary)))
		XCTAssertEqual(row.keys.last?.action, .backspace)
	}

	// MARK: - Bottom row

	func testBottomRow_onLettersPage_hasNumericToggleAndEmojiSwitcher() {
		let layout = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
		let row = layout.rows.last!
		XCTAssertEqual(row.id, "bottomRow")
		XCTAssertEqual(row.keys.count, 5)

		let toggle = row.keys[0]
		XCTAssertEqual(toggle.primary, .text("123"))
		XCTAssertEqual(toggle.action, .switchPage(.symbols(.primary)))

		// Emoji switcher sits left of space and jumps to the emoji page.
		XCTAssertEqual(row.keys[1].primary, .symbol(.smiley))
		XCTAssertEqual(row.keys[1].action, .switchPage(.emojis))
		XCTAssertEqual(row.keys[2].action, .space)
		XCTAssertEqual(row.keys[3].action, .insertText("."))
		XCTAssertEqual(row.keys[4].action, .return)
	}

	func testBottomRow_onSymbolsPrimary_hasABCToggleAndEmojiSwitcher() {
		let layout = LayoutBuilder.layout(page: .symbols(.primary), showNumberRow: true, returnKeyType: .default)
		let row = layout.rows.last!
		XCTAssertEqual(row.keys.count, 5)
		XCTAssertEqual(row.keys[0].primary, .text("ABC"))
		XCTAssertEqual(row.keys[0].action, .switchPage(.letters(.lower)))
		XCTAssertEqual(row.keys[1].action, .switchPage(.emojis))
	}

	func testBottomRow_onSymbolsAlternate_hasABCToggleAndEmojiSwitcher() {
		let layout = LayoutBuilder.layout(page: .symbols(.alternate), showNumberRow: true, returnKeyType: .default)
		let row = layout.rows.last!
		XCTAssertEqual(row.keys.count, 5)
		XCTAssertEqual(row.keys[0].primary, .text("ABC"))
		XCTAssertEqual(row.keys[0].action, .switchPage(.letters(.lower)))
		XCTAssertEqual(row.keys[1].action, .switchPage(.emojis))
	}

	// MARK: - Emoji page

	func testEmojiPage_withoutNumberRow_hasOnlyBottomRow() {
		let layout = LayoutBuilder.layout(page: .emojis, showNumberRow: false, returnKeyType: .default)
		XCTAssertEqual(layout.rows.count, 1)
		XCTAssertEqual(layout.rows.first?.id, "bottomRow")
	}

	func testEmojiPage_dropsNumberRowEvenWhenPreferenceIsTrue() {
		// Digits have no role in the emoji picker, so the number row is skipped here. Overall
		// keyboard height stays consistent across pages because `KeyboardView.keyboardHeight`
		// is driven by `layout.showsNumberRow`, not the row count.
		let layout = LayoutBuilder.layout(page: .emojis, showNumberRow: true, returnKeyType: .default)
		XCTAssertEqual(layout.rows.count, 1)
		XCTAssertEqual(layout.rows.first?.id, "bottomRow")
		XCTAssertTrue(layout.showsNumberRow, "preference should still propagate so height stays at 260")
	}

	func testEmojiPage_bottomRow_hasABCSpaceDelete() {
		let layout = LayoutBuilder.layout(page: .emojis, showNumberRow: false, returnKeyType: .default)
		let row = layout.rows.last!
		XCTAssertEqual(row.keys.count, 3)
		XCTAssertEqual(row.keys[0].primary, .text("ABC"))
		XCTAssertEqual(row.keys[0].action, .switchPage(.letters(.lower)))
		XCTAssertEqual(row.keys[1].action, .space)
		XCTAssertEqual(row.keys[2].action, .backspace)
	}

	// MARK: - Emoji search page

	func testEmojiSearchPage_dropsNumberRowEvenWhenPreferenceIsTrue() {
		// Search bottom row deliberately omits the `123` toggle (task 39 §6) so the user
		// only exits via the `×` chip — surfacing digits via the number row would put the
		// number-row keys back on screen with no way to actually use them.
		let layout = LayoutBuilder.layout(page: .emojiSearch, showNumberRow: true, returnKeyType: .default)
		XCTAssertFalse(layout.rows.contains { $0.id == "numberRow" })
		XCTAssertTrue(layout.showsNumberRow, "preference should still propagate so height stays consistent")
	}

	func testEmojiSearchPage_lettersRowsAreLowercase() {
		// Search mode is case-insensitive; the rows must render lowercase so the visible
		// keys match what's being matched in `EmojiSearchIndex`.
		let layout = LayoutBuilder.layout(page: .emojiSearch, showNumberRow: false, returnKeyType: .default)
		let row1 = layout.rows.first { $0.id == "letters.row1" }!
		let chars = row1.keys.compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(chars, ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"])
	}

	func testEmojiSearchPage_bottomRow_has123ToggleSpaceReturn() {
		// Native iOS emoji-search keyboard parity: 123 toggle on the left, space in the
		// middle, return on the right. No delete here — row 3 already carries delete.
		let layout = LayoutBuilder.layout(page: .emojiSearch, showNumberRow: false, returnKeyType: .default)
		let row = layout.rows.last!
		XCTAssertEqual(row.id, "bottomRow")
		XCTAssertEqual(row.keys.count, 3)
		XCTAssertEqual(row.keys[0].primary, .text("123"))
		XCTAssertEqual(row.keys[0].action, .switchPage(.emojiSearchSymbols(.primary)))
		XCTAssertEqual(row.keys[1].action, .space)
		XCTAssertEqual(row.keys[2].action, .return)
	}

	// MARK: - Emoji search symbols page

	func testEmojiSearchSymbolsPrimary_hasSymbolRows() {
		let layout = LayoutBuilder.layout(page: .emojiSearchSymbols(.primary), showNumberRow: false, returnKeyType: .default)
		let rowA = layout.rows.first { $0.id == "emojiSearchSymbols.primary.rowA" }
		let rowB = layout.rows.first { $0.id == "emojiSearchSymbols.primary.rowB" }
		let rowC = layout.rows.first { $0.id == "emojiSearchSymbols.primary.rowC" }
		XCTAssertNotNil(rowA, "primary rowA missing")
		XCTAssertNotNil(rowB, "primary rowB missing")
		XCTAssertNotNil(rowC, "primary rowC missing")
		// In-row toggle hops between the search-mode symbol sub-pages, NOT to plain `.symbols`.
		XCTAssertEqual(rowC?.keys.first?.action, .switchPage(.emojiSearchSymbols(.alternate)))
	}

	func testEmojiSearchSymbolsPrimary_rowA_hasDigits() {
		// Emoji search always drops the number row, so its primary symbol page is always native config:
		// digits on row A. Regression for the "can't type digits while searching emoji" bug. Passing
		// `showNumberRow: true` proves the preference is irrelevant here — search never shows it anyway.
		let row = symbolRow(at: "emojiSearchSymbols.primary.rowA", page: .emojiSearchSymbols(.primary), showNumberRow: true)
		let chars = row.keys.compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(chars, ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"])
		// And the row must keep its standard ID (not `"numberRow"`) so it renders at full key height.
		XCTAssertFalse(row.isNumberRow)
	}

	func testEmojiSearchSymbolsAlternate_rowCToggle_pointsBackToPrimary() {
		let layout = LayoutBuilder.layout(page: .emojiSearchSymbols(.alternate), showNumberRow: false, returnKeyType: .default)
		let rowC = layout.rows.first { $0.id == "emojiSearchSymbols.alternate.rowC" }
		XCTAssertEqual(rowC?.keys.first?.action, .switchPage(.emojiSearchSymbols(.primary)))
	}

	func testEmojiSearchSymbols_bottomRow_hasABCToggleSpaceReturn() {
		let layout = LayoutBuilder.layout(page: .emojiSearchSymbols(.primary), showNumberRow: false, returnKeyType: .default)
		let row = layout.rows.last!
		XCTAssertEqual(row.id, "bottomRow")
		XCTAssertEqual(row.keys.count, 3)
		XCTAssertEqual(row.keys[0].primary, .text("ABC"))
		XCTAssertEqual(row.keys[0].action, .switchPage(.emojiSearch))
		XCTAssertEqual(row.keys[1].action, .space)
		XCTAssertEqual(row.keys[2].action, .return)
	}

	func testEmojiSearchSymbols_dropsNumberRow() {
		// Same rationale as `.emojiSearch` — search reaches digits via its own `123` toggle.
		let layout = LayoutBuilder.layout(page: .emojiSearchSymbols(.primary), showNumberRow: true, returnKeyType: .default)
		XCTAssertFalse(layout.rows.contains { $0.id == "numberRow" })
	}

	// MARK: - Return key type & equality

	func testReturnKeyType_propagatesIntoLayout() {
		let layout = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: true, returnKeyType: .search)
		XCTAssertEqual(layout.returnKeyType, .search)
	}

	func testLayout_isEquatableForIdenticalInputs() {
		let a = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
		let b = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
		XCTAssertEqual(a, b)
	}

	func testLayout_differsByPage() {
		let a = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
		let b = LayoutBuilder.layout(page: .symbols(.primary), showNumberRow: true, returnKeyType: .default)
		XCTAssertNotEqual(a, b)
	}

	func testLayout_primaryAndAlternateSymbolPages_differ() {
		let a = LayoutBuilder.layout(page: .symbols(.primary), showNumberRow: true, returnKeyType: .default)
		let b = LayoutBuilder.layout(page: .symbols(.alternate), showNumberRow: true, returnKeyType: .default)
		XCTAssertNotEqual(a, b)
	}

	// MARK: - Reference weight (ASDF row width parity)

	func testLettersRow2_hasReferenceWeight10() {
		let row = letterRow(at: "letters.row2", page: .letters(.lower))
		XCTAssertEqual(row.referenceWeight, 10)
	}

	func testLettersRow1_hasNoReferenceWeight() {
		let row = letterRow(at: "letters.row1", page: .letters(.lower))
		XCTAssertNil(row.referenceWeight)
	}

	func testLettersRow3_hasNoReferenceWeight() {
		let row = letterRow(at: "letters.row3", page: .letters(.lower))
		XCTAssertNil(row.referenceWeight)
	}

	func testSymbolsRowC_hasNoReferenceWeight_onBothPages() {
		let primaryRow = symbolRow(at: "symbols.primary.rowC", page: .symbols(.primary))
		let alternateRow = symbolRow(at: "symbols.alternate.rowC", page: .symbols(.alternate))
		// Row C fills the full width proportionally (no `referenceWeight`): the toggle / delete hug the
		// edges and the punctuation cluster is widened to stay centred —
		// 1.3 + 0.2 gap + 5×1.4 + 0.2 gap + 1.3 = 10.0 weight units. The proportional fill is what makes
		// the edges line up with the letter row 3, so there's no reference inset to apply.
		XCTAssertNil(primaryRow.referenceWeight)
		XCTAssertNil(alternateRow.referenceWeight)
	}

	// MARK: - Letter row 3 / symbol row C edge parity (task 55)

	func testLettersRow3_edgeKeysUseSharedWeight_soLettersAlignWithRow2() {
		let row = letterRow(at: "letters.row3", page: .letters(.lower))
		let shift = row.keys.first { $0.action == .shift }!
		let delete = row.keys.first { $0.action == .backspace }!
		// Shift / delete use the shared 1.3 edge weight (not the emoji row's 1.5) so the row totals 10
		// weight units with the 0.2 edge gaps, putting each of the seven letters at W/10 — identical to
		// rows 1 and 2.
		XCTAssertEqual(shift.visualWeight.value, 1.3, accuracy: 0.0001)
		XCTAssertEqual(delete.visualWeight.value, 1.3, accuracy: 0.0001)

		let totalWeight = row.keys.reduce(0.0) {
			$0 + $1.leadingGapWeight + $1.visualWeight.value + $1.trailingGapWeight
		}
		XCTAssertEqual(totalWeight, 10.0, accuracy: 0.0001, "Letter row 3 must sum to 10 so letters render at W/10")

		let letterWeights = row.keys
			.filter { $0.role == .character }
			.map { $0.visualWeight.value }
		XCTAssertEqual(letterWeights, Array(repeating: 1.0, count: 7))
	}

	func testSymbolsRowC_edgeKeysMatchLetterRow3_soEdgesDontJump() {
		// Toggle and delete on the symbol row C share the same 1.3 edge weight as the letter row 3's
		// shift / delete, so the left and right edges don't jump when toggling letters ↔ symbols.
		let row = symbolRow(at: "symbols.primary.rowC", page: .symbols(.primary))
		let toggle = row.keys.first!
		let delete = row.keys.last!
		XCTAssertEqual(toggle.visualWeight.value, 1.3, accuracy: 0.0001)
		XCTAssertEqual(delete.visualWeight.value, 1.3, accuracy: 0.0001)
	}

	func testSymbolsRowC_punctuationClusterMatchesLetterCluster_andRowSumsTo10() {
		let row = symbolRow(at: "symbols.primary.rowC", page: .symbols(.primary))

		// Each punctuation key is wider than a single letter (1.4 vs 1.0)…
		let punctuation = row.keys.filter { $0.role == .character }
		XCTAssertEqual(punctuation.map { $0.visualWeight.value }, Array(repeating: 1.4, count: 5))

		// …but the 5-key punctuation cluster (5×1.4 = 7.0) matches the 7-letter cluster (7×1.0 = 7.0),
		// so the middle of both third rows is exactly the same width.
		let punctClusterWidth = punctuation.reduce(0.0) { $0 + $1.visualWeight.value }
		XCTAssertEqual(punctClusterWidth, 7.0, accuracy: 0.0001)

		// And the whole row sums to 10, matching the letter row 3 so the keyboard width is unchanged.
		let totalWeight = row.keys.reduce(0.0) {
			$0 + $1.leadingGapWeight + $1.visualWeight.value + $1.trailingGapWeight
		}
		XCTAssertEqual(totalWeight, 10.0, accuracy: 0.0001, "Symbol row C must sum to 10, matching letter row 3")
	}

	func testEmojiBottomRow_deleteKeepsWideWeight() {
		// The emoji bottom row has no shift / toggle to align with, so its delete keeps the `.wide` (1.5)
		// weight rather than the narrower shared edge weight used by the letter row 3 / symbol row C.
		let row = bottomRow(page: .emojis)
		let delete = row.keys.first { $0.action == .backspace }!
		XCTAssertEqual(delete.visualWeight.value, 1.5, accuracy: 0.0001)
	}

	// MARK: - QWERTZ letter layout

	func testQwerty_isTheDefaultLetterLayout() {
		// Every other test in this file omits `letterLayout`, relying on the `.qwerty` default —
		// this pins that contract so a default change can't silently flip the whole suite.
		let explicit = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default, letterLayout: .qwerty)
		let defaulted = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
		XCTAssertEqual(explicit, defaulted)
	}

	func testQwertz_row1_hasZBetweenTAndU() {
		let row = letterRow(at: "letters.row1", page: .letters(.lower), letterLayout: .qwertz)
		let chars = row.keys.compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(chars, ["q", "w", "e", "r", "t", "z", "u", "i", "o", "p"])
		XCTAssertFalse(chars.contains("y"), "y must not appear on row 1 in QWERTZ")
	}

	func testQwertz_row3_startsWithY() {
		let row = letterRow(at: "letters.row3", page: .letters(.lower), letterLayout: .qwertz)
		XCTAssertEqual(row.keys.first?.action, .shift)
		XCTAssertEqual(row.keys.last?.action, .backspace)
		let middle = row.keys.dropFirst().dropLast().compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(middle, ["y", "x", "c", "v", "b", "n", "m"])
		XCTAssertFalse(middle.contains("z"), "z must not appear on row 3 in QWERTZ")
	}

	func testQwertzUpper_positionsSwappedAndUppercased() {
		let row1 = letterRow(at: "letters.row1", page: .letters(.upper), letterLayout: .qwertz)
		let row1Chars = row1.keys.compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(row1Chars, ["Q", "W", "E", "R", "T", "Z", "U", "I", "O", "P"])

		let row3 = letterRow(at: "letters.row3", page: .letters(.upper), letterLayout: .qwertz)
		let row3Middle = row3.keys.dropFirst().dropLast().compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(row3Middle, ["Y", "X", "C", "V", "B", "N", "M"])
	}

	func testQwertz_yAndZKeepTheirAccentAlternates() {
		// Alternates are keyed by `Character`, so they travel with the letter regardless of position.
		// Accents only, no base cell (task 69).
		let row1 = letterRow(at: "letters.row1", page: .letters(.lower), letterLayout: .qwertz)
		let zKey = row1.keys.first { $0.id == "letter.z" }!
		let zAlternates = zKey.alternates.compactMap { content -> String? in
			if case .text(let t) = content { return t }
			return nil
		}
		XCTAssertEqual(zAlternates, ["ž", "ź", "ż"])

		let row3 = letterRow(at: "letters.row3", page: .letters(.lower), letterLayout: .qwertz)
		let yKey = row3.keys.first { $0.id == "letter.y" }!
		let yAlternates = yKey.alternates.compactMap { content -> String? in
			if case .text(let t) = content { return t }
			return nil
		}
		XCTAssertEqual(yAlternates, ["ý", "ÿ"])
	}

	func testQwertz_emojiSearchHonorsLetterLayout() {
		// Search mode reuses the letter rows, so it must respect the QWERTZ choice too.
		let layout = LayoutBuilder.layout(page: .emojiSearch, showNumberRow: false, returnKeyType: .default, letterLayout: .qwertz)
		let row1 = layout.rows.first { $0.id == "letters.row1" }!
		let chars = row1.keys.compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(chars, ["q", "w", "e", "r", "t", "z", "u", "i", "o", "p"])
	}

	func testLayout_differsByLetterLayout() {
		let qwerty = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default, letterLayout: .qwerty)
		let qwertz = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default, letterLayout: .qwertz)
		XCTAssertNotEqual(qwerty, qwertz)
	}

	func testLayout_isEquatableForIdenticalLetterLayout() {
		let a = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default, letterLayout: .qwertz)
		let b = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default, letterLayout: .qwertz)
		XCTAssertEqual(a, b)
	}

	// MARK: - Letter alternate sets (task 58)

	func testCzechSet_rKey_hasSingleAccentNoBase() {
		// Single-accent letter: popover is just `[ř]` (task 69 — no base cell). A one-cell popover
		// still shows; releasing without sliding commits `ř`.
		let row = letterRow(at: "letters.row1", page: .letters(.lower), alternateSet: .czech)
		let rKey = row.keys.first { $0.id == "letter.r" }!
		XCTAssertEqual(rKey.alternates, [.text("ř")])
	}

	func testCzechSet_eKey_orderedByFrequency() {
		XCTAssertEqual(alternateTexts("e", page: .letters(.lower), alternateSet: .czech), ["é", "ě"])
	}

	func testCzechSet_letterWithoutDiacritic_hasNoAlternates() {
		// `f` has no Czech accent → empty alternates → no popup at all.
		let row = letterRow(at: "letters.row2", page: .letters(.lower), alternateSet: .czech)
		let fKey = row.keys.first { $0.id == "letter.f" }!
		XCTAssertTrue(fKey.alternates.isEmpty)
	}

	func testGermanSet_excludesEszett() {
		// German set is ä/ö/ü only — `s` carries no ß (avoids the ß→SS uppercasing problem).
		XCTAssertTrue(alternateTexts("s", page: .letters(.lower), alternateSet: .german).isEmpty)
		XCTAssertEqual(alternateTexts("a", page: .letters(.lower), alternateSet: .german), ["ä"])
		XCTAssertEqual(alternateTexts("o", page: .letters(.lower), alternateSet: .german), ["ö"])
	}

	func testShiftedSet_accentsAreUppercased() {
		// Accents are uppercased when shifted; no base cell to uppercase (task 69).
		let row = letterRow(at: "letters.row1", page: .letters(.upper), alternateSet: .czech)
		let rKey = row.keys.first { $0.id == "letter.r" }!
		XCTAssertEqual(rKey.alternates, [.text("Ř")])
	}

	func testAllSet_matchesLegacyAccents() {
		// `.all` keeps the legacy comprehensive accent map, now with no leading base cell (task 69).
		XCTAssertEqual(
			alternateTexts("a", page: .letters(.lower), alternateSet: .all),
			["á", "à", "â", "ä", "ã", "å", "ā", "æ"]
		)
	}

	func testNumberRow_neverHasAlternates() {
		// Digits carry no long-press alternates regardless of the chosen accent set (task 69).
		let layout = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default, alternateSet: .czech)
		let numberRow = layout.rows.first { $0.id == "numberRow" }!
		let oneKey = numberRow.keys.first { $0.id == "number.1" }!
		XCTAssertTrue(oneKey.alternates.isEmpty)
	}

	func testSetSelection_changesLetterAlternates() {
		// The chosen set actually drives the data: `a` differs between Czech (1 accent) and `.all` (8).
		let czech = alternateTexts("a", page: .letters(.lower), alternateSet: .czech)
		let all = alternateTexts("a", page: .letters(.lower), alternateSet: .all)
		XCTAssertEqual(czech, ["á"])
		XCTAssertEqual(all.count, 8)
		XCTAssertNotEqual(czech, all)
	}

	func testDefaultAlternateSet_isAll() {
		// Omitting `alternateSet` must keep the legacy `.all` behavior for previews / other callers.
		let explicit = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: false, returnKeyType: .default, alternateSet: .all)
		let defaulted = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: false, returnKeyType: .default)
		XCTAssertEqual(explicit, defaulted)
	}

	func testLayout_differsByAlternateSet() {
		let czech = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: false, returnKeyType: .default, alternateSet: .czech)
		let all = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: false, returnKeyType: .default, alternateSet: .all)
		XCTAssertNotEqual(czech, all)
	}

	// MARK: - Numeric (numpad, task 59)

	func testNumericInteger_hasFourRows_noNumberRow() {
		let layout = LayoutBuilder.layout(page: .numeric(.integer), showNumberRow: true, returnKeyType: .default)
		XCTAssertEqual(layout.rows.count, 4)
		XCTAssertNil(layout.rows.first { $0.id == "numberRow" }, "numeric page must never include the number row")
		XCTAssertNil(layout.rows.first { $0.id == "bottomRow" }, "numeric page builds its own bottom row, not the shared one")
	}

	func testNumericInteger_gridRowsAreOneTwoThree() {
		let layout = LayoutBuilder.layout(page: .numeric(.integer), showNumberRow: false, returnKeyType: .default)
		XCTAssertEqual(digits(in: layout, rowID: "numeric.row1"), ["1", "2", "3"])
		XCTAssertEqual(digits(in: layout, rowID: "numeric.row2"), ["4", "5", "6"])
		XCTAssertEqual(digits(in: layout, rowID: "numeric.row3"), ["7", "8", "9"])
	}

	func testNumericInteger_digitsAreTextCharacterKeysWithInsertAction() {
		let layout = LayoutBuilder.layout(page: .numeric(.integer), showNumberRow: false, returnKeyType: .default)
		let one = numericRow(in: layout, id: "numeric.row1").keys[0]
		XCTAssertEqual(one.primary, .text("1"))
		XCTAssertEqual(one.action, .insertText("1"))
		XCTAssertEqual(one.role, .character)
	}

	func testNumericInteger_bottomRow_isZeroWithLeadingGapThenDelete() {
		let layout = LayoutBuilder.layout(page: .numeric(.integer), showNumberRow: false, returnKeyType: .default)
		let row4 = numericRow(in: layout, id: "numeric.row4")
		XCTAssertEqual(row4.keys.count, 2)

		let zero = row4.keys[0]
		XCTAssertEqual(zero.primary, .text("0"))
		XCTAssertEqual(zero.action, .insertText("0"))
		// Empty left third keeps `0` centered in the middle column (no separator on the integer pad).
		XCTAssertEqual(zero.leadingGapWeight, 1.0, accuracy: 0.0001)

		let delete = row4.keys[1]
		XCTAssertEqual(delete.action, .backspace)
		XCTAssertEqual(delete.leadingGapWeight, 0.0, accuracy: 0.0001)
	}

	func testNumericDecimal_bottomRow_isSeparatorZeroDelete() {
		let layout = LayoutBuilder.layout(page: .numeric(.decimal), showNumberRow: false, returnKeyType: .default, decimalSeparator: ",")
		let row4 = numericRow(in: layout, id: "numeric.row4")
		XCTAssertEqual(row4.keys.count, 3)

		let separator = row4.keys[0]
		XCTAssertEqual(separator.id, "numeric.separator")
		XCTAssertEqual(separator.primary, .text(","))
		XCTAssertEqual(separator.action, .insertText(","))
		XCTAssertEqual(separator.role, .character)
		// No leading gap on the decimal pad — the separator fills the left column.
		XCTAssertEqual(separator.leadingGapWeight, 0.0, accuracy: 0.0001)

		XCTAssertEqual(row4.keys[1].primary, .text("0"))
		XCTAssertEqual(row4.keys[1].leadingGapWeight, 0.0, accuracy: 0.0001)
		XCTAssertEqual(row4.keys[2].action, .backspace)
	}

	func testNumericDecimal_defaultSeparatorIsDot() {
		let layout = LayoutBuilder.layout(page: .numeric(.decimal), showNumberRow: false, returnKeyType: .default)
		let separator = numericRow(in: layout, id: "numeric.row4").keys[0]
		XCTAssertEqual(separator.primary, .text("."))
		XCTAssertEqual(separator.action, .insertText("."))
	}

	func testNumeric_noKeyHasAlternates() {
		for kind in [NumericKind.integer, .decimal] {
			let layout = LayoutBuilder.layout(page: .numeric(kind), showNumberRow: true, returnKeyType: .default, decimalSeparator: ",")
			for row in layout.rows {
				for key in row.keys {
					XCTAssertTrue(key.alternates.isEmpty, "numeric key \(key.id) must have no long-press alternates")
				}
			}
		}
	}

	func testNumeric_isEquatableForIdenticalInputs_andDiffersByKind() {
		let intA = LayoutBuilder.layout(page: .numeric(.integer), showNumberRow: false, returnKeyType: .default)
		let intB = LayoutBuilder.layout(page: .numeric(.integer), showNumberRow: false, returnKeyType: .default)
		XCTAssertEqual(intA, intB)

		let decimal = LayoutBuilder.layout(page: .numeric(.decimal), showNumberRow: false, returnKeyType: .default)
		XCTAssertNotEqual(intA, decimal)
	}

	// MARK: - Helpers

	private func numericRow(in layout: KeyboardLayout, id: String) -> KeyboardRow {
		layout.rows.first { $0.id == id }!
	}

	/// Digit primaries (as text) for a numpad grid row.
	private func digits(in layout: KeyboardLayout, rowID: String) -> [String] {
		numericRow(in: layout, id: rowID).keys.compactMap { key in
			if case .text(let t) = key.primary { return t }
			return nil
		}
	}

	private func letterRow(
		at id: String,
		page: KeyboardPage,
		letterLayout: LetterLayout = .qwerty,
		alternateSet: LetterAlternateSet = .all
	) -> KeyboardRow {
		let layout = LayoutBuilder.layout(
			page: page,
			showNumberRow: false,
			returnKeyType: .default,
			letterLayout: letterLayout,
			alternateSet: alternateSet
		)
		return layout.rows.first { $0.id == id }!
	}

	/// Text content of a single letter key's alternates, in order. `nil` if the key isn't found.
	private func alternateTexts(_ char: Character, page: KeyboardPage, alternateSet: LetterAlternateSet) -> [String] {
		for rowID in ["letters.row1", "letters.row2", "letters.row3"] {
			let row = letterRow(at: rowID, page: page, alternateSet: alternateSet)
			if let key = row.keys.first(where: { $0.id == "letter.\(char)" }) {
				return key.alternates.compactMap { if case .text(let t) = $0 { return t } else { return nil } }
			}
		}
		return []
	}

	/// `showNumberRow` defaults to `false` (native config — digits on the primary symbol page). Pass
	/// `true` to exercise the rich config (number row present → brackets-first primary page). Task 66
	/// made the symbol-page content depend on this flag, so symbol tests must opt into the config they
	/// mean instead of assuming today's brackets-first layout.
	private func symbolRow(at id: String, page: KeyboardPage, showNumberRow: Bool = false) -> KeyboardRow {
		let layout = LayoutBuilder.layout(page: page, showNumberRow: showNumberRow, returnKeyType: .default)
		return layout.rows.first { $0.id == id }!
	}

	private func bottomRow(page: KeyboardPage) -> KeyboardRow {
		let layout = LayoutBuilder.layout(page: page, showNumberRow: false, returnKeyType: .default)
		return layout.rows.first { $0.id == "bottomRow" }!
	}
}

private extension Array {
	subscript(safe index: Int) -> Element? {
		indices.contains(index) ? self[index] : nil
	}
}
