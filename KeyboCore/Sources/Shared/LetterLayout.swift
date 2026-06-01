import Foundation

/// Positional variant of the alphabetic keys. Differs only in where Y and Z sit —
/// the inserted characters, diacritics, and all other keys are identical.
/// Persisted as a string in `AppGroupStore` under `letterLayout`.
public enum LetterLayout: String, Sendable, CaseIterable {
	/// English layout: `… t y u …` on row 1, `z x c v b n m` on row 3. Default.
	case qwerty
	/// Central-European layout: `… t z u …` on row 1, `y x c v b n m` on row 3.
	case qwertz
}
