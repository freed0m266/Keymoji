//
//  EmojiCatalogPickerView.swift
//  EmojiCatalogPicker
//
//  Created by Martin Svoboda on 25.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import KeyboardCore
import KeymojiResources

/// Categorized emoji grid presented as a sheet from the Favorites editor. Tapping a cell
/// toggles the emoji's membership in the user's favorites; the checkmark badge reflects
/// the current state so users can browse and curate in one sweep without dismissing.
public struct EmojiCatalogPickerView: View {
	public let selectedEmojis: Set<String>
	public let onToggle: (String) -> Void
	public let onDone: () -> Void
	/// Optional cap. When set, once `selectedEmojis.count` reaches it, unselected cells dim + disable
	/// (matching the onboarding grid) so a free user can't pick past what the keyboard would keep.
	/// `nil` (default) = no cap — the Favorites editor relies on its `onToggle` paywall instead.
	public let selectionLimit: Int?

	typealias Texts = L10n.Settings.Favorites.Picker

	private static let glyphSize: CGFloat = 28
	private static let cellMinWidth: CGFloat = 44
	private static let cellHeight: CGFloat = 52
	private static let gridSpacing: CGFloat = 4

	private var columns: [GridItem] {
		[GridItem(.adaptive(minimum: Self.cellMinWidth, maximum: 64), spacing: Self.gridSpacing)]
	}

	public init(
		selectedEmojis: Set<String>,
		onToggle: @escaping (String) -> Void,
		onDone: @escaping () -> Void,
		selectionLimit: Int? = nil
	) {
		self.selectedEmojis = selectedEmojis
		self.onToggle = onToggle
		self.onDone = onDone
		self.selectionLimit = selectionLimit
	}

	public var body: some View {
		ScrollView {
			LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
				ForEach(EmojiCatalog.staticCategories) { category in
					Section {
						LazyVGrid(columns: columns, spacing: Self.gridSpacing) {
							ForEach(EmojiCatalog.emojis(for: category)) { emoji in
								cell(for: emoji.glyph, isSelected: selectedEmojis.contains(emoji.glyph))
							}
						}
						.padding(.horizontal, 16)
					} header: {
						sectionHeader(category)
					}
				}
			}
			.padding(.vertical, 8)
		}
		// Clip overflow at the top (content bleeding under the nav bar) without
		// cropping the bottom — the mask hugs the top edge but extends past the
		// bottom safe area so content keeps flowing under the home indicator.
		.mask {
			Rectangle()
				.ignoresSafeArea(edges: .bottom)
		}
		.navigationTitle(Texts.title)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button(L10n.General.ok) { onDone() }
					.fontWeight(.semibold)
			}
		}
	}

	private func sectionHeader(_ category: EmojiCategory) -> some View {
		HStack(spacing: 8) {
			Text(category.accessibilityLabel)
				.font(.subheadline)
				.fontWeight(.semibold)
				.foregroundStyle(.secondary)
			Spacer()
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 6)
		.background(Color(.systemBackground))
	}

	/// Whether an unselected cell should be dimmed/disabled because the selection cap is reached.
	private func isBeyondLimit(isSelected: Bool) -> Bool {
		guard let limit = selectionLimit, !isSelected else { return false }
		return selectedEmojis.count >= limit
	}

	private func cell(for emoji: String, isSelected: Bool) -> some View {
		let dimmed = isBeyondLimit(isSelected: isSelected)
		return Button {
			onToggle(emoji)
		} label: {
			ZStack(alignment: .topTrailing) {
				Text(emoji)
					.font(.system(size: Self.glyphSize))
					.frame(maxWidth: .infinity)
					.frame(height: Self.cellHeight)
					.background(
						RoundedRectangle(cornerRadius: 8)
							.fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
					)
				if isSelected {
					Image(systemName: "checkmark.circle.fill")
						.font(.system(size: 14))
						.foregroundStyle(Color.accentColor, Color(.systemBackground))
						.padding(2)
				}
			}
			.contentShape(Rectangle())
			.opacity(dimmed ? 0.35 : 1)
		}
		.buttonStyle(.plain)
		.disabled(dimmed)
		.accessibilityLabel(emoji)
		.accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
	}
}

#if DEBUG
#Preview {
	NavigationStack {
		EmojiCatalogPickerView(
			selectedEmojis: ["😀", "❤️"],
			onToggle: { _ in },
			onDone: {}
		)
	}
	.preferredColorScheme(.dark)
}
#endif
