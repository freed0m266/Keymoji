import Foundation

/// Top-level keyboard page state. `letters(_:)` carries the current shift state;
/// `symbols` is the punctuation/symbols page reached via the 123 toggle.
public enum KeyboardPage: Sendable, Equatable {
	case letters(ShiftState)
	case symbols
}

public enum ShiftState: Sendable, Equatable {
	case lower
	/// One-shot uppercase — downshifts to lower after the next character.
	case upper
	/// Sticky uppercase — stays until explicitly disabled (double-tap shift, or tap shift while in caps).
	case capsLock
}
