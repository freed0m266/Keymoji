import Foundation

/// Maps a focused field's keyboard type onto the numpad page it should force, or `nil` when the
/// field doesn't want a numpad (task 59). Pure and UIKit-free — it takes the already-mirrored
/// `KeyboardInputKind` (see `SuggestionFieldTraitsMapping` in the extension), so the full mapping
/// stays unit-testable inside `KeyboardCore`.
public enum NumericPageResolver {

	/// Only `.numberPad` → `.numeric(.integer)` and `.decimalPad` → `.numeric(.decimal)` force the
	/// numpad. Everything else returns `nil`:
	/// - `.asciiCapableNumberPad` expects letters too, so a locked numpad would trap the user.
	/// - `.phonePad` / `.namePhonePad` want a `+ * #` phone layout (and iOS often forces its own);
	///   out of scope here.
	/// - `.default`, `.url`, `.emailAddress`, … are plain text fields.
	public static func numericPage(for kind: KeyboardInputKind) -> KeyboardPage? {
		switch kind {
		case .numberPad:  return .numeric(.integer)
		case .decimalPad: return .numeric(.decimal)
		case .default, .asciiCapable, .numbersAndPunctuation, .url, .phonePad,
		     .namePhonePad, .emailAddress, .twitter, .webSearch, .asciiCapableNumberPad:
			return nil
		}
	}
}
