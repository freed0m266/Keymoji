import Foundation
import KeyboCore

/// Public entry point for the KeyboardCore framework.
/// Layout factory, state machines, and input dispatch live under this namespace.
public enum KeyboardCore {

	/// Build a `KeyboardLayout` from the current page state, number-row preference, the host app's
	/// return key type, and the user's QWERTY/QWERTZ letter-layout choice.
	/// Pure function — the same inputs always produce equal layouts.
	public static func makeLayout(
		page: KeyboardPage,
		showNumberRow: Bool,
		returnKeyType: ReturnKeyType,
		letterLayout: LetterLayout = .qwerty
	) -> KeyboardLayout {
		LayoutBuilder.layout(
			page: page,
			showNumberRow: showNumberRow,
			returnKeyType: returnKeyType,
			letterLayout: letterLayout
		)
	}
}
