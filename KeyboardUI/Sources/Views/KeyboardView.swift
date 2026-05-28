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
	public let favoriteEmojis: [String]
	public let searchQuery: String
	public let slackSuggestions: [SlackEmojiSuggester.Suggestion]
	public let onKey: (Key) -> Void
	public let onToggleFavoriteEmoji: (String) -> Void
	public let onSelectSlackSuggestion: (SlackEmojiSuggester.Suggestion) -> Void
	public let onKeyTapHaptic: () -> Void
	public let onKeyClick: () -> Void
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
		slackSuggestions: [SlackEmojiSuggester.Suggestion] = [],
		onKey: @escaping (Key) -> Void,
		onToggleFavoriteEmoji: @escaping (String) -> Void = { _ in },
		onSelectSlackSuggestion: @escaping (SlackEmojiSuggester.Suggestion) -> Void = { _ in },
		onKeyTapHaptic: @escaping () -> Void = {},
		onKeyClick: @escaping () -> Void = {},
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
		self.slackSuggestions = slackSuggestions
		self.onKey = onKey
		self.onToggleFavoriteEmoji = onToggleFavoriteEmoji
		self.onSelectSlackSuggestion = onSelectSlackSuggestion
		self.onKeyTapHaptic = onKeyTapHaptic
		self.onKeyClick = onKeyClick
		self.onPopoverEntry = onPopoverEntry
		self.onHighlightChanged = onHighlightChanged
		self.canEscalateBackspace = canEscalateBackspace
		self.onTrackpadModeEntered = onTrackpadModeEntered
	}

	private let horizontalPadding: CGFloat = 6
	private let topPadding: CGFloat = 3
	private let rowSpacing: CGFloat = 11

	private var isEmojiKeyboard: Bool {
		layout.page == .emojis
	}

	private var isEmojiSearchKeyboard: Bool {
		layout.page.isEmojiSearch
	}

	/// Suggestion bar appears only on letter pages while the user is composing a shortcode.
	/// On symbol or emoji pages the bar is suppressed (the user can't be in a shortcode-authoring
	/// state there anyway), and the controller is expected to pass `slackSuggestions == []`.
	private var showsSuggestionBar: Bool {
		guard !isEmojiKeyboard, case .letters = layout.page else { return false }
		return !slackSuggestions.isEmpty
	}

	/// When the suggestion bar is up, it *replaces* the number row to keep the keyboard height
	/// constant. With number row off, the bar stacks on top and the keyboard grows by `barHeight`.
	private var showsNumberRow: Bool {
		layout.rows.contains(where: \.isNumberRow) && !showsSuggestionBar
	}

	public var body: some View {
		VStack(spacing: rowSpacing) {
			if showsSuggestionBar {
				SlackSuggestionBarView(
					suggestions: slackSuggestions,
					onSelect: onSelectSlackSuggestion,
					onKeyTapHaptic: onKeyTapHaptic,
					onKeyClick: onKeyClick
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
		.padding(.top, topPadding)
		.frame(width: width, height: keyboardHeight)
		// Fade the whole keyboard while the user is scrubbing the cursor — matches stock iOS,
		// where the keys recede so the surface visually becomes a trackpad.
		.opacity(isInTrackpadMode ? 0.45 : 1.0)
		.animation(.easeOut(duration: 0.15), value: isInTrackpadMode)
	}

	private var emojiSearchKeyboard: some View {
		VStack(spacing: rowSpacing) {
			EmojiSearchView(
				query: searchQuery,
				recents: recentEmojis,
				onSelectEmoji: { emoji in
					let key = Key(
						id: "emoji.\(emoji)",
						primary: .text(emoji),
						alternates: [],
						action: .insertText(emoji),
						visualWeight: .standard,
						role: .character
					)
					onKey(key)
				},
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
				onKeyClick: onKeyClick
			)
			defaultKeyboard
		}
	}

	private var emojiKeyboard: some View {
		EmojiPanelView(
			recents: recentEmojis,
			favorites: favoriteEmojis,
			onSelectEmoji: { emoji in
				// Synthesize a transient `Key` for emoji insertion so it flows through the
				// existing dispatch path. `role: .character` keeps `KeyView`-style feedback
				// semantics in any downstream consumers.
				let key = Key(
					id: "emoji.\(emoji)",
					primary: .text(emoji),
					alternates: [],
					action: .insertText(emoji),
					visualWeight: .standard,
					role: .character
				)
				onKey(key)
			},
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
			.frame(maxHeight: row.isNumberRow ? 36 : nil)
		}
	}

	private func handleTrackpadModeChanged(_ active: Bool) {
		isInTrackpadMode = active
		if active { onTrackpadModeEntered() }
	}

	private var visibleRows: [KeyboardRow] {
		// Drop the number row whenever the suggestion bar takes its slot.
		showsSuggestionBar ? layout.rows.filter { !$0.isNumberRow } : layout.rows
	}

	/// Hardcoded heights for iPhone portrait, v1.0. Adjust after on-device testing.
	/// When the suggestion bar replaces the number row the total height is unchanged; when it
	/// stacks on top of a number-row-less keyboard, height grows by the bar (~44 pt incl. spacing).
	private var keyboardHeight: CGFloat {
		let base: CGFloat = layout.showsNumberRow ? 260 : 216
		let barFootprint: CGFloat = 44
		if showsSuggestionBar && !layout.showsNumberRow {
			return base + barFootprint
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
		let interSectionSpacing = rowSpacing
		let topPaddingInsideSearchView: CGFloat = 4
		let interBarSpacing: CGFloat = 6
		return searchBarHeight
			+ resultsBarHeight
			+ interSectionSpacing
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
