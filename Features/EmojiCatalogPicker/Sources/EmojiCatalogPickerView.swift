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
		onDone: @escaping () -> Void
	) {
		self.selectedEmojis = selectedEmojis
		self.onToggle = onToggle
		self.onDone = onDone
	}

	public var body: some View {
		ScrollView {
			LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
				ForEach(EmojiCatalog.staticCategories) { category in
					Section {
						LazyVGrid(columns: columns, spacing: Self.gridSpacing) {
							ForEach(EmojiCatalog.emojis(for: category)) { emoji in
								cell(for: emoji.glyph)
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

	private func cell(for emoji: String) -> some View {
		let isSelected = selectedEmojis.contains(emoji)
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
		}
		.buttonStyle(.plain)
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
