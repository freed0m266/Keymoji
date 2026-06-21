import Foundation
import KeymojiCore

/// Pure factory that builds a `KeyboardLayout` from `(page, showNumberRow, returnKeyType, letterLayout)`.
/// All keyboard layout shape decisions live here — view layer just renders the output.
public enum LayoutBuilder {

	public static func layout(
		page: KeyboardPage,
		showNumberRow: Bool,
		returnKeyType: ReturnKeyType,
		letterLayout: LetterLayout = .qwerty,
		alternateSet: LetterAlternateSet = .all,
		decimalSeparator: String = "."
	) -> KeyboardLayout {
		var rows: [KeyboardRow] = []

		// The emoji pages skip the number row entirely — digits would crowd the picker and
		// the search results bar. Search mode reaches digits via its own bottom-row `123`
		// toggle (which jumps into `.emojiSearchSymbols`), not via the number row.
		// `KeyboardLayout.showsNumberRow` still propagates `showNumberRow` so the *overall*
		// keyboard height (260 vs 216) stays consistent when toggling between pages. Note this
		// builder is pure and orientation-unaware: callers pass the *effective* value
		// (`KeyboardState.effectiveShowsNumberRow`, already false in landscape), not the raw
		// user preference — so landscape gets the shorter, number-row-less layout for free.
		// Numeric pages drop the number row too: the numpad already *is* digits, and its host height
		// is derived from the four real rows below — adding a number row on top would desync the host
		// constraint from the visible content (the classic drift bug). See `KeyboardMetrics`.
		let includeNumberRow = showNumberRow && page != .emojis && !page.isEmojiSearch && !page.isNumeric
		if includeNumberRow {
			rows.append(makeNumberRow())
		}

		switch page {
		case .letters(let shift):
			rows.append(contentsOf: makeLetterRows(shift: shift, letterLayout: letterLayout, alternateSet: alternateSet))
		case .symbols(let symbolPage):
			rows.append(contentsOf: makeSymbolRows(symbolPage, inEmojiSearch: false, includeDigits: !includeNumberRow))
		case .emojis:
			// Emoji page renders an `EmojiPanelView` in place of the letter/symbol rows.
			// No row keys here — only the page-specific bottom row appears below.
			break
		case .emojiSearch:
			// Search mode: full QWERTY/QWERTZ for typing the query. Always lowercase — query is
			// case-insensitive at match time, so a Shift key would only add noise. Honors the
			// user's letter-layout choice so the search keyboard matches the typing keyboard.
			rows.append(contentsOf: makeLetterRows(shift: .lower, letterLayout: letterLayout, alternateSet: alternateSet))
		case .emojiSearchSymbols(let symbolPage):
			// Symbols variant of search mode — same row content as the regular `.symbols`
			// layout, but the in-row `#+=` / `123` toggle keeps the user in the search-mode
			// symbol pages instead of escaping back to plain symbols. The number row is always
			// dropped here (`includeNumberRow` is false on every search page), so `includeDigits`
			// is always true → digits ride the primary symbol page, the only place to reach them.
			rows.append(contentsOf: makeSymbolRows(symbolPage, inEmojiSearch: true, includeDigits: !includeNumberRow))
		case .numeric(let kind):
			// The numpad builds all four of its own rows (digits + a custom bottom row with the
			// separator/delete), so it skips both the number row above and `makeBottomRow` below.
			rows.append(contentsOf: makeNumericRows(kind: kind, decimalSeparator: decimalSeparator))
		}

		// The numpad owns its bottom row (`makeNumericRows`); every other page gets the shared one.
		if !page.isNumeric {
			rows.append(makeBottomRow(page: page))
		}

		return KeyboardLayout(
			page: page,
			rows: rows,
			showsNumberRow: showNumberRow,
			returnKeyType: returnKeyType
		)
	}

	// MARK: - Number row

	private static let digitTitles = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

	/// The ten digit keys, shared between the number row (letters page) and the primary symbol page
	/// in native config. No long-press alternates (task 69 dropped the old `1→!` … `0→)` shortcuts —
	/// the symbols page is the discoverable home for those glyphs, and a hidden digit popover only
	/// confused beta testers). Uses the `.standard` visual weight (10 keys = full row width, no
	/// `referenceWeight`).
	///
	/// The key IDs (`number.1` … `number.0`) are shared too — that's safe because the number row and
	/// the symbol page are mutually exclusive on screen (the symbol page only carries digits when the
	/// number row is absent), so there's never a duplicate-ID collision in a single layout. What must
	/// NOT be shared is the *row* ID: `makeNumberRow` wraps these in `"numberRow"` (height 36 via
	/// `KeyboardRow.isNumberRow`), while the symbol page wraps them in a standard `symbols.*.rowA` ID
	/// (height 42) so the digits line up with the symbol row beneath them.
	private static func makeDigitKeys() -> [Key] {
		digitTitles.map { digit in
			Key(
				id: "number.\(digit)",
				primary: .text(digit),
				alternates: [],
				action: .insertText(digit),
				visualWeight: .standard,
				role: .character
			)
		}
	}

	private static func makeNumberRow() -> KeyboardRow {
		KeyboardRow(id: "numberRow", keys: makeDigitKeys())
	}

	// MARK: - Numeric (numpad)

	/// Builds the four-row Apple-style numpad (task 59). Rows 1–3 are the `1-2-3 / 4-5-6 / 7-8-9`
	/// grid; row 4 carries `0` plus delete, with the bottom-left slot either empty (`.integer`) or
	/// the locale decimal separator (`.decimal`).
	///
	/// Digits are plain `.text` keys with `role: .character`, so they inherit tap dispatch
	/// (`.insertText`), haptics, click sound, and key-preview from `KeyView` for free, and render
	/// with the flat (non-letter) baseline `KeyView` already applies to non-lowercase glyphs. No
	/// alternates → no long-press popup, matching the locked native numberPad.
	private static func makeNumericRows(kind: NumericKind, decimalSeparator: String) -> [KeyboardRow] {
		func digit(_ d: String) -> Key {
			Key(
				id: "numeric.\(d)",
				primary: .text(d),
				alternates: [],
				action: .insertText(d),
				visualWeight: .standard,
				role: .character
			)
		}
		let row1 = KeyboardRow(id: "numeric.row1", keys: ["1", "2", "3"].map(digit))
		let row2 = KeyboardRow(id: "numeric.row2", keys: ["4", "5", "6"].map(digit))
		let row3 = KeyboardRow(id: "numeric.row3", keys: ["7", "8", "9"].map(digit))

		let zero = digit("0")
		let delete = makeDeleteKey(weight: .standard)
		let bottomKeys: [Key]
		switch kind {
		case .integer:
			// Empty left third (a leading gap on `0`, reusing the existing gap mechanic — no inert
			// key, no new action) keeps `0` optically centered in the middle column, like Apple's
			// numberPad. The gap area stays part of `0`'s tap target, which only enlarges it.
			bottomKeys = [zero.addingGaps(leading: 1.0), delete]
		case .decimal:
			let separator = Key(
				id: "numeric.separator",
				primary: .text(decimalSeparator),
				alternates: [],
				action: .insertText(decimalSeparator),
				visualWeight: .standard,
				role: .character
			)
			bottomKeys = [separator, zero, delete]
		}
		let row4 = KeyboardRow(id: "numeric.row4", keys: bottomKeys)
		return [row1, row2, row3, row4]
	}

	// MARK: - Letters

	/// Long-press accent variants per base letter, scoped to the user's active `LetterAlternateSet`.
	/// Each map holds **only the accents** (lowercase) for that language, ordered by in-language
	/// frequency — these become the popover cells verbatim in `makeLetterKey` (no base-letter cell;
	/// task 69), and uppercase variants are derived via `posixUppercased()`. A letter absent from the
	/// map has no accents (→ no popover).
	private static func letterAlternates(for set: LetterAlternateSet) -> [Character: [String]] {
		switch set {
		case .czech:   return czechAlternates
		case .slovak:  return slovakAlternates
		case .german:  return germanAlternates
		case .polish:  return polishAlternates
		case .french:  return frenchAlternates
		case .spanish: return spanishAlternates
		case .all:     return allAlternates
		}
	}

	private static let czechAlternates: [Character: [String]] = [
		"a": ["á"], "c": ["č"], "d": ["ď"], "e": ["ě", "é"], "i": ["í"],
		"n": ["ň"], "o": ["ó"], "r": ["ř"], "s": ["š"], "t": ["ť"],
		"u": ["ů", "ú"], "y": ["ý"], "z": ["ž"]
	]

	private static let slovakAlternates: [Character: [String]] = [
		"a": ["á", "ä"], "c": ["č"], "d": ["ď"], "e": ["é"], "i": ["í"],
		"l": ["ľ", "ĺ"], "n": ["ň"], "o": ["ó", "ô"], "r": ["ŕ"], "s": ["š"],
		"t": ["ť"], "u": ["ú"], "y": ["ý"], "z": ["ž"]
	]

	private static let germanAlternates: [Character: [String]] = [
		"a": ["ä"], "o": ["ö"], "u": ["ü"]      // no ß (see task decision — avoids ß→SS uppercasing)
	]

	private static let polishAlternates: [Character: [String]] = [
		"a": ["ą"], "c": ["ć"], "e": ["ę"], "l": ["ł"], "n": ["ń"],
		"o": ["ó"], "s": ["ś"], "z": ["ż", "ź"]
	]

	private static let frenchAlternates: [Character: [String]] = [
		"a": ["à", "â", "æ"], "c": ["ç"], "e": ["é", "è", "ê", "ë"],
		"i": ["î", "ï"], "o": ["ô", "œ"], "u": ["ù", "û", "ü"], "y": ["ÿ"]
	]

	private static let spanishAlternates: [Character: [String]] = [
		"a": ["á"], "e": ["é"], "i": ["í"], "n": ["ñ"], "o": ["ó"], "u": ["ú", "ü"]
	]

	/// `.all` — the comprehensive union (today's legacy map). Czech diacritics first, then common
	/// Western European. Fallback for bilingual users and unsupported locales.
	private static let allAlternates: [Character: [String]] = [
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

	private static func makeLetterRows(shift: ShiftState, letterLayout: LetterLayout, alternateSet: LetterAlternateSet) -> [KeyboardRow] {
		let row1 = KeyboardRow(
			id: "letters.row1",
			keys: letterRow1(letterLayout).map { makeLetterKey($0, shift: shift, alternateSet: alternateSet) }
		)
		// Row 2 has 9 letters (asdf…l). To keep each key the same width as row 1's 10 keys,
		// we reserve half-a-key of inset on each side via `referenceWeight: 10`.
		let row2 = KeyboardRow(
			id: "letters.row2",
			keys: letterRow2.map { makeLetterKey($0, shift: shift, alternateSet: alternateSet) },
			referenceWeight: 10
		)
		let row3Letters = letterRow3Letters(letterLayout).map { makeLetterKey($0, shift: shift, alternateSet: alternateSet) }
		// Shift / delete on the letter row use `rowEdgeKeyWeight` (1.3) — shared with the symbol row C's
		// toggle / delete so the edges never jump when toggling — so the seven letters line up with rows
		// 1 and 2 at exactly `W/10`, edge gaps included:
		//   1.3 (shift) + 0.2 gap + 7×1.0 (letters) + 0.2 gap + 1.3 (delete) = 10.0 weight units.
		let row3 = KeyboardRow(
			id: "letters.row3",
			keys: [makeShiftKey(shift: shift).addingGaps(trailing: edgeGapWeight)]
				+ row3Letters
				+ [makeDeleteKey().addingGaps(leading: edgeGapWeight)]
		)
		return [row1, row2, row3]
	}

	private static func makeLetterKey(_ char: Character, shift: ShiftState, alternateSet: LetterAlternateSet) -> Key {
		let lower = String(char)
		let displayed = shouldUppercase(shift) ? lower.posixUppercased() : lower
		let accents = letterAlternates(for: alternateSet)[char] ?? []
		// The popover holds *only* the accents — no base-letter cell (task 69). Releasing the hold
		// without sliding commits the first accent; the base letter is still reached by a plain tap
		// (no hold). No accents in the active set → empty alternates → no popover at all. A single
		// accent (e.g. Czech `r` → `[ř]`) shows a one-cell popover, so `KeyView` no longer needs a
		// `count == 1` auto-commit shortcut. `map` over empty `accents` yields empty alternates for
		// free, so no early-return is needed.
		let alternates: [KeyContent] = accents.map { .text(shouldUppercase(shift) ? $0.posixUppercased() : $0) }
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

	/// The four symbol content rows, shared between the two configs (see `makeSymbolRows`). Which two
	/// land on which page depends on whether digits need a home:
	///
	/// - **Rich config** (number row present → digits live up top): primary = brackets + punctuation;
	///   alternate = underscores/currency + legal/typography. Today's stock layout, matching Apple.
	/// - **Native config** (no number row → digits have nowhere else): primary = digits + punctuation;
	///   alternate = brackets + underscores/currency. Mirrors the native iOS `123` / `#+=` pages; the
	///   orphaned legal/typography row (`° § ¶ …`) has no slot here, exactly like native iOS.
	///
	///   Row A (rich primary): bracket / math operator row — `[ ] { } # % ^ * + =`
	private static let symbolsPrimaryRowA: [String] = ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="]
	///   Row B (both primaries): punctuation / common symbols — `- / : ; ( ) $ & @ "`
	private static let symbolsPrimaryRowB: [String] = ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]

	///   Row A (rich alternate): underscore / pipes / comparisons / currency — `_ \ | ~ < > € £ ¥ ·`
	private static let symbolsAlternateRowA: [String] = ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "·"]
	///   Row B (rich alternate only): legal & typographic punctuation — `° § ¶ © ® ™ – — • …`.
	///   Dropped in native config (no third symbol page to host it — accepted; see task 66 ADR).
	private static let symbolsAlternateRowB: [String] = ["°", "§", "¶", "©", "®", "™", "–", "—", "•", "…"]

	/// Punctuation row C (shared between primary and alternate).
	private static let symbolsRowCPunctuation: [String] = [".", ",", "?", "!", "'"]

	/// Breathing-room gap weight between the third-row edge keys and the middle cluster, on both the
	/// letter row 3 and the symbol row C. Visual gap only — the gap area stays in the edge key's tap area.
	private static let edgeGapWeight: Double = 0.2

	/// Punctuation keys in row C render wider than a standard key — the space freed up by pinning
	/// toggle / delete to the edges is handed to them. 1.4 is dimensioned so the 5-key punctuation
	/// cluster (5×1.4 = 7.0) matches the 7-letter cluster (7×1.0), keeping both rows' middles equal
	/// width. See `makeSymbolRows` for the full budget.
	private static let symbolRowCPunctuationWeight = KeyWeight(1.4)

	/// Builds the three symbol body rows for one sub-page. `includeDigits` selects the config:
	/// when `true` (no number row in this layout → the bug case) the primary page leads with the
	/// digit row so `1…0` stay reachable; when `false` (number row carries the digits) the page
	/// keeps today's bracket-first layout. See `symbolPageContent` for the per-config row content.
	private static func makeSymbolRows(_ page: SymbolPage, inEmojiSearch: Bool, includeDigits: Bool) -> [KeyboardRow] {
		let content = symbolPageContent(page, inEmojiSearch: inEmojiSearch, includeDigits: includeDigits)
		let idPrefix = inEmojiSearch ? "emojiSearchSymbols" : "symbols"

		// Native config primary: row A is the shared digit row. It keeps a *standard* row ID (not
		// `"numberRow"`), so `KeyboardRow.isNumberRow` is false and the digits render at the full 42pt
		// cap height, aligned with the symbol row beneath — not the number row's shorter 36pt cap.
		let rowAKeys = content.rowAIsDigits ? makeDigitKeys() : content.rowA.map(makeSymbolKey)
		let rowA = KeyboardRow(id: "\(idPrefix).\(page.id).rowA", keys: rowAKeys)
		let rowB = KeyboardRow(
			id: "\(idPrefix).\(page.id).rowB",
			keys: content.rowB.map(makeSymbolKey)
		)
		let rowCToggle = content.rowCToggle
		let rowCPunctuation = symbolsRowCPunctuation.map(makeSymbolPunctuationKey)
		// Native parity: the toggle hugs the left edge and delete the right edge, each separated from
		// the punctuation cluster by a sliver of breathing room. No `referenceWeight` — the row fills
		// the full width proportionally, with the punctuation keys widened so the cluster stays
		// centered between the edge keys. Edges match the letter row 3's shift / delete so nothing
		// jumps when toggling letters ↔ symbols:
		//   1.3 (toggle) + 0.2 gap + 5×1.4 (punctuation) + 0.2 gap + 1.3 (delete) = 10.0 weight units.
		let rowC = KeyboardRow(
			id: "\(idPrefix).\(page.id).rowC",
			keys: [rowCToggle.addingGaps(trailing: edgeGapWeight)]
				+ rowCPunctuation
				+ [makeDeleteKey().addingGaps(leading: edgeGapWeight)]
		)
		return [rowA, rowB, rowC]
	}

	/// Resolved content for one symbol sub-page. `rowAIsDigits` flags the native-config primary page,
	/// whose row A is the shared digit row rather than a list of symbol glyphs (so `rowA` is unused —
	/// `makeSymbolRows` builds the digit keys directly). `rowCToggle` is the in-row `#+=` / `123`
	/// switcher.
	private struct SymbolPageContent {
		let rowA: [String]
		let rowB: [String]
		let rowCToggle: Key
		let rowAIsDigits: Bool
	}

	/// Per-config content for a symbol sub-page. The in-row `#+=` / `123` toggle hops between the
	/// `.emojiSearchSymbols` sub-pages when `inEmojiSearch`, or the regular `.symbols` sub-pages
	/// otherwise. `includeDigits` switches between the two layouts described on `symbolsPrimaryRowA`:
	/// native config (digits up front on the primary page) vs. rich config (today's brackets-first).
	private static func symbolPageContent(
		_ page: SymbolPage,
		inEmojiSearch: Bool,
		includeDigits: Bool
	) -> SymbolPageContent {
		switch page {
		case .primary:
			let target: KeyboardPage = inEmojiSearch ? .emojiSearchSymbols(.alternate) : .symbols(.alternate)
			let toggle = Key(
				id: "symbols.row3.toggleAlt",
				primary: .text("#+="),
				alternates: [],
				action: .switchPage(target),
				visualWeight: rowEdgeKeyWeight,
				role: .system
			)
			// Native: digits + punctuation. Rich: brackets + punctuation (today).
			return SymbolPageContent(
				rowA: includeDigits ? [] : symbolsPrimaryRowA,
				rowB: symbolsPrimaryRowB,
				rowCToggle: toggle,
				rowAIsDigits: includeDigits
			)

		case .alternate:
			let target: KeyboardPage = inEmojiSearch ? .emojiSearchSymbols(.primary) : .symbols(.primary)
			let toggle = Key(
				id: "symbols.row3.togglePrimary",
				primary: .text("123"),
				alternates: [],
				action: .switchPage(target),
				visualWeight: rowEdgeKeyWeight,
				role: .system
			)
			// Native: brackets + underscores/currency (legal/typography row dropped — no slot for it).
			// Rich: underscores/currency + legal/typography (today).
			return SymbolPageContent(
				rowA: includeDigits ? symbolsPrimaryRowA : symbolsAlternateRowA,
				rowB: includeDigits ? symbolsAlternateRowA : symbolsAlternateRowB,
				rowCToggle: toggle,
				rowAIsDigits: false
			)
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

	/// Width weight for the third-row edge keys — shift & delete on the letter row, and the `#+=`/`123`
	/// toggle & delete on the symbol row C. Same on both pages so the edges never jump when toggling.
	/// 1.3 + 0.2 gap each side + 7×1.0 letters = 10.0, so the letters stay at W/10 (aligned with rows 1/2).
	private static let rowEdgeKeyWeight = KeyWeight(1.3)

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
			visualWeight: rowEdgeKeyWeight,
			role: .system
		)
	}

	private static func makeDeleteKey(weight: KeyWeight = rowEdgeKeyWeight) -> Key {
		Key(
			id: "delete",
			primary: .symbol(.delete),
			alternates: [],
			action: .backspace,
			visualWeight: weight,
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
		case .numeric:
			// Unreachable — the numpad builds its own four rows in `makeNumericRows` and `layout`
			// skips this call for numeric pages. Present only to keep the switch exhaustive.
			fatalError("numeric page builds its own rows in makeNumericRows")
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
		case .emojis, .emojiSearch, .emojiSearchSymbols, .numeric:
			// Unreachable — emoji pages have their own bottom-row builders and numeric pages build
			// their own rows. Present only to keep the switch exhaustive.
			fatalError("emoji/numeric page should not reach makeStandardBottomRow")
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
		// Emoji bottom row has no shift / toggle to align with, so delete keeps its own `.wide` (1.5)
		// width rather than the narrower shared edge weight used by the letter row 3 / symbol row C.
		let delete = makeDeleteKey(weight: .wide)
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
		case .letters, .symbols, .emojis, .numeric:
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
