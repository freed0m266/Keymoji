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

	func testNumberRow_alternatesMatchShiftedSymbols() {
		let layout = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
		let numberRow = layout.rows.first { $0.id == "numberRow" }!
		let alternates = numberRow.keys.compactMap { key -> String? in
			if case .text(let t) = key.alternates.first ?? .text("") { return t }
			return nil
		}
		XCTAssertEqual(alternates, ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")"])
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

	// MARK: - Letter alternates

	func testLetterE_hasCzechDiacriticsFirst() {
		let row = letterRow(at: "letters.row1", page: .letters(.lower))
		let eKey = row.keys.first { $0.id == "letter.e" }!
		let alternates = eKey.alternates.compactMap { content -> String? in
			if case .text(let t) = content { return t }
			return nil
		}
		XCTAssertEqual(alternates.first, "é")
		XCTAssertEqual(alternates[safe: 1], "ě")
	}

	func testLetterB_hasNoAlternates() {
		let row = letterRow(at: "letters.row3", page: .letters(.lower))
		let bKey = row.keys.first { $0.id == "letter.b" }!
		XCTAssertTrue(bKey.alternates.isEmpty)
	}

	func testLetterA_hasEightAlternates() {
		let row = letterRow(at: "letters.row2", page: .letters(.lower))
		let aKey = row.keys.first { $0.id == "letter.a" }!
		XCTAssertEqual(aKey.alternates.count, 8)
	}

	// MARK: - Symbols page primary

	func testSymbolsPrimary_rowA_hasBracketsAndMath() {
		let row = symbolRow(at: "symbols.primary.rowA", page: .symbols(.primary))
		let chars = row.keys.compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(chars, ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="])
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

	func testSymbolsAlternate_rowA_hasUnderscoresPipesAndCurrency() {
		let row = symbolRow(at: "symbols.alternate.rowA", page: .symbols(.alternate))
		let chars = row.keys.compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(chars, ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "·"])
	}

	func testSymbolsAlternate_rowB_hasLegalAndTypography() {
		let row = symbolRow(at: "symbols.alternate.rowB", page: .symbols(.alternate))
		let chars = row.keys.compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(chars, ["°", "§", "¶", "©", "®", "™", "–", "—", "•", "…"])
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
		// 1.5 + 0.3 gap + 5×1.5 + 0.3 gap + 1.5 = 11.1 weight units. It aligns with nothing, so there's
		// no reference inset to apply.
		XCTAssertNil(primaryRow.referenceWeight)
		XCTAssertNil(alternateRow.referenceWeight)
	}

	// MARK: - Letter row 3 width parity (task 52)

	func testLettersRow3_edgeKeysUseNarrowWeight_soLettersAlignWithRow2() {
		let row = letterRow(at: "letters.row3", page: .letters(.lower))
		let shift = row.keys.first { $0.action == .shift }!
		let delete = row.keys.first { $0.action == .backspace }!
		// Shift / delete drop to 1.2 (not the symbol row's 1.5) so the row totals 10 weight units with
		// the 0.3 edge gaps, putting each of the seven letters at W/10 — identical to rows 1 and 2.
		XCTAssertEqual(shift.visualWeight.value, 1.2, accuracy: 0.0001)
		XCTAssertEqual(delete.visualWeight.value, 1.2, accuracy: 0.0001)

		let totalWeight = row.keys.reduce(0.0) {
			$0 + $1.leadingGapWeight + $1.visualWeight.value + $1.trailingGapWeight
		}
		XCTAssertEqual(totalWeight, 10.0, accuracy: 0.0001, "Letter row 3 must sum to 10 so letters render at W/10")

		let letterWeights = row.keys
			.filter { $0.role == .character }
			.map { $0.visualWeight.value }
		XCTAssertEqual(letterWeights, Array(repeating: 1.0, count: 7))
	}

	func testSymbolsRowC_keepsWideEdgeKeys_notTheLetterRowWeight() {
		// The narrower 1.2 edge weight is scoped to the letter row only — the symbol row C toggle and
		// delete keep `.wide` (1.5), since they have nothing to align with.
		let row = symbolRow(at: "symbols.primary.rowC", page: .symbols(.primary))
		let toggle = row.keys.first!
		let delete = row.keys.last!
		XCTAssertEqual(toggle.visualWeight.value, 1.5, accuracy: 0.0001)
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

	// MARK: - Helpers

	private func letterRow(at id: String, page: KeyboardPage, letterLayout: LetterLayout = .qwerty) -> KeyboardRow {
		let layout = LayoutBuilder.layout(page: page, showNumberRow: false, returnKeyType: .default, letterLayout: letterLayout)
		return layout.rows.first { $0.id == id }!
	}

	private func symbolRow(at id: String, page: KeyboardPage) -> KeyboardRow {
		let layout = LayoutBuilder.layout(page: page, showNumberRow: false, returnKeyType: .default)
		return layout.rows.first { $0.id == id }!
	}
}

private extension Array {
	subscript(safe index: Int) -> Element? {
		indices.contains(index) ? self[index] : nil
	}
}
