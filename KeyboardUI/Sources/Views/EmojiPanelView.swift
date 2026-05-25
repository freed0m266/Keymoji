import SwiftUI
import BaseKitX
import KeyboardCore

/// Emoji picker shown when `KeyboardPage` is `.emojis`. Renders a horizontal tab bar of
/// categories at the top and a scrollable `LazyVGrid` of glyphs below. Tapping a glyph
/// invokes `onSelectEmoji`, which the controller wires to text insertion + recents update.
public struct EmojiPanelView: View {
	let recents: [String]
	let onSelectEmoji: (String) -> Void
	let onSwitchToLetters: () -> Void
	let onDelete: () -> Void
	let onKeyTapHaptic: () -> Void
	let onKeyClick: () -> Void

	@State private var selectedCategory: EmojiCategory

	public init(
		recents: [String],
		onSelectEmoji: @escaping (String) -> Void,
		onSwitchToLetters: @escaping () -> Void = {},
		onDelete: @escaping () -> Void = {},
		onKeyTapHaptic: @escaping () -> Void = {},
		onKeyClick: @escaping () -> Void = {}
	) {
		self.recents = recents
		self.onSelectEmoji = onSelectEmoji
		self.onSwitchToLetters = onSwitchToLetters
		self.onDelete = onDelete
		self.onKeyTapHaptic = onKeyTapHaptic
		self.onKeyClick = onKeyClick
		// Open on Recents only when there's something to show — otherwise jump straight to smileys.
		self._selectedCategory = State(initialValue: recents.isEmpty ? .smileys : .recents)
	}

	private static let glyphSize: CGFloat = 28
	private static let cellMinWidth: CGFloat = 38
	private static let cellHeight: CGFloat = 40
	private static let gridSpacing: CGFloat = 4
	private static let tabIconSize: CGFloat = 18
	private static let tabHeight: CGFloat = 32

	private var visibleCategories: [EmojiCategory] {
		var out: [EmojiCategory] = []
		if !recents.isEmpty { out.append(.recents) }
		out.append(contentsOf: EmojiCatalog.staticCategories)
		return out
	}

	private var currentEmojis: [String] {
		switch selectedCategory {
		case .recents:
			recents
		default:
			EmojiCatalog.emojis(for: selectedCategory)
		}
	}

	private var columns: [GridItem] {
		[GridItem(.adaptive(minimum: Self.cellMinWidth, maximum: 56), spacing: Self.gridSpacing)]
	}

	public var body: some View {
		grid
			.overlay(alignment: .bottom) {
				categoryTabs
					.padding(.top, 64)
					.background {
						LinearGradient(
							// TODO: Replace color
							colors: [
								Color(hexString: "171719"),
								Color(hexString: "171719").opacity(0.8),
								Color.clear
							],
							startPoint: .bottom,
							endPoint: .top
						)
						.allowsHitTesting(false)
					}
			}
	}

	// MARK: - Category tabs

	private var categoryTabs: some View {
		HStack(spacing: 0) {
			cornerButton(iconName: "characters.uppercase") {
				// Mirror `KeyView.firesKeyTapFeedback`: `.switchPage` is silent (no click/haptic).
				onSwitchToLetters()
			}
			.padding(.leading, 4)
			.accessibilityLabel("Switch to letters")

			ForEach(visibleCategories) { category in
				categoryTab(category, isSelected: category == selectedCategory)
					.id(category.id)
			}

			cornerButton(iconName: "delete.left") {
				// Backspace is a character-mutating action — fire haptic + click like KeyView does.
				onKeyTapHaptic()
				onKeyClick()
				onDelete()
			}
			.padding(.trailing, 4)
			.accessibilityLabel("Delete")
		}
	}

	private func categoryTab(_ category: EmojiCategory, isSelected: Bool) -> some View {
		Button {
			onKeyTapHaptic()
			selectedCategory = category
		} label: {
			categoryTabIcon(category)
				.font(.system(size: Self.tabIconSize))
				.frame(maxWidth: .infinity)
				.frame(minHeight: 44)
				.background(
					Circle()
						.fill(Color(.systemGray3).opacity(isSelected ? 1 : 0.01))
				)

		}
		.buttonStyle(.plain)
		.accessibilityLabel(category.accessibilityLabel)
		.accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
	}

	private func categoryTabIcon(_ category: EmojiCategory) -> some View {
		switch category {
		case .recents:
			Image(systemName: "clock")
		case .smileys:
			Image(systemName: "face.smiling")
		case .people:
			Image(systemName: "hand.wave")
		case .animals:
			Image(systemName: "pawprint")
		case .food:
			Image(systemName: "fork.knife")
		case .activity:
			Image(systemName: "basketball")
		case .travel:
			Image(systemName: "car")
		case .objects:
			Image(systemName: "lightbulb")
		case .symbols:
			Image(systemName: "heart")
		case .flags:
			Image(systemName: "flag")
		}
	}

	private func cornerButton(iconName: String, action: @escaping () -> Void) -> some View {
		Button(action: action) {
			Image(systemName: iconName)
				.foregroundStyle(.secondary)
				.padding(.horizontal, 4)
				.background(
					Rectangle()
						.fill(Color(.systemGray3).opacity(0.01))
				)
		}
		.buttonStyle(.plain)
	}

	// MARK: - Grid

	private var grid: some View {
		ScrollView(.vertical, showsIndicators: false) {
			if currentEmojis.isEmpty {
				emptyState
					.frame(maxWidth: .infinity, minHeight: 80)
			} else {
				LazyVGrid(columns: columns, spacing: Self.gridSpacing) {
					ForEach(currentEmojis, id: \.self) { emoji in
						EmojiCell(
							emoji: emoji,
							glyphSize: Self.glyphSize,
							height: Self.cellHeight,
							onTap: {
								onKeyTapHaptic()
								onKeyClick()
								onSelectEmoji(emoji)
							}
						)
					}
				}
				.padding(.horizontal, 6)
				.padding(.vertical, 2)
			}
		}
	}

	private var emptyState: some View {
		// Reached only when `.recents` is selected with no entries — guarded against in
		// `visibleCategories`, but kept here so the grid never renders a blank gap.
		Text("No recent emojis yet")
			.font(.footnote)
			.foregroundStyle(.secondary)
	}
}

/// Individual emoji cell. A `Button` (rather than a custom `DragGesture`) so that the parent
/// `ScrollView` keeps the vertical drag — pulling down to scroll the grid never inserts an
/// emoji. The custom `ButtonStyle` supplies the press-highlight backdrop, and the action only
/// fires if the user releases on the same cell.
private struct EmojiCell: View {
	let emoji: String
	let glyphSize: CGFloat
	let height: CGFloat
	let onTap: () -> Void

	var body: some View {
		Button(action: onTap) {
			Text(emoji)
				.font(.system(size: glyphSize))
				.minimumScaleFactor(0.8)
				.lineLimit(1)
				.frame(maxWidth: .infinity)
				.frame(height: height)
				.contentShape(Rectangle())
		}
		.buttonStyle(EmojiCellButtonStyle())
		.accessibilityElement()
		.accessibilityLabel(emoji)
		.accessibilityAddTraits(.isKeyboardKey)
	}
}

private struct EmojiCellButtonStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		ZStack {
			RoundedRectangle(cornerRadius: 5)
				.fill(configuration.isPressed ? Color(.systemGray3) : Color.clear)

			configuration.label
		}
	}
}

#if DEBUG
#Preview("Emoji panel — empty recents / Dark") {
	EmojiPanelView(recents: [], onSelectEmoji: { _ in })
		.frame(width: 393, height: 220)
		.background(Color(.systemBackground))
		.preferredColorScheme(.dark)
}

#Preview("Emoji panel — with recents / Light") {
	EmojiPanelView(
		recents: ["😀", "👋", "🎉", "❤️", "🚀", "🍕"],
		onSelectEmoji: { _ in }
	)
	.frame(width: 393, height: 220)
	.background(Color(.systemBackground))
	.preferredColorScheme(.light)
}
#endif
