import SwiftUI
import KeyboardCore
import KeyboardUI

/// Root SwiftUI view hosted by `KeyboardViewController`. Bound **once** to a `KeyboardViewModel`
/// (task 73, Phase B): it reads the model's render-affecting properties, so SwiftUI's Observation
/// re-evaluates `body` only when one of them changes — and the key grid (`KeyRowView`s inside
/// `KeyboardView`) is `Equatable`, so an unchanged `layout` short-circuits the grid even when a
/// keystroke updates `suggestions`. Key taps route back to the controller via the model's stable
/// callbacks.
struct KeyboardRoot: View {
	let model: KeyboardViewModel

	var body: some View {
		KeyboardView(
			layout: model.layout,
			width: model.width,
			recentEmojis: model.recentEmojis,
			favoriteEmojis: model.favoriteEmojis,
			centersFavorites: model.centersFavorites,
			searchQuery: model.searchQuery,
			suggestions: model.suggestions,
			fieldAllowsBar: model.fieldAllowsBar,
			onKey: model.dispatch,
			onSelectSuggestion: model.selectSuggestion,
			onKeyTapHaptic: model.onKeyTapHaptic,
			onKeyClick: model.onKeyClick,
			onPopoverEntry: model.onPopoverEntry,
			onHighlightChanged: model.onHighlightChanged,
			canEscalateBackspace: model.canEscalateBackspace,
			onTrackpadModeEntered: model.onTrackpadModeEntered
		)
	}
}
