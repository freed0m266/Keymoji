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
}

/// Convenience predicate: any of the search-mode pages. Used by `InputDispatcher` to route
/// character/space/backspace into the query buffer, by `LayoutBuilder` to drop the number
/// row, and by the view layer to keep the search chrome on screen across `123` ↔ `ABC`
/// toggles.
public extension KeyboardPage {
	var isEmojiSearch: Bool {
		switch self {
		case .emojiSearch, .emojiSearchSymbols: return true
		case .letters, .symbols, .emojis:       return false
		}
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
