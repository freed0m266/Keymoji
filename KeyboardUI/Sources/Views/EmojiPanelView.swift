import SwiftUI
import BaseKitX
import KeyboardCore

/// Emoji picker shown when `KeyboardPage` is `.emojis`. Renders a horizontal tab bar of
/// categories at the top and a scrollable `LazyVGrid` of glyphs below. Tapping a glyph
/// invokes `onSelectEmoji`, which the controller wires to text insertion + recents update.
public struct EmojiPanelView: View {
	let recents: [String]
	let favorites: [String]
	let onSelectEmoji: (String) -> Void
	let onToggleFavorite: (String) -> Void
	let onSwitchToLetters: () -> Void
	let onDelete: () -> Void
	let onEnterSearch: () -> Void
	let onKeyTapHaptic: () -> Void
	let onKeyClick: () -> Void

	@State private var selectedCategory: EmojiCategory

	public init(
		recents: [String],
		favorites: [String] = [],
		onSelectEmoji: @escaping (String) -> Void,
		onToggleFavorite: @escaping (String) -> Void = { _ in },
		onSwitchToLetters: @escaping () -> Void = {},
		onDelete: @escaping () -> Void = {},
		onEnterSearch: @escaping () -> Void = {},
		onKeyTapHaptic: @escaping () -> Void = {},
		onKeyClick: @escaping () -> Void = {}
	) {
		self.recents = recents
		self.favorites = favorites
		self.onSelectEmoji = onSelectEmoji
		self.onToggleFavorite = onToggleFavorite
		self.onSwitchToLetters = onSwitchToLetters
		self.onDelete = onDelete
		self.onEnterSearch = onEnterSearch
		self.onKeyTapHaptic = onKeyTapHaptic
		self.onKeyClick = onKeyClick
		// Open priority: favorites > recents > smileys. The most personalized tab wins so
		// returning users land on what they curated rather than the bundled catalog.
		let initial: EmojiCategory
		if !favorites.isEmpty {
			initial = .favorites
		} else if !recents.isEmpty {
			initial = .recents
		} else {
			initial = .smileys
		}
		self._selectedCategory = State(initialValue: initial)
	}

	private static let glyphSize: CGFloat = 28
	private static let cellMinWidth: CGFloat = 38
	private static let cellHeight: CGFloat = 40
	private static let gridSpacing: CGFloat = 4
	private static let tabIconSize: CGFloat = 18
	private static let tabHeight: CGFloat = 32

	private var visibleCategories: [EmojiCategory] {
		var out: [EmojiCategory] = []
		if !favorites.isEmpty { out.append(.favorites) }
		if !recents.isEmpty { out.append(.recents) }
		out.append(contentsOf: EmojiCatalog.staticCategories)
		return out
	}

	private var currentEmojis: [String] {
		switch selectedCategory {
		case .favorites:
			favorites
		case .recents:
			recents
		default:
			EmojiCatalog.emojis(for: selectedCategory).map(\.glyph)
		}
	}

	private var columns: [GridItem] {
		[GridItem(.adaptive(minimum: Self.cellMinWidth, maximum: 56), spacing: Self.gridSpacing)]
	}

	public var body: some View {
		VStack(spacing: 0) {
			searchBarTrigger
			grid
				.overlay(alignment: .bottom) {
					categoryTabs
						.padding(.top, 52)
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
		// Snap away from `.favorites`/`.recents` if the user empties the list while it's the
		// active tab (e.g. long-presses to unfavorite the last entry). Without this the tab
		// stays selected but its row is gone, leaving an unreachable empty grid.
		.onChange(of: visibleCategories) { _, newValue in
			if !newValue.contains(selectedCategory) {
				selectedCategory = newValue.first ?? .smileys
			}
		}
	}

	// MARK: - Search bar trigger

	/// Read-only search affordance pinned above the grid. Tapping it asks the controller to
	/// switch into `.emojiSearch` mode — it doesn't actually edit any text itself. Mirrors
	/// the native iOS emoji picker's "Search Emoji" placeholder bar.
	private var searchBarTrigger: some View {
		Button {
			onKeyTapHaptic()
			onEnterSearch()
		} label: {
			HStack(spacing: 6) {
				Image(systemName: "magnifyingglass")
					.font(.system(size: 14, weight: .regular))
				Text("Search Emoji")
					.font(.system(size: 15))
				Spacer()
			}
			.foregroundStyle(.secondary)
			.padding(.horizontal, 10)
			.frame(height: 32)
			.background(
				RoundedRectangle(cornerRadius: 8, style: .continuous)
					.fill(Color(.systemGray3).opacity(0.45))
			)
			.padding(.horizontal, 10)
			.padding(.top, 6)
			.padding(.bottom, 4)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.accessibilityLabel("Search emoji")
		.accessibilityAddTraits(.isButton)
	}

	// MARK: - Category tabs

	private var categoryTabs: some View {
		HStack(spacing: 0) {
			cornerButton(iconName: "characters.uppercase") {
				// Mirror `KeyView.firesKeyTapFeedback`: fire haptic + click on page switch.
				onKeyTapHaptic()
				onKeyClick()
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
		case .favorites:
			Image(systemName: "star.fill")
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
							},
							onLongPress: {
								// Long-press toggles favorite membership. Fire the popover-entry haptic
								// to confirm the toggle landed without ambiguity vs. an ordinary tap.
								onKeyTapHaptic()
								onToggleFavorite(emoji)
							}
						)
					}
				}
				.padding(.horizontal, 6)
				.padding(.vertical, 2)
				.padding(.bottom, 52)
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
	let onLongPress: () -> Void

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
		// SwiftUI cancels the Button's tap action when this long-press fires first, so the two
		// gestures stay mutually exclusive: a quick tap inserts, a held finger toggles favorite.
		.onLongPressGesture(minimumDuration: 0.45, perform: onLongPress)
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

#Preview("Emoji panel — with favorites / Dark") {
	EmojiPanelView(
		recents: ["😀", "👋", "🎉"],
		favorites: ["❤️", "🚀", "🍕", "🐶"],
		onSelectEmoji: { _ in }
	)
	.frame(width: 393, height: 220)
	.background(Color(.systemBackground))
	.preferredColorScheme(.dark)
}
#endif
