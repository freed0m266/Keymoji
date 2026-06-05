import SwiftUI
import KeyboardCore
import KeymojiUI

/// The suggestion bar that sits above the keyboard. Renders an arbitrary `[Suggestion]`, drawing
/// each chip per its `renderStyle`:
///
/// - `.plain` (word completion): up to three evenly-spaced text chips with vertical dividers,
///   matching the stock predictive bar.
/// - `.pill` (Slack shortcode typeahead): emoji glyph + `:shortcode:` label in a rounded chip,
///   horizontally scrollable — preserves the pre-refactor Slack bar look.
///
/// The coordinator returns a homogeneous list (Slack wins wholesale or word completions only), so
/// the bar picks one layout based on the first chip. When `suggestions` is empty it falls back to a
/// third mode — a horizontal scroll of `favoriteEmojis` (bare glyphs, tap-to-insert) — filling the
/// slot that would otherwise be blank. With no suggestions *and* no favorites the bar still occupies
/// its slot but draws nothing (C1 — always-shown when enabled, visually silent when there's nothing
/// to offer, so the keyboard never changes height as content comes and goes).
public struct SuggestionBarView: View {
	public let suggestions: [Suggestion]
	/// Favorite emoji glyphs, rendered as a horizontal scroll row in the otherwise-empty bar — shown
	/// only when there are no `suggestions` (never alongside them; see `body`). Empty by default so
	/// existing call sites and snapshots keep their behavior.
	public let favoriteEmojis: [String]
	public let totalWidth: CGFloat
	public let onSelect: (Suggestion) -> Void
	/// Tap handler for a favorite emoji glyph. The host routes it through the same emoji-insert
	/// dispatch path as the emoji panel (text insertion + haptics/sound + recents update).
	public let onSelectEmoji: (String) -> Void
	public let onKeyTapHaptic: () -> Void
	public let onKeyClick: () -> Void

	private let barHeight: CGFloat = 40
	private let chipSpacing: CGFloat = 6
	private let horizontalPadding: CGFloat = 3
	private let favoriteEmojiWidth: CGFloat = 42

	private var emojiPages: [[String]] {
		let usable = totalWidth - 2 * horizontalPadding
		let per = Int(floor(usable / favoriteEmojiWidth))
		let emojisPerPage = max(1, per)

		return stride(from: 0, to: favoriteEmojis.count, by: emojisPerPage).map {
			Array(favoriteEmojis[$0 ..< min($0 + emojisPerPage, favoriteEmojis.count)])
		}
	}

	public init(
		suggestions: [Suggestion],
		favoriteEmojis: [String] = [],
		totalWidth: CGFloat,
		onSelect: @escaping (Suggestion) -> Void,
		onSelectEmoji: @escaping (String) -> Void = { _ in },
		onKeyTapHaptic: @escaping () -> Void = {},
		onKeyClick: @escaping () -> Void = {}
	) {
		self.suggestions = suggestions
		self.favoriteEmojis = favoriteEmojis
		self.totalWidth = totalWidth
		self.onSelect = onSelect
		self.onSelectEmoji = onSelectEmoji
		self.onKeyTapHaptic = onKeyTapHaptic
		self.onKeyClick = onKeyClick
	}

	public var body: some View {
		Group {
			if !suggestions.isEmpty {
				if suggestions.first?.renderStyle == .pill {
					pillBar
				} else {
					plainBar
				}
			} else if !favoriteEmojis.isEmpty {
				favoritesBar
			} else {
				// Nothing to suggest and no favorites → visually silent bar that still holds its
				// slot (C1). `plainBar` with empty `suggestions` draws nothing.
				plainBar
			}
		}
		.frame(height: barHeight)
		.frame(maxWidth: .infinity)
	}

	// MARK: - Plain (word completion)

	private var plainBar: some View {
		HStack(spacing: 0) {
			ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
				Button {
					select(suggestion)
				} label: {
					Text(suggestion.displayText)
						.font(.system(size: 17))
						.lineLimit(1)
						.truncationMode(.tail)
						.foregroundStyle(Color(.label))
						.padding(.horizontal, 6)
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(.plain)

				if index < suggestions.count - 1 {
					Divider().frame(height: 20)
				}
			}
		}
	}

	// MARK: - Pill (Slack shortcodes)

	private var pillBar: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: chipSpacing) {
				ForEach(suggestions) { suggestion in
					pillChip(for: suggestion)
				}
			}
			.padding(.horizontal, horizontalPadding)
		}
	}

	private func pillChip(for suggestion: Suggestion) -> some View {
		Button {
			select(suggestion)
		} label: {
			HStack(spacing: 4) {
				Text(suggestion.replacementText)
					.font(.system(size: 20))

				Text(":\(suggestion.displayText):")
					.font(.system(size: 12, weight: .medium))
					.foregroundStyle(Color(.secondaryLabel))
					.lineLimit(1)
					.truncationMode(.tail)
			}
			.padding(.vertical, 4)
			.padding(.horizontal, 8)
			.background(
				RoundedRectangle(cornerRadius: 6)
					.fill(Color(.systemGray5))
			)
		}
		.buttonStyle(.plain)
		.frame(maxWidth: 140)
	}

	private func select(_ suggestion: Suggestion) {
		onKeyTapHaptic()
		onKeyClick()
		onSelect(suggestion)
	}

	// MARK: - Favorites (emoji quick-access)

	private var favoritesBar: some View {
		TabView {
			ForEach(Array(emojiPages.enumerated()), id: \.offset) { index, page in
				HStack(spacing: 0) {
					ForEach(page, id: \.self) { emoji in
						Button {
							selectEmoji(emoji)
						} label: {
							Text(emoji)
								.font(.system(size: 24))
								.frame(minWidth: favoriteEmojiWidth)
								.tappable()
						}
						.buttonStyle(.plain)
					}
					Spacer(minLength: 0) // last (partial) page stays left-aligned
				}
				.tappable()
				.padding(.horizontal, horizontalPadding)
				.tag(index)
			}
		}
		.tabViewStyle(.page(indexDisplayMode: .never))
	}

	private func selectEmoji(_ emoji: String) {
		onKeyTapHaptic()
		onKeyClick()
		onSelectEmoji(emoji)
	}
}

#if DEBUG
private func wordSuggestion(_ text: String, score: Double) -> Suggestion {
	Suggestion(
		id: "word:\(text)",
		displayText: text,
		replacementText: text,
		renderStyle: .plain,
		score: score,
		source: .wordCompletion
	)
}

private func pillSuggestion(_ shortcode: String, _ emoji: String) -> Suggestion {
	Suggestion(
		id: "slack:\(shortcode)",
		displayText: shortcode,
		replacementText: emoji,
		renderStyle: .pill,
		score: 1.0,
		source: .slack
	)
}

#Preview("Word chips / dark") {
	SuggestionBarView(
		suggestions: [
			wordSuggestion("hello", score: 0.9),
			wordSuggestion("help", score: 0.7),
			wordSuggestion("helicopter", score: 0.5)
		],
		totalWidth: 387,
		onSelect: { _ in }
	)
	.frame(width: 393, height: 40)
	.preferredColorScheme(.dark)
}

#Preview("Pill chips / light") {
	SuggestionBarView(
		suggestions: [
			pillSuggestion("smile", "😄"),
			pillSuggestion("smiley", "😃"),
			pillSuggestion("smirk", "😏")
		],
		totalWidth: 387,
		onSelect: { _ in }
	)
	.frame(width: 393, height: 40)
	.preferredColorScheme(.light)
}

#Preview("Favorite emojis / dark") {
	SuggestionBarView(
		suggestions: [],
		favoriteEmojis: ["❤️", "😀", "🚀", "🎉", "🐶", "🍕", "👍"],
		totalWidth: 387,
		onSelect: { _ in },
		onSelectEmoji: { _ in }
	)
	.frame(width: 393, height: 40)
	.preferredColorScheme(.dark)
}
#endif
