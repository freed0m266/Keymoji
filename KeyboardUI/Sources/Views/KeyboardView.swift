import SwiftUI
import KeyboardCore

/// Public entry point — renders a complete keyboard given a `KeyboardLayout`.
///
/// Width is passed explicitly by the caller — `GeometryReader` was unreliable inside the
/// hosting controller's input view (it occasionally under-reports by a few points, which
/// shifts the keyboard a fraction to the right and clips the rightmost keys). The
/// `KeyboardViewController` reads `view.bounds.width` in `viewDidLayoutSubviews` and feeds it here.
public struct KeyboardView: View {
	public let layout: KeyboardLayout
	public let width: CGFloat
	public let recentEmojis: [String]
	/// Favorites in the order they should appear, shared by both the suggestion bar and the emoji
	/// panel so the two never disagree. The caller (`KeyboardViewController`) decides the order —
	/// manual or frequency-sorted — and freezes it while the favorites are on screen.
	public let favoriteEmojis: [String]
	public let searchQuery: String
	public let suggestions: [Suggestion]
	/// Whether the current field permits the top bar at all. The host passes `currentEligibility.allowDisplay`,
	/// which is false in secure (password) entry; on those fields the reserved top region stays empty so the
	/// favorites/suggestions bar is hidden, matching stock keyboards. This is *only* the field gate — it's
	/// deliberately independent of the suggestions master toggle, since the favorites baseline shows even with
	/// word/Slack suggestions turned off (see `showsBarContent`). Defaults to `true` (eligible field).
	public let fieldAllowsBar: Bool
	public let onKey: (Key) -> Void
	public let onToggleFavoriteEmoji: (String) -> Void
	public let onSelectSuggestion: (Suggestion) -> Void
	public let onKeyTapHaptic: () -> Void
	public let onKeyClick: (ClickSoundKind) -> Void
	public let onPopoverEntry: () -> Void
	public let onHighlightChanged: () -> Void
	/// Returns true when the underlying document proxy currently exposes
	/// `documentContextBeforeInput`. The keyboard uses this to decide whether a long
	/// delete-on-hold may escalate to word-by-word delete (which needs visible context to
	/// find word boundaries). Defaults to nil — escalation is allowed unconditionally,
	/// which is fine for previews and tests that don't run a real proxy.
	public let canEscalateBackspace: (() -> Bool)?
	/// Fired once when trackpad-on-space mode engages. The keyboard owns the visual fade
	/// internally; this hook lets the host fire the entry haptic.
	public let onTrackpadModeEntered: () -> Void

	@State private var isInTrackpadMode = false

	public init(
		layout: KeyboardLayout,
		width: CGFloat,
		recentEmojis: [String] = [],
		favoriteEmojis: [String] = [],
		searchQuery: String = "",
		suggestions: [Suggestion] = [],
		fieldAllowsBar: Bool = true,
		onKey: @escaping (Key) -> Void,
		onToggleFavoriteEmoji: @escaping (String) -> Void = { _ in },
		onSelectSuggestion: @escaping (Suggestion) -> Void = { _ in },
		onKeyTapHaptic: @escaping () -> Void = {},
		onKeyClick: @escaping (ClickSoundKind) -> Void = { _ in },
		onPopoverEntry: @escaping () -> Void = {},
		onHighlightChanged: @escaping () -> Void = {},
		canEscalateBackspace: (() -> Bool)? = nil,
		onTrackpadModeEntered: @escaping () -> Void = {}
	) {
		self.layout = layout
		self.width = width
		self.recentEmojis = recentEmojis
		self.favoriteEmojis = favoriteEmojis
		self.searchQuery = searchQuery
		self.suggestions = suggestions
		self.fieldAllowsBar = fieldAllowsBar
		self.onKey = onKey
		self.onToggleFavoriteEmoji = onToggleFavoriteEmoji
		self.onSelectSuggestion = onSelectSuggestion
		self.onKeyTapHaptic = onKeyTapHaptic
		self.onKeyClick = onKeyClick
		self.onPopoverEntry = onPopoverEntry
		self.onHighlightChanged = onHighlightChanged
		self.canEscalateBackspace = canEscalateBackspace
		self.onTrackpadModeEntered = onTrackpadModeEntered
	}

	private let horizontalPadding = KeyboardMetrics.horizontalPadding

	private var isEmojiKeyboard: Bool {
		layout.page == .emojis
	}

	private var isEmojiSearchKeyboard: Bool {
		layout.page.isEmojiSearch
	}

	/// Whether the `topRegion` renders bar content. True on letter/symbol pages of an eligible field; false
	/// on the emoji panel / emoji-search pages (which have no `topRegion`) and in secure fields
	/// (`fieldAllowsBar`). Decoupled from the suggestions master toggle: the bar's baseline is the user's
	/// favorites — guaranteed non-empty after onboarding (task 62) — so on an eligible field the top region
	/// always shows *something* (emoji quick-access), and word/Slack suggestions only take it over
	/// transiently while typing. The master toggle therefore doesn't make the bar disappear; it only gates
	/// whether suggestions are computed (controller-side). Content-only (task 61): drives content, never
	/// height — the region is reserved regardless, so this can't cause host/view height drift.
	private var showsBarContent: Bool {
		fieldAllowsBar && !isEmojiKeyboard && !isEmojiSearchKeyboard
	}

	/// Favorites shown *in the bar*. Falls back to the curated starter set (`EmojiCatalog.defaultFavorites`)
	/// when the user has none, so the always-on emoji quick-access is never empty — the same "never empty"
	/// guarantee onboarding makes for the stored set (task 62), held here as a runtime safety net for the
	/// edge case where the user clears every favorite. Scoped to the bar only: the emoji panel's favorites
	/// category still reflects the real stored list (and stays hidden when it's empty), so the panel's
	/// star-toggle curation isn't polluted with defaults the user never picked.
	private var barFavorites: [String] {
		favoriteEmojis.isEmpty ? EmojiCatalog.defaultFavorites : favoriteEmojis
	}

	public var body: some View {
		VStack(spacing: 0) {
			// letters/symbols reserve the `topRegion` above the keys; emoji and emoji-search fill the
			// canonical height with their own content (the panel grows, the search chrome expands), so
			// they get no separate region slot.
			if !isEmojiKeyboard && !isEmojiSearchKeyboard {
				topRegion
			}

			if isEmojiKeyboard {
				emojiKeyboard
			} else if isEmojiSearchKeyboard {
				emojiSearchKeyboard
			} else {
				defaultKeyboard
			}
		}
		.padding(.horizontal, isEmojiKeyboard ? 0 : horizontalPadding)
		.frame(width: width, height: keyboardHeight)
		// Fade the whole keyboard while the user is scrubbing the cursor — matches stock iOS,
		// where the keys recede so the surface visually becomes a trackpad.
		.opacity(isInTrackpadMode ? 0.45 : 1.0)
		.animation(.easeOut(duration: 0.15), value: isInTrackpadMode)
	}

	/// The reserved region above the keys on letter/symbol pages (task 61). Fixed at
	/// `KeyboardMetrics.topRegionHeight` whether or not it has content, so the keyboard's height is
	/// identical whatever the bar shows — switching pages, toggling suggestions off, or entering a secure
	/// field never makes it jump. On an eligible field it renders the `SuggestionBarView` (`showsBarContent`):
	/// word/Slack suggestions while typing, otherwise the favorites quick-access row. In a secure field
	/// (`!fieldAllowsBar`) it stays empty — height held, bar hidden, like stock keyboards. A future
	/// top-region content type would slot into the same fixed-height container.
	private var topRegion: some View {
		VStack(spacing: 0) {
			if showsBarContent {
				SuggestionBarView(
					suggestions: suggestions,
					favoriteEmojis: barFavorites,
					totalWidth: max(0, width - horizontalPadding * 2),
					onSelect: onSelectSuggestion,
					onSelectEmoji: { emoji in insertEmojiKey(emoji) },
					onKeyTapHaptic: onKeyTapHaptic,
					onKeyClick: { onKeyClick(.character) }
				)
				// Explicit gap below the bar (decision #6), so the bar (40) + gap (2) exactly fill the
				// region's 42pt — the bar sits flush at the top with the gap below it, above the first row.
				Color.clear.frame(height: KeyboardMetrics.suggestionBarGap)
			}
		}
		.frame(height: KeyboardMetrics.topRegionHeight)
	}

	/// Builds the transient emoji-insert `Key` and routes it through `onKey`, so emoji taps from the
	/// emoji panel, emoji search, and the suggestion-bar favorites all share one dispatch path —
	/// getting text insertion, haptics/sound, and the recents update (`recordRecentEmojiIfNeeded`)
	/// for free. `role: .character` keeps `KeyView`-style feedback semantics downstream.
	private func insertEmojiKey(_ emoji: String) {
		let key = Key(
			id: "emoji.\(emoji)",
			primary: .text(emoji),
			alternates: [],
			action: .insertText(emoji),
			visualWeight: .standard,
			role: .character
		)
		onKey(key)
	}

	private var emojiSearchKeyboard: some View {
		VStack(spacing: 0) {
			EmojiSearchView(
				query: searchQuery,
				recents: recentEmojis,
				onSelectEmoji: { emoji in insertEmojiKey(emoji) },
				onClearSearch: {
					// `×` always exits search back to the regular emoji panel. The dispatcher's
					// `.switchPage` handler clears the query buffer in `KeyboardState`.
					let key = Key(
						id: "emojiSearch.clear",
						primary: .symbol(.delete),
						alternates: [],
						action: .switchPage(.emojis),
						visualWeight: .standard,
						role: .system
					)
					onKey(key)
				},
				onKeyTapHaptic: onKeyTapHaptic,
				onKeyClick: { onKeyClick(.character) }
			)
			defaultKeyboard
		}
	}

	private var emojiKeyboard: some View {
		EmojiPanelView(
			recents: recentEmojis,
			favorites: favoriteEmojis,
			onSelectEmoji: { emoji in insertEmojiKey(emoji) },
			onToggleFavorite: onToggleFavoriteEmoji,
			onSwitchToLetters: {
				let key = Key(
					id: "emojiPanel.switchToLetters",
					primary: .text("ABC"),
					alternates: [],
					action: .switchPage(.letters(.lower)),
					visualWeight: .small,
					role: .system
				)
				onKey(key)
			},
			onDelete: {
				let key = Key(
					id: "emojiPanel.delete",
					primary: .symbol(.delete),
					alternates: [],
					action: .backspace,
					visualWeight: .wide,
					role: .system
				)
				onKey(key)
			},
			onEnterSearch: {
				let key = Key(
					id: "emojiPanel.enterSearch",
					primary: .symbol(.smiley),
					alternates: [],
					action: .switchPage(.emojiSearch),
					visualWeight: .standard,
					role: .system
				)
				onKey(key)
			},
			onKeyTapHaptic: onKeyTapHaptic,
			onKeyClick: onKeyClick
		)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}

	private var defaultKeyboard: some View {
		ForEach(visibleRows) { row in
			KeyRowView(
				row: row,
				page: layout.page,
				returnKeyType: layout.returnKeyType,
				totalWidth: max(0, width - horizontalPadding * 2),
				onKey: onKey,
				onKeyTapHaptic: onKeyTapHaptic,
				onKeyClick: onKeyClick,
				onPopoverEntry: onPopoverEntry,
				onHighlightChanged: onHighlightChanged,
				canEscalateBackspace: canEscalateBackspace,
				onTrackpadModeChanged: handleTrackpadModeChanged
			)
			// No per-row height clamp — each `KeyView` now carries its own fixed cap height, so the
			// VStack is exactly the sum of the row slots and rows never stretch to fill leftover space.
		}
	}

	private func handleTrackpadModeChanged(_ active: Bool) {
		isInTrackpadMode = active
		if active { onTrackpadModeEntered() }
	}

	private var visibleRows: [KeyboardRow] {
		// The suggestion bar is now a separate row above the number row (no mutex), so all layout
		// rows render unconditionally.
		layout.rows
	}

	/// Total keyboard height, derived bottom-up from `KeyboardMetrics` (cap heights + row gaps + the
	/// reserved `topRegion` + emoji-search chrome). The same `KeyboardMetrics.keyboardHeight(for:)` drives
	/// the host UIInputView constraint in `KeyboardViewController`, so the SwiftUI frame and the host can't
	/// drift (drift used to clip the emoji-search bar — task 39 / task 52). It takes no `showsSuggestionBar`
	/// flag (task 61): the region is reserved unconditionally, so height depends only on page + number row.
	private var keyboardHeight: CGFloat {
		KeyboardMetrics.keyboardHeight(for: layout)
	}
}

#if DEBUG
#Preview("Letters Lower / Dark") {
	KeyboardView(
		layout: KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default),
		width: 393,
		onKey: { _ in }
	)
	.preferredColorScheme(.dark)
}

#Preview("Letters Upper / Light") {
	KeyboardView(
		layout: KeyboardCore.makeLayout(page: .letters(.upper), showNumberRow: true, returnKeyType: .default),
		width: 393,
		onKey: { _ in }
	)
	.preferredColorScheme(.light)
}

#Preview("Caps Lock / Dark") {
	KeyboardView(
		layout: KeyboardCore.makeLayout(page: .letters(.capsLock), showNumberRow: true, returnKeyType: .default),
		width: 393,
		onKey: { _ in }
	)
	.preferredColorScheme(.dark)
}

#Preview("Symbols Primary / Dark") {
	KeyboardView(
		layout: KeyboardCore.makeLayout(page: .symbols(.primary), showNumberRow: true, returnKeyType: .default),
		width: 393,
		onKey: { _ in }
	)
	.preferredColorScheme(.dark)
}

#Preview("Symbols Alternate / Dark") {
	KeyboardView(
		layout: KeyboardCore.makeLayout(page: .symbols(.alternate), showNumberRow: true, returnKeyType: .default),
		width: 393,
		onKey: { _ in }
	)
	.preferredColorScheme(.dark)
}

#Preview("No Number Row / Dark") {
	KeyboardView(
		layout: KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: false, returnKeyType: .default),
		width: 393,
		onKey: { _ in }
	)
	.preferredColorScheme(.dark)
}

#Preview("Return = Search / Dark") {
	KeyboardView(
		layout: KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .search),
		width: 393,
		onKey: { _ in }
	)
	.preferredColorScheme(.dark)
}

#Preview("Emojis / no recents / Dark") {
	KeyboardView(
		layout: KeyboardCore.makeLayout(page: .emojis, showNumberRow: true, returnKeyType: .default),
		width: 393,
		recentEmojis: [],
		onKey: { _ in }
	)
	.preferredColorScheme(.dark)
}

#Preview("Emojis / with recents / Light") {
	KeyboardView(
		layout: KeyboardCore.makeLayout(page: .emojis, showNumberRow: true, returnKeyType: .default),
		width: 393,
		recentEmojis: ["😀", "👋", "🎉", "❤️", "🚀", "🍕", "🐶", "🌈"],
		onKey: { _ in }
	)
	.preferredColorScheme(.light)
}

#Preview("Emojis / with favorites / Dark") {
	KeyboardView(
		layout: KeyboardCore.makeLayout(page: .emojis, showNumberRow: true, returnKeyType: .default),
		width: 393,
		recentEmojis: ["😀", "👋"],
		favoriteEmojis: ["❤️", "🚀", "🍕", "🐶"],
		onKey: { _ in }
	)
	.preferredColorScheme(.dark)
}
#endif
