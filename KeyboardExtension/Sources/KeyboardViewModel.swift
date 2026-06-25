import SwiftUI
import KeyboardCore
import KeyboardUI

/// Observable render model for the keyboard (task 73, Phase B).
///
/// The hosting controller is installed **once** with a `KeyboardRoot` bound to this model; thereafter
/// `KeyboardViewController` mutates these properties in place instead of reassigning
/// `hostingController.rootView`. SwiftUI's Observation tracks exactly which properties each subview
/// reads, so a keystroke that only changes `suggestions` invalidates the suggestion bar without
/// touching the key grid (the grid rows are additionally `Equatable`, so they short-circuit even when
/// `KeyboardView.body` re-runs).
///
/// Properties are the *render-affecting* slice of `KeyboardState` plus the derived `layout`. The
/// callbacks are stored once (`@ObservationIgnored`) and forward to the controller, so they never
/// reallocate and never trigger spurious invalidation.
@MainActor
@Observable
final class KeyboardViewModel {

	/// Memoized layout (built once per layout-affecting change by the controller). Drives the key grid.
	var layout: KeyboardLayout
	/// Visible keyboard width in points, from `view.bounds.width`.
	var width: CGFloat
	var recentEmojis: [String]
	/// Favorites in frozen display order (bar + panel), as resolved by the controller.
	var favoriteEmojis: [String]
	/// Whether the suggestion bar should center its favorites cluster. Controller sets it to
	/// `!state.effectiveIsPlus` — the view stays monetization-agnostic (it only knows "center or not").
	var centersFavorites: Bool
	var searchQuery: String
	var suggestions: [Suggestion]
	/// Whether the field permits the top bar (false in secure entry).
	var fieldAllowsBar: Bool

	// MARK: - Stable callbacks (never reallocated → no spurious invalidation)

	@ObservationIgnored let dispatch: (Key) -> Void
	@ObservationIgnored let selectSuggestion: (Suggestion) -> Void
	@ObservationIgnored let onKeyTapHaptic: () -> Void
	@ObservationIgnored let onKeyClick: (ClickSoundKind) -> Void
	@ObservationIgnored let onPopoverEntry: () -> Void
	@ObservationIgnored let onHighlightChanged: () -> Void
	@ObservationIgnored let canEscalateBackspace: () -> Bool
	@ObservationIgnored let onTrackpadModeEntered: () -> Void

	init(
		layout: KeyboardLayout,
		width: CGFloat,
		recentEmojis: [String],
		favoriteEmojis: [String],
		centersFavorites: Bool,
		searchQuery: String,
		suggestions: [Suggestion],
		fieldAllowsBar: Bool,
		dispatch: @escaping (Key) -> Void,
		selectSuggestion: @escaping (Suggestion) -> Void,
		onKeyTapHaptic: @escaping () -> Void,
		onKeyClick: @escaping (ClickSoundKind) -> Void,
		onPopoverEntry: @escaping () -> Void,
		onHighlightChanged: @escaping () -> Void,
		canEscalateBackspace: @escaping () -> Bool,
		onTrackpadModeEntered: @escaping () -> Void
	) {
		self.layout = layout
		self.width = width
		self.recentEmojis = recentEmojis
		self.favoriteEmojis = favoriteEmojis
		self.centersFavorites = centersFavorites
		self.searchQuery = searchQuery
		self.suggestions = suggestions
		self.fieldAllowsBar = fieldAllowsBar
		self.dispatch = dispatch
		self.selectSuggestion = selectSuggestion
		self.onKeyTapHaptic = onKeyTapHaptic
		self.onKeyClick = onKeyClick
		self.onPopoverEntry = onPopoverEntry
		self.onHighlightChanged = onHighlightChanged
		self.canEscalateBackspace = canEscalateBackspace
		self.onTrackpadModeEntered = onTrackpadModeEntered
	}
}
