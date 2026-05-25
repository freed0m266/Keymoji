import Foundation

/// Top-level keyboard page state. `letters(_:)` carries the current shift state;
/// `symbols(_:)` carries which of the two symbol sub-pages is showing.
/// `emojis` is the emoji picker — its own category selection lives in view state, not here.
public enum KeyboardPage: Sendable, Equatable {
	case letters(ShiftState)
	case symbols(SymbolPage)
	case emojis
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
