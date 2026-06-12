import SwiftUI
import KeyboardCore
import KeyboardUI

/// Root SwiftUI view hosted by `KeyboardViewController`. Re-builds the layout from current
/// `KeyboardState` and routes key taps back to the controller via `dispatch`.
struct KeyboardRoot: View {
	let state: KeyboardState
	/// Favorites in display order (bar + panel). The controller computes the order — manual or
	/// frequency-sorted — and freezes it while the favorites are visible, so it never shuffles
	/// under the user's finger.
	let favoriteEmojis: [String]
	let suggestions: [Suggestion]
	let showsSuggestionBar: Bool
	let dispatch: (Key) -> Void
	let toggleFavoriteEmoji: (String) -> Void
	let selectSuggestion: (Suggestion) -> Void
	let onKeyTapHaptic: () -> Void
	let onKeyClick: (ClickSoundKind) -> Void
	let onPopoverEntry: () -> Void
	let onHighlightChanged: () -> Void
	let canEscalateBackspace: () -> Bool
	let onTrackpadModeEntered: () -> Void

	var body: some View {
		let layout = KeyboardCore.makeLayout(
			page: state.page,
			showNumberRow: state.effectiveShowsNumberRow,
			returnKeyType: state.returnKeyType,
			letterLayout: state.letterLayout,
			alternateSet: state.letterAlternateSet
		)
		KeyboardView(
			layout: layout,
			width: state.keyboardWidth,
			recentEmojis: state.recentEmojis,
			favoriteEmojis: favoriteEmojis,
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
