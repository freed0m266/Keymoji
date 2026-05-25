import SwiftUI
import KeyboardCore
import KeyboardUI

/// Root SwiftUI view hosted by `KeyboardViewController`. Re-builds the layout from current
/// `KeyboardState` and routes key taps back to the controller via `dispatch`.
struct KeyboardRoot: View {
	let state: KeyboardState
	let dispatch: (Key) -> Void
	let onKeyTapHaptic: () -> Void
	let onKeyClick: () -> Void
	let onPopoverEntry: () -> Void
	let onHighlightChanged: () -> Void

	var body: some View {
		let layout = KeyboardCore.makeLayout(
			page: state.page,
			showNumberRow: state.showNumberRow,
			returnKeyType: state.returnKeyType
		)
		KeyboardView(
			layout: layout,
			width: state.keyboardWidth,
			onKey: dispatch,
			onKeyTapHaptic: onKeyTapHaptic,
			onKeyClick: onKeyClick,
			onPopoverEntry: onPopoverEntry,
			onHighlightChanged: onHighlightChanged
		)
	}
}
