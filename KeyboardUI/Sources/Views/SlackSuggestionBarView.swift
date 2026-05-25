import SwiftUI
import KeyboardCore

/// Typeahead bar that sits above the keyboard while the user is composing a Slack-style
/// `:shortcode:`. Renders each suggestion as a chip — emoji glyph + truncated shortcode
/// label — and forwards taps via `onSelect`. Sized for the predictive-bar slot (~40 pt tall).
///
/// `KeyboardView` shows this *instead of* the number row when both would otherwise be on
/// screen; that's a deliberate tradeoff to keep the keyboard from growing in height during
/// shortcode authoring (the typeahead replaces the number row, not appends to it).
public struct SlackSuggestionBarView: View {
	public let suggestions: [SlackEmojiSuggester.Suggestion]
	public let onSelect: (SlackEmojiSuggester.Suggestion) -> Void
	public let onKeyTapHaptic: () -> Void
	public let onKeyClick: () -> Void

	public init(
		suggestions: [SlackEmojiSuggester.Suggestion],
		onSelect: @escaping (SlackEmojiSuggester.Suggestion) -> Void,
		onKeyTapHaptic: @escaping () -> Void = {},
		onKeyClick: @escaping () -> Void = {}
	) {
		self.suggestions = suggestions
		self.onSelect = onSelect
		self.onKeyTapHaptic = onKeyTapHaptic
		self.onKeyClick = onKeyClick
	}

	private let barHeight: CGFloat = 40
	private let chipSpacing: CGFloat = 6
	private let horizontalPadding: CGFloat = 6

	public var body: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: chipSpacing) {
				ForEach(suggestions) { suggestion in
					chip(for: suggestion)
				}
			}
			.padding(.horizontal, horizontalPadding)
		}
		.frame(height: barHeight)
		.background(Color(.systemBackground))
	}

	private func chip(for suggestion: SlackEmojiSuggester.Suggestion) -> some View {
		Button {
			onKeyTapHaptic()
			onKeyClick()
			onSelect(suggestion)
		} label: {
			HStack(spacing: 4) {
				Text(suggestion.emoji)
					.font(.system(size: 20))
				Text(":\(suggestion.shortcode):")
					.font(.system(size: 12, weight: .medium))
					.foregroundStyle(Color(.secondaryLabel))
					.lineLimit(1)
					.truncationMode(.tail)
			}
			.padding(.horizontal, 8)
			.padding(.vertical, 4)
			.background(
				RoundedRectangle(cornerRadius: 6)
					.fill(Color(.systemGray5))
			)
		}
		.buttonStyle(.plain)
		.frame(maxWidth: 140)
	}
}

#if DEBUG
#Preview("Suggestions / dark") {
	SlackSuggestionBarView(
		suggestions: [
			.init(shortcode: "smile", emoji: "😄"),
			.init(shortcode: "smiley", emoji: "😃"),
			.init(shortcode: "smirk", emoji: "😏"),
			.init(shortcode: "smiling_imp", emoji: "😈"),
			.init(shortcode: "smoking", emoji: "🚬")
		],
		onSelect: { _ in }
	)
	.frame(width: 393, height: 40)
	.preferredColorScheme(.dark)
}

#Preview("Suggestions / light") {
	SlackSuggestionBarView(
		suggestions: [
			.init(shortcode: "fire", emoji: "🔥"),
			.init(shortcode: "thumbsup", emoji: "👍")
		],
		onSelect: { _ in }
	)
	.frame(width: 393, height: 40)
	.preferredColorScheme(.light)
}
#endif
