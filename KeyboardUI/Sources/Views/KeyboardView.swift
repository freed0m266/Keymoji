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
	public let slackSuggestions: [SlackEmojiSuggester.Suggestion]
	public let onKey: (Key) -> Void
	public let onToggleFavoriteEmoji: (String) -> Void
	public let onSelectSlackSuggestion: (SlackEmojiSuggester.Suggestion) -> Void
	public let onKeyTapHaptic: () -> Void
	public let onKeyClick: () -> Void
	public let onPopoverEntry: () -> Void
	public let onHighlightChanged: () -> Void

	public init(
		layout: KeyboardLayout,
		width: CGFloat,
		recentEmojis: [String] = [],
		favoriteEmojis: [String] = [],
		slackSuggestions: [SlackEmojiSuggester.Suggestion] = [],
		onKey: @escaping (Key) -> Void,
		onToggleFavoriteEmoji: @escaping (String) -> Void = { _ in },
		onSelectSlackSuggestion: @escaping (SlackEmojiSuggester.Suggestion) -> Void = { _ in },
		onKeyTapHaptic: @escaping () -> Void = {},
		onKeyClick: @escaping () -> Void = {},
		onPopoverEntry: @escaping () -> Void = {},
		onHighlightChanged: @escaping () -> Void = {}
	) {
		self.layout = layout
		self.width = width
		self.recentEmojis = recentEmojis
		self.favoriteEmojis = favoriteEmojis
		self.slackSuggestions = slackSuggestions
		self.onKey = onKey
		self.onToggleFavoriteEmoji = onToggleFavoriteEmoji
		self.onSelectSlackSuggestion = onSelectSlackSuggestion
		self.onKeyTapHaptic = onKeyTapHaptic
		self.onKeyClick = onKeyClick
		self.onPopoverEntry = onPopoverEntry
		self.onHighlightChanged = onHighlightChanged
	}

	private let horizontalPadding: CGFloat = 3
	private let topPadding: CGFloat = 4
	private let rowSpacing: CGFloat = 10

	private var isEmojiKeyboard: Bool {
		layout.page == .emojis
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
			if isEmojiKeyboard {
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
					onKeyTapHaptic: onKeyTapHaptic,
					onKeyClick: onKeyClick
				)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else {
				if showsSuggestionBar {
					SlackSuggestionBarView(
						suggestions: slackSuggestions,
						onSelect: onSelectSlackSuggestion,
						onKeyTapHaptic: onKeyTapHaptic,
						onKeyClick: onKeyClick
					)
				}
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
						onHighlightChanged: onHighlightChanged
					)
					.frame(maxHeight: row.isNumberRow ? 38 : nil)
				}
			}
		}
		.padding(.horizontal, isEmojiKeyboard ? 0 : horizontalPadding)
		.padding(.top, topPadding)
		.frame(width: width, height: keyboardHeight)
		.background(Color(.systemBackground))
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
		return base
	}
}

#if DEBUG
//#Preview("Letters Lower / Dark") {
//	KeyboardView(
//		layout: KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .default),
//		width: 393,
//		onKey: { _ in }
//	)
//	.preferredColorScheme(.dark)
//}
//
//#Preview("Letters Upper / Light") {
//	KeyboardView(
//		layout: KeyboardCore.makeLayout(page: .letters(.upper), showNumberRow: true, returnKeyType: .default),
//		width: 393,
//		onKey: { _ in }
//	)
//	.preferredColorScheme(.light)
//}
//
//#Preview("Caps Lock / Dark") {
//	KeyboardView(
//		layout: KeyboardCore.makeLayout(page: .letters(.capsLock), showNumberRow: true, returnKeyType: .default),
//		width: 393,
//		onKey: { _ in }
//	)
//	.preferredColorScheme(.dark)
//}
//
//#Preview("Symbols Primary / Dark") {
//	KeyboardView(
//		layout: KeyboardCore.makeLayout(page: .symbols(.primary), showNumberRow: true, returnKeyType: .default),
//		width: 393,
//		onKey: { _ in }
//	)
//	.preferredColorScheme(.dark)
//}
//
//#Preview("Symbols Alternate / Dark") {
//	KeyboardView(
//		layout: KeyboardCore.makeLayout(page: .symbols(.alternate), showNumberRow: true, returnKeyType: .default),
//		width: 393,
//		onKey: { _ in }
//	)
//	.preferredColorScheme(.dark)
//}
//
//#Preview("No Number Row / Dark") {
//	KeyboardView(
//		layout: KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: false, returnKeyType: .default),
//		width: 393,
//		onKey: { _ in }
//	)
//	.preferredColorScheme(.dark)
//}
//
//#Preview("Return = Search / Dark") {
//	KeyboardView(
//		layout: KeyboardCore.makeLayout(page: .letters(.lower), showNumberRow: true, returnKeyType: .search),
//		width: 393,
//		onKey: { _ in }
//	)
//	.preferredColorScheme(.dark)
//}

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
