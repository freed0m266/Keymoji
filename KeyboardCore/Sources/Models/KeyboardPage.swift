import Foundation

/// Top-level keyboard page state. `letters(_:)` carries the current shift state;
/// `symbols(_:)` carries which of the two symbol sub-pages is showing.
/// `emojis` is the emoji picker — its own category selection lives in view state, not here.
/// `emojiSearch` and `emojiSearchSymbols` are search-driven siblings: a QWERTY/symbols layout
/// typing into `KeyboardState.searchQuery` (no host insertions) with a horizontal results bar
/// above the keyboard. The `123` / `ABC` toggle on their bottom row hops between the two,
/// matching the native iOS emoji-search keyboard. Exit happens via the `×` in the search bar.
public enum KeyboardPage: Sendable, Equatable {
	case letters(ShiftState)
	case symbols(SymbolPage)
	case emojis
	case emojiSearch
	case emojiSearchSymbols(SymbolPage)
	/// Locked Apple-style numeric grid, force-shown while a `.numberPad` / `.decimalPad` field is
	/// focused (task 59). `NumericKind` selects integer vs. decimal; the concrete decimal-separator
	/// glyph is locale-aware and flows into `LayoutBuilder` separately (like `returnKeyType`), so
	/// this case stays locale-agnostic and cleanly `Equatable`.
	case numeric(NumericKind)
}

/// Which numeric variant the numpad renders. `.integer` mirrors `numberPad` (no separator — the
/// bottom-left slot stays empty so `0` reads centered); `.decimal` mirrors `decimalPad` (the
/// bottom-left slot holds the locale decimal separator).
public enum NumericKind: Sendable, Equatable {
	case integer
	case decimal
}

/// Convenience predicate: any of the search-mode pages. Used by `InputDispatcher` to route
/// character/space/backspace into the query buffer, by `LayoutBuilder` to drop the number
/// row, and by the view layer to keep the search chrome on screen across `123` ↔ `ABC`
/// toggles.
public extension KeyboardPage {
	var isEmojiSearch: Bool {
		switch self {
		case .emojiSearch, .emojiSearchSymbols:   return true
		case .letters, .symbols, .emojis, .numeric: return false
		}
	}

	/// True for the force-shown numeric pages (task 59). Guards the number-row inclusion and the
	/// bottom-row append in `LayoutBuilder` (the numpad builds its own four rows) and the
	/// "leaving a numeric field" branch in `KeyboardViewController`.
	var isNumeric: Bool {
		if case .numeric = self { return true }
		return false
	}
}

public enum ShiftState: Sendable, Equatable {
	case lower
	/// One-shot uppercase — downshifts to lower after the next character.
	case upper
	/// Sticky uppercase — stays until explicitly disabled (double-tap shift, or tap shift while in caps).
	case capsLock
}

/// Which of the two symbol pages is showing. Mirrors Apple's stock `123` / `#+=` pattern:
/// the `[#+=]` toggle on the primary page goes to `.alternate`, the `[123]` toggle on the
/// alternate page goes back to `.primary`.
public enum SymbolPage: Sendable, Equatable {
	case primary
	case alternate
}
