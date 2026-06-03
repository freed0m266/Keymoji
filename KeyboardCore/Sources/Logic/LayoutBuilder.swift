import Foundation
import KeymojiCore

/// Pure factory that builds a `KeyboardLayout` from `(page, showNumberRow, returnKeyType, letterLayout)`.
/// All keyboard layout shape decisions live here — view layer just renders the output.
public enum LayoutBuilder {

	public static func layout(
		page: KeyboardPage,
		showNumberRow: Bool,
		returnKeyType: ReturnKeyType,
		letterLayout: LetterLayout = .qwerty
	) -> KeyboardLayout {
		var rows: [KeyboardRow] = []

		// The emoji pages skip the number row entirely — digits would crowd the picker and
		// the search results bar. Search mode reaches digits via its own bottom-row `123`
		// toggle (which jumps into `.emojiSearchSymbols`), not via the number row.
		// `KeyboardLayout.showsNumberRow` still propagates the user's preference so the
		// *overall* keyboard height (260 vs 216) stays consistent when toggling between pages.
		let includeNumberRow = showNumberRow && page != .emojis && !page.isEmojiSearch
		if includeNumberRow {
			rows.append(makeNumberRow())
		}

		switch page {
		case .letters(let shift):
			rows.append(contentsOf: makeLetterRows(shift: shift, letterLayout: letterLayout))
		case .symbols(let symbolPage):
			rows.append(contentsOf: makeSymbolRows(symbolPage, inEmojiSearch: false))
		case .emojis:
			// Emoji page renders an `EmojiPanelView` in place of the letter/symbol rows.
			// No row keys here — only the page-specific bottom row appears below.
			break
		case .emojiSearch:
			// Search mode: full QWERTY/QWERTZ for typing the query. Always lowercase — query is
			// case-insensitive at match time, so a Shift key would only add noise. Honors the
			// user's letter-layout choice so the search keyboard matches the typing keyboard.
			rows.append(contentsOf: makeLetterRows(shift: .lower, letterLayout: letterLayout))
		case .emojiSearchSymbols(let symbolPage):
			// Symbols variant of search mode — same row content as the regular `.symbols`
			// layout, but the in-row `#+=` / `123` toggle keeps the user in the search-mode
			// symbol pages instead of escaping back to plain symbols.
			rows.append(contentsOf: makeSymbolRows(symbolPage, inEmojiSearch: true))
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

	// Row 1 and row 3 differ between QWERTY and QWERTZ only in the position of Y and Z;
	// row 2 is identical across variants. The inserted characters and per-letter accent
	// alternates travel with the letter (keyed by `Character`), so only the order changes.
	private static func letterRow1(_ layout: LetterLayout) -> [Character] {
		switch layout {
		case .qwerty: return ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
		case .qwertz: return ["q", "w", "e", "r", "t", "z", "u", "i", "o", "p"]
		}
	}

	private static let letterRow2: [Character] = ["a", "s", "d", "f", "g", "h", "j", "k", "l"]

	private static func letterRow3Letters(_ layout: LetterLayout) -> [Character] {
		switch layout {
		case .qwerty: return ["z", "x", "c", "v", "b", "n", "m"]
		case .qwertz: return ["y", "x", "c", "v", "b", "n", "m"]
		}
	}

	private static func makeLetterRows(shift: ShiftState, letterLayout: LetterLayout) -> [KeyboardRow] {
		let row1 = KeyboardRow(
			id: "letters.row1",
			keys: letterRow1(letterLayout).map { makeLetterKey($0, shift: shift) }
		)
		// Row 2 has 9 letters (asdf…l). To keep each key the same width as row 1's 10 keys,
		// we reserve half-a-key of inset on each side via `referenceWeight: 10`.
		let row2 = KeyboardRow(
			id: "letters.row2",
			keys: letterRow2.map { makeLetterKey($0, shift: shift) },
			referenceWeight: 10
		)
		let row3Letters = letterRow3Letters(letterLayout).map { makeLetterKey($0, shift: shift) }
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

	/// Symbols page primary content (matches SwiftKey/Apple parity):
	///   Row A: bracket / math operator row — `[ ] { } # % ^ * + =`
	///   Row B: punctuation / common symbols — `- / : ; ( ) $ & @ "`
	///   Row C: `[#+=]` toggle + .,?!' + delete (8 visual slots, weight-balanced to 10)
	private static let symbolsPrimaryRowA: [String] = ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="]
	private static let symbolsPrimaryRowB: [String] = ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]

	/// Symbols page alternate (`#+=`) content:
	///   Row A: underscore / pipes / comparisons / currency — `_ \ | ~ < > € £ ¥ ·`
	///   Row B: legal & typographic punctuation — `° § ¶ © ® ™ – — • …`
	///   Row C: `[123]` toggle + .,?!' + delete
	private static let symbolsAlternateRowA: [String] = ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "·"]
	private static let symbolsAlternateRowB: [String] = ["°", "§", "¶", "©", "®", "™", "–", "—", "•", "…"]

	/// Punctuation row C (shared between primary and alternate).
	private static let symbolsRowCPunctuation: [String] = [".", ",", "?", "!", "'"]

	/// Breathing room (≈ a third of a key) between the edge-hugging toggle / delete keys and the
	/// punctuation cluster, mirroring the native symbols keyboard.
	private static let symbolEdgeGapWeight: Double = 0.3

	/// Punctuation keys in row C render wider than a standard key — the space freed up by pinning
	/// toggle / delete to the edges is handed to them. See `makeSymbolRows` for the budget.
	private static let symbolRowCPunctuationWeight = KeyWeight(1.5)

	private static func makeSymbolRows(_ page: SymbolPage, inEmojiSearch: Bool) -> [KeyboardRow] {
		let (rowAContent, rowBContent, rowCToggle) = symbolPageContent(page, inEmojiSearch: inEmojiSearch)
		let idPrefix = inEmojiSearch ? "emojiSearchSymbols" : "symbols"

		let rowA = KeyboardRow(
			id: "\(idPrefix).\(page.id).rowA",
			keys: rowAContent.map(makeSymbolKey)
		)
		let rowB = KeyboardRow(
			id: "\(idPrefix).\(page.id).rowB",
			keys: rowBContent.map(makeSymbolKey)
		)
		let rowCPunctuation = symbolsRowCPunctuation.map(makeSymbolPunctuationKey)
		// Native parity: the toggle hugs the left edge and delete the right edge, each separated from
		// the punctuation cluster by a sliver of breathing room. No `referenceWeight` — the row fills
		// the full width proportionally, with the punctuation keys widened so the cluster stays
		// centered between the edge keys:
		//   1.5 (toggle) + 0.3 gap + 5×1.5 (punctuation) + 0.3 gap + 1.5 (delete) = 11.1 weight units.
		let rowC = KeyboardRow(
			id: "\(idPrefix).\(page.id).rowC",
			keys: [rowCToggle.addingGaps(trailing: symbolEdgeGapWeight)]
				+ rowCPunctuation
				+ [makeDeleteKey().addingGaps(leading: symbolEdgeGapWeight)]
		)
		return [rowA, rowB, rowC]
	}

	/// In-row `#+=` / `123` toggle. When `inEmojiSearch` is true, the toggle hops between the
	/// `.emojiSearchSymbols` sub-pages so the user stays in the search context; otherwise it
	/// flips between the regular `.symbols` sub-pages.
	private static func symbolPageContent(
		_ page: SymbolPage,
		inEmojiSearch: Bool
	) -> (rowA: [String], rowB: [String], rowCToggle: Key) {
		switch page {
		case .primary:
			let target: KeyboardPage = inEmojiSearch ? .emojiSearchSymbols(.alternate) : .symbols(.alternate)
			let toggle = Key(
				id: "symbols.row3.toggleAlt",
				primary: .text("#+="),
				alternates: [],
				action: .switchPage(target),
				visualWeight: .wide,
				role: .system
			)
			return (symbolsPrimaryRowA, symbolsPrimaryRowB, toggle)

		case .alternate:
			let target: KeyboardPage = inEmojiSearch ? .emojiSearchSymbols(.primary) : .symbols(.primary)
			let toggle = Key(
				id: "symbols.row3.togglePrimary",
				primary: .text("123"),
				alternates: [],
				action: .switchPage(target),
				visualWeight: .wide,
				role: .system
			)
			return (symbolsAlternateRowA, symbolsAlternateRowB, toggle)
		}
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

	/// Row C punctuation key — identical to `makeSymbolKey` but carries the wider row-C weight.
	private static func makeSymbolPunctuationKey(_ symbol: String) -> Key {
		Key(
			id: "sym.\(symbol)",
			primary: .text(symbol),
			alternates: [],
			action: .insertText(symbol),
			visualWeight: symbolRowCPunctuationWeight,
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
		switch page {
		case .letters, .symbols:
			return makeStandardBottomRow(page: page)
		case .emojis:
			return makeEmojiBottomRow()
		case .emojiSearch, .emojiSearchSymbols:
			return makeEmojiSearchBottomRow(page: page)
		}
	}

	private static func makeStandardBottomRow(page: KeyboardPage) -> KeyboardRow {
		let toggle: Key
		switch page {
		case .letters:
			toggle = Key(
				id: "bottom.pageToggle",
				primary: .text("123"),
				alternates: [],
				action: .switchPage(.symbols(.primary)),
				visualWeight: .small,
				role: .system
			)
		case .symbols:
			// Both symbol pages route back to letters from the bottom row — the in-row `[#+=]` /
			// `[123]` toggle is what hops between the two symbol pages.
			toggle = Key(
				id: "bottom.pageToggle",
				primary: .text("ABC"),
				alternates: [],
				action: .switchPage(.letters(.lower)),
				visualWeight: .small,
				role: .system
			)
		case .emojis, .emojiSearch, .emojiSearchSymbols:
			// Unreachable — emoji pages are handled by their own bottom-row builders.
			fatalError("emoji page should not reach makeStandardBottomRow")
		}

		// Slot for jumping to the emoji panel — tapping it pushes the page state to `.emojis`.
		let emoji = Key(
			id: "bottom.emojiSwitcher",
			primary: .symbol(.smiley),
			alternates: [],
			action: .switchPage(.emojis),
			visualWeight: .small,
			role: .system
		)
		let space = Key(
			id: "space",
			primary: .text(""),
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
			keys: [toggle, emoji, space, dot, returnKey]
		)
	}

	/// Bottom row shown while on the emoji page. ABC jumps back to letters; space + delete behave
	/// as on the regular pages. No `.` or page-toggle — emoji input has different ergonomics.
	private static func makeEmojiBottomRow() -> KeyboardRow {
		let abc = Key(
			id: "bottom.pageToggle",
			primary: .text("ABC"),
			alternates: [],
			action: .switchPage(.letters(.lower)),
			visualWeight: .small,
			role: .system
		)
		let space = Key(
			id: "space",
			primary: .text(""),
			alternates: [],
			action: .space,
			visualWeight: .space,
			role: .system
		)
		let delete = makeDeleteKey()
		return KeyboardRow(
			id: "bottomRow",
			keys: [abc, space, delete]
		)
	}

	/// Bottom row shown while typing into the emoji search query. Mirrors the native iOS
	/// emoji-search keyboard: `123` / `ABC` toggle on the left jumps between the QWERTY
	/// sub-page and the symbols sub-page, space in the middle, return on the right. There
	/// is no delete key here — row 3 already carries delete in both layouts. Exit out of
	/// search mode is via the `×` in the search bar above the keyboard.
	private static func makeEmojiSearchBottomRow(page: KeyboardPage) -> KeyboardRow {
		let toggle: Key
		switch page {
		case .emojiSearch:
			toggle = Key(
				id: "bottom.pageToggle",
				primary: .text("123"),
				alternates: [],
				action: .switchPage(.emojiSearchSymbols(.primary)),
				visualWeight: .small,
				role: .system
			)
		case .emojiSearchSymbols:
			toggle = Key(
				id: "bottom.pageToggle",
				primary: .text("ABC"),
				alternates: [],
				action: .switchPage(.emojiSearch),
				visualWeight: .small,
				role: .system
			)
		case .letters, .symbols, .emojis:
			// Unreachable — `makeBottomRow` only routes the two emoji-search variants here.
			fatalError("non-search page should not reach makeEmojiSearchBottomRow")
		}

		let space = Key(
			id: "space",
			primary: .text(""),
			alternates: [],
			action: .space,
			visualWeight: .space,
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
			keys: [toggle, space, returnKey]
		)
	}
}

private extension String {
	/// POSIX-locale uppercase to avoid Turkish-style `i → İ` for non-Turkish targets.
	func posixUppercased() -> String {
		uppercased(with: Locale(identifier: "en_US_POSIX"))
	}
}

private extension SymbolPage {
	/// Slug used inside row IDs so SwiftUI can tell primary and alternate rows apart.
	var id: String {
		switch self {
		case .primary:    return "primary"
		case .alternate:  return "alternate"
		}
	}
}
