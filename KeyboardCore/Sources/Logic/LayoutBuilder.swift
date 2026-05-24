import Foundation

/// Pure factory that builds a `KeyboardLayout` from `(page, showNumberRow, returnKeyType)`.
/// All keyboard layout shape decisions live here — view layer just renders the output.
public enum LayoutBuilder {

	public static func layout(
		page: KeyboardPage,
		showNumberRow: Bool,
		returnKeyType: ReturnKeyType
	) -> KeyboardLayout {
		var rows: [KeyboardRow] = []

		if showNumberRow {
			rows.append(makeNumberRow())
		}

		switch page {
		case .letters(let shift):
			rows.append(contentsOf: makeLetterRows(shift: shift))
		case .symbols:
			rows.append(contentsOf: makeSymbolRows())
		}

		rows.append(makeBottomRow(page: page))

		return KeyboardLayout(
			page: page,
			rows: rows,
			showsNumberRow: showNumberRow,
			returnKeyType: returnKeyType
		)
	}

	// MARK: - Number row

	private static let numberRowMapping: [(digit: String, alternate: String)] = [
		("1", "!"), ("2", "@"), ("3", "#"), ("4", "$"), ("5", "%"),
		("6", "^"), ("7", "&"), ("8", "*"), ("9", "("), ("0", ")")
	]

	private static func makeNumberRow() -> KeyboardRow {
		let keys = numberRowMapping.map { entry in
			Key(
				id: "number.\(entry.digit)",
				primary: .text(entry.digit),
				alternates: [.text(entry.alternate)],
				action: .insertText(entry.digit),
				visualWeight: .standard,
				role: .character
			)
		}
		return KeyboardRow(id: "numberRow", keys: keys)
	}

	// MARK: - Letters

	/// Long-press accent variants per base letter. Czech diacritics first, then common Western European.
	/// Lowercase form here; uppercase variants are derived via `String.uppercased(with:)`.
	private static let letterAlternates: [Character: [String]] = [
		"a": ["á", "à", "â", "ä", "ã", "å", "ā", "æ"],
		"c": ["č", "ç", "ć", "ĉ"],
		"d": ["ď"],
		"e": ["é", "ě", "è", "ê", "ë", "ē", "ė", "ę"],
		"i": ["í", "ì", "î", "ï", "ī", "į"],
		"l": ["ł"],
		"n": ["ñ", "ň"],
		"o": ["ó", "ò", "ô", "ö", "õ", "ø", "ō", "œ"],
		"r": ["ř"],
		"s": ["š", "ś", "ŝ"],
		"t": ["ť"],
		"u": ["ú", "ù", "û", "ü", "ū", "ů"],
		"y": ["ý", "ÿ"],
		"z": ["ž", "ź", "ż"]
	]

	private static let letterRow1: [Character] = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
	private static let letterRow2: [Character] = ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
	private static let letterRow3Letters: [Character] = ["z", "x", "c", "v", "b", "n", "m"]

	private static func makeLetterRows(shift: ShiftState) -> [KeyboardRow] {
		let row1 = KeyboardRow(
			id: "letters.row1",
			keys: letterRow1.map { makeLetterKey($0, shift: shift) }
		)
		// Row 2 has 9 letters (asdf…l). To keep each key the same width as row 1's 10 keys,
		// we reserve half-a-key of inset on each side via `referenceWeight: 10`.
		let row2 = KeyboardRow(
			id: "letters.row2",
			keys: letterRow2.map { makeLetterKey($0, shift: shift) },
			referenceWeight: 10
		)
		let row3Letters = letterRow3Letters.map { makeLetterKey($0, shift: shift) }
		let row3 = KeyboardRow(
			id: "letters.row3",
			keys: [makeShiftKey(shift: shift)] + row3Letters + [makeDeleteKey()]
		)
		return [row1, row2, row3]
	}

	private static func makeLetterKey(_ char: Character, shift: ShiftState) -> Key {
		let lower = String(char)
		let displayed = shouldUppercase(shift) ? lower.posixUppercased() : lower
		let rawAlternates = letterAlternates[char] ?? []
		let alternates = rawAlternates.map { alt -> KeyContent in
			.text(shouldUppercase(shift) ? alt.posixUppercased() : alt)
		}
		return Key(
			id: "letter.\(lower)",
			primary: .text(displayed),
			alternates: alternates,
			action: .insertText(displayed),
			visualWeight: .standard,
			role: .character
		)
	}

	private static func shouldUppercase(_ shift: ShiftState) -> Bool {
		switch shift {
		case .lower:                return false
		case .upper, .capsLock:     return true
		}
	}

	// MARK: - Symbols

	private static let symbolRow2: [String] = ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]
	private static let symbolRow3: [String] = [".", ",", "?", "!", "'"]

	private static func makeSymbolRows() -> [KeyboardRow] {
		let row2 = KeyboardRow(
			id: "symbols.row2",
			keys: symbolRow2.map(makeSymbolKey)
		)
		let abcToggle = Key(
			id: "symbols.row3.toggleABC",
			primary: .text("ABC"),
			alternates: [],
			action: .switchPage(.letters(.lower)),
			visualWeight: .wide,
			role: .system
		)
		let row3Symbols = symbolRow3.map(makeSymbolKey)
		let row3 = KeyboardRow(
			id: "symbols.row3",
			keys: [abcToggle] + row3Symbols + [makeDeleteKey()]
		)
		return [row2, row3]
	}

	private static func makeSymbolKey(_ symbol: String) -> Key {
		Key(
			id: "sym.\(symbol)",
			primary: .text(symbol),
			alternates: [],
			action: .insertText(symbol),
			visualWeight: .standard,
			role: .character
		)
	}

	// MARK: - Shared keys

	private static func makeShiftKey(shift: ShiftState) -> Key {
		let symbol: SystemSymbol
		switch shift {
		case .lower:        symbol = .shift
		case .upper:        symbol = .shiftFill
		case .capsLock:     symbol = .capsLockFill
		}
		return Key(
			id: "shift",
			primary: .symbol(symbol),
			alternates: [],
			action: .shift,
			visualWeight: .wide,
			role: .system
		)
	}

	private static func makeDeleteKey() -> Key {
		Key(
			id: "delete",
			primary: .symbol(.delete),
			alternates: [],
			action: .backspace,
			visualWeight: .wide,
			role: .system
		)
	}

	// MARK: - Bottom row

	private static func makeBottomRow(page: KeyboardPage) -> KeyboardRow {
		let toggle: Key
		switch page {
		case .letters:
			toggle = Key(
				id: "bottom.pageToggle",
				primary: .text("123"),
				alternates: [],
				action: .switchPage(.symbols),
				visualWeight: .small,
				role: .system
			)
		case .symbols:
			toggle = Key(
				id: "bottom.pageToggle",
				primary: .text("ABC"),
				alternates: [],
				action: .switchPage(.letters(.lower)),
				visualWeight: .small,
				role: .system
			)
		}

		let globe = Key(
			id: "globe",
			primary: .symbol(.globe),
			alternates: [],
			action: .nextKeyboard,
			visualWeight: .small,
			role: .system
		)
		let space = Key(
			id: "space",
			primary: .text("space"),
			alternates: [],
			action: .space,
			visualWeight: .space,
			role: .system
		)
		let dot = Key(
			id: "dot",
			primary: .text("."),
			alternates: [],
			action: .insertText("."),
			visualWeight: .dotKey,
			role: .system
		)
		let returnKey = Key(
			id: "return",
			primary: .symbol(.return),
			alternates: [],
			action: .return,
			visualWeight: .returnKey,
			role: .system
		)

		return KeyboardRow(
			id: "bottomRow",
			keys: [toggle, globe, space, dot, returnKey]
		)
	}
}

private extension String {
	/// POSIX-locale uppercase to avoid Turkish-style `i → İ` for non-Turkish targets.
	func posixUppercased() -> String {
		self.uppercased(with: Locale(identifier: "en_US_POSIX"))
	}
}
