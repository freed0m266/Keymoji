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
	/// Whether the suggestion bar may occupy its row. The controller computes this from the
	/// master toggle + field eligibility; on letter pages an enabled, allowed field shows the bar
	/// even when `suggestions` is empty (C1 — always-on, visually silent, keeps height constant).
	public let showsSuggestionBar: Bool
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
		showsSuggestionBar: Bool = false,
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
		self.showsSuggestionBar = showsSuggestionBar
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

	private let horizontalPadding: CGFloat = 3

	private var isEmojiKeyboard: Bool {
		layout.page == .emojis
	}

	private var isEmojiSearchKeyboard: Bool {
		layout.page.isEmojiSearch
	}

	/// The suggestion bar is its own row above the number row (A2 — no mutex with the number row),
	/// shown only on letter pages. The controller gates `showsSuggestionBar` on the master toggle
	/// and field eligibility; this is the final view-side guard that keeps it off symbol/emoji/search
	/// pages. Independent of `suggestions.isEmpty` (C1 — always-on when enabled, so height is stable).
	private var effectiveShowsBar: Bool {
		guard showsSuggestionBar, !isEmojiKeyboard, !isEmojiSearchKeyboard else { return false }
		if case .letters = layout.page { return true }
		return false
	}

	public var body: some View {
		VStack(spacing: 0) {
			if effectiveShowsBar {
				SuggestionBarView(
					suggestions: suggestions,
					favoriteEmojis: favoriteEmojis,
					totalWidth: max(0, width - horizontalPadding * 2),
					onSelect: onSelectSuggestion,
					onSelectEmoji: { emoji in insertEmojiKey(emoji) },
					onKeyTapHaptic: onKeyTapHaptic,
					onKeyClick: { onKeyClick(.character) }
				)
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
			.frame(maxHeight: row.isNumberRow ? 48 : nil)
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

	/// Vertical footprint the suggestion bar adds when shown: the bar height plus the inter-row
	/// gap above the keys below it. Public so `KeyboardViewController` can mirror it in the host
	/// input view's height constraint — otherwise the SwiftUI content overflows and clips.
	public static let suggestionBarFootprint: CGFloat = 51

	/// Hardcoded heights for iPhone portrait, v1.0. Adjust after on-device testing.
	/// The suggestion bar (when shown) adds `suggestionBarFootprint` on top of the base height,
	/// stacking above the number row rather than replacing it (A2).
	private var keyboardHeight: CGFloat {
		let base: CGFloat = layout.showsNumberRow ? 260 : 216
		if effectiveShowsBar {
			return base + Self.suggestionBarFootprint
		}
		if isEmojiSearchKeyboard {
			// Emoji search stacks the search bar (~36 pt) + horizontal results bar (~44 pt) + a
			// vertical row gap above the full QWERTY layout. The layout builder also drops the
			// number row in this mode, so we measure off the no-number-row base and add the
			// chrome footprint. Without this, the bottom space/delete row clipped under the
			// frame (caught by the Codex review on task 39).
			return 216 + emojiSearchChromeHeight
		}
		return base
	}

	/// Vertical footprint of the emoji-search chrome (search bar + results bar + intra-row gap)
	/// stacked above the regular QWERTY rows when `layout.page == .emojiSearch`.
	private var emojiSearchChromeHeight: CGFloat {
		let searchBarHeight: CGFloat = 32
		let resultsBarHeight: CGFloat = 44
		let topPaddingInsideSearchView: CGFloat = 4
		let interBarSpacing: CGFloat = 6
		return searchBarHeight
			+ resultsBarHeight
			+ topPaddingInsideSearchView
			+ interBarSpacing
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
