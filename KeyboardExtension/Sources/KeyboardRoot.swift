import SwiftUI
import KeyboardCore
import KeyboardUI

/// Root SwiftUI view hosted by `KeyboardViewController`. Re-builds the layout from current
/// `KeyboardState` and routes key taps back to the controller via `dispatch`.
struct KeyboardRoot: View {
	let state: KeyboardState
	let suggestions: [Suggestion]
	let showsSuggestionBar: Bool
	let dispatch: (Key) -> Void
	let toggleFavoriteEmoji: (String) -> Void
	let selectSuggestion: (Suggestion) -> Void
	let onKeyTapHaptic: () -> Void
	let onKeyClick: () -> Void
	let onPopoverEntry: () -> Void
	let onHighlightChanged: () -> Void
	let canEscalateBackspace: () -> Bool
	let onTrackpadModeEntered: () -> Void

	var body: some View {
		let layout = KeyboardCore.makeLayout(
			page: state.page,
			showNumberRow: state.showNumberRow,
			returnKeyType: state.returnKeyType
		)
		KeyboardView(
			layout: layout,
			width: state.keyboardWidth,
			recentEmojis: state.recentEmojis,
			favoriteEmojis: state.favoriteEmojis,
			searchQuery: state.searchQuery,
			suggestions: suggestions,
			showsSuggestionBar: showsSuggestionBar,
			onKey: dispatch,
			onToggleFavoriteEmoji: toggleFavoriteEmoji,
			onSelectSuggestion: selectSuggestion,
			onKeyTapHaptic: onKeyTapHaptic,
			onKeyClick: onKeyClick,
			onPopoverEntry: onPopoverEntry,
			onHighlightChanged: onHighlightChanged,
			canEscalateBackspace: canEscalateBackspace,
			onTrackpadModeEntered: onTrackpadModeEntered
		)
	}
}
