import Foundation

/// Public entry point for the KeyboardCore framework.
/// Layout factory, state machines, and input dispatch live under this namespace.
public enum KeyboardCore {

	/// Build a `KeyboardLayout` from the current page state, number-row preference, and the host app's return key type.
	/// Pure function — the same inputs always produce equal layouts.
	public static func makeLayout(
		page: KeyboardPage,
		showNumberRow: Bool,
		returnKeyType: ReturnKeyType
	) -> KeyboardLayout {
		LayoutBuilder.layout(
			page: page,
			showNumberRow: showNumberRow,
			returnKeyType: returnKeyType
		)
	}
}
