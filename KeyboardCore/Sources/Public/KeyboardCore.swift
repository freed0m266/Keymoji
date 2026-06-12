import Foundation
import KeymojiCore

/// Public entry point for the KeyboardCore framework.
/// Layout factory, state machines, and input dispatch live under this namespace.
public enum KeyboardCore {

	/// Build a `KeyboardLayout` from the current page state, number-row preference, the host app's
	/// return key type, the user's QWERTY/QWERTZ letter-layout choice, and the active long-press
	/// diacritic set. Pure function — the same inputs always produce equal layouts.
	public static func makeLayout(
		page: KeyboardPage,
		showNumberRow: Bool,
		returnKeyType: ReturnKeyType,
		letterLayout: LetterLayout = .qwerty,
		alternateSet: LetterAlternateSet = .all
	) -> KeyboardLayout {
		LayoutBuilder.layout(
			page: page,
			showNumberRow: showNumberRow,
			returnKeyType: returnKeyType,
			letterLayout: letterLayout,
			alternateSet: alternateSet
		)
	}
}
