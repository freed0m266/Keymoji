import XCTest
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

	func testSymbols_withNumberRow_hasFourRows() {
		let layout = LayoutBuilder.layout(page: .symbols, showNumberRow: true, returnKeyType: .default)
		XCTAssertEqual(layout.rows.count, 4)
	}

	func testSymbols_withoutNumberRow_hasThreeRows() {
		let layout = LayoutBuilder.layout(page: .symbols, showNumberRow: false, returnKeyType: .default)
		XCTAssertEqual(layout.rows.count, 3)
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

	// MARK: - Symbols page

	func testSymbolsRow2_hasExpectedCharacters() {
		let layout = LayoutBuilder.layout(page: .symbols, showNumberRow: true, returnKeyType: .default)
		let row = layout.rows.first { $0.id == "symbols.row2" }!
		let chars = row.keys.compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(chars, ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""])
	}

	func testSymbolsRow3_hasABCTogglePunctuationDelete() {
		let layout = LayoutBuilder.layout(page: .symbols, showNumberRow: true, returnKeyType: .default)
		let row = layout.rows.first { $0.id == "symbols.row3" }!
		XCTAssertEqual(row.keys.first?.action, .switchPage(.letters(.lower)))
		XCTAssertEqual(row.keys.last?.action, .backspace)
		let middle = row.keys.dropFirst().dropLast().compactMap { key -> String? in
			if case .text(let t) = key.primary { return t }
			return nil
		}
		XCTAssertEqual(middle, [".", ",", "?", "!", "'"])
	}

	// MARK: - Bottom row

	func testBottomRow_onLettersPage_hasNumericToggle() {
		let layout = LayoutBuilder.layout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default)
		let row = layout.rows.last!
		XCTAssertEqual(row.id, "bottomRow")
		XCTAssertEqual(row.keys.count, 5)

		let toggle = row.keys[0]
		XCTAssertEqual(toggle.primary, .text("123"))
		XCTAssertEqual(toggle.action, .switchPage(.symbols))

		XCTAssertEqual(row.keys[1].action, .nextKeyboard)
		XCTAssertEqual(row.keys[2].action, .space)
		XCTAssertEqual(row.keys[3].action, .insertText("."))
		XCTAssertEqual(row.keys[4].action, .return)
	}

	func testBottomRow_onSymbolsPage_hasABCToggle() {
		let layout = LayoutBuilder.layout(page: .symbols, showNumberRow: true, returnKeyType: .default)
		let row = layout.rows.last!
		XCTAssertEqual(row.keys[0].primary, .text("ABC"))
		XCTAssertEqual(row.keys[0].action, .switchPage(.letters(.lower)))
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
		let b = LayoutBuilder.layout(page: .symbols, showNumberRow: true, returnKeyType: .default)
		XCTAssertNotEqual(a, b)
	}

	// MARK: - Helpers

	private func letterRow(at id: String, page: KeyboardPage) -> KeyboardRow {
		let layout = LayoutBuilder.layout(page: page, showNumberRow: false, returnKeyType: .default)
		return layout.rows.first { $0.id == id }!
	}
}

private extension Array {
	subscript(safe index: Int) -> Element? {
		indices.contains(index) ? self[index] : nil
	}
}
