//
//  FavoriteEmojisEditorView.swift
//  FavoriteEmojisEditor
//
//  Created by Martin Svoboda on 25.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import EmojiCatalogPicker
import KeyboardCore
import KeymojiCore
import KeymojiResources

public struct FavoriteEmojisEditorView<ViewModel: FavoriteEmojisEditorViewModeling>: View {
	@State private var viewModel: ViewModel
	@State private var pickerPresented = false

	typealias Texts = L10n.Settings.Favorites

	public init(viewModel: ViewModel) {
		_viewModel = State(initialValue: viewModel)
	}

	public var body: some View {
		Group {
			if viewModel.favorites.isEmpty {
				emptyState
			} else {
				favoritesList
			}
		}
		.navigationTitle(Texts.title)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button {
					pickerPresented = true
				} label: {
					Label(Texts.add, systemImage: "plus")
				}
			}
			// Drag-to-reorder only applies to manual order — hide Edit in `.frequency`.
			if !viewModel.favorites.isEmpty, viewModel.sortMode == .manual {
				ToolbarItem(placement: .topBarLeading) {
					EditButton()
				}
			}
		}
		.sheet(isPresented: $pickerPresented) {
			NavigationStack {
				EmojiCatalogPickerView(
					selectedEmojis: Set(viewModel.favorites),
					onToggle: { emoji in viewModel.toggle(emoji) },
					onDone: { pickerPresented = false }
				)
			}
			.preferredColorScheme(.dark)
		}
	}

	private var emptyState: some View {
		ContentUnavailableView {
			Label(Texts.emptyTitle, systemImage: "star")
		} description: {
			Text(Texts.emptyMessage)
		} actions: {
			Button(Texts.add) { pickerPresented = true }
				.buttonStyle(.borderedProminent)
		}
	}

	private var favoritesList: some View {
		List {
			Section {
				Picker(Texts.Sort.title, selection: $viewModel.sortMode) {
					Text(Texts.Sort.manual).tag(FavoritesSortMode.manual)
					Text(Texts.Sort.frequency).tag(FavoritesSortMode.frequency)
				}
				.pickerStyle(.segmented)
				.labelsHidden()
			}
			Section {
				ForEach(viewModel.displayedFavorites, id: \.self) { emoji in
					row(for: emoji)
				}
				.onDelete {
					offsets in viewModel.remove(at: offsets)
				}
				.onMove(
					perform: viewModel.sortMode == .manual
						? { source, destination in viewModel.move(fromOffsets: source, toOffset: destination) }
						: nil
				)
			} footer: {
				Text(viewModel.sortMode == .manual ? Texts.listFooter : Texts.frequencyFooter)
			}
		}
	}

	private func row(for emoji: String) -> some View {
		let shortcode = SlackEmojiTable.shortcode(for: emoji)
		return HStack(spacing: 12) {
			Text(emoji)
				.font(.system(size: 28))
				.frame(width: 40, alignment: .center)
			if let shortcode {
				Text(":\(shortcode):")
					.font(.body.monospaced())
					.foregroundStyle(.primary)
					.lineLimit(1)
			} else {
				Text(Texts.noShortcode)
					.font(.body.italic())
					.foregroundStyle(.secondary)
			}
		}
		.accessibilityElement()
		.accessibilityLabel(shortcode.map { "\(emoji), :\($0):" } ?? emoji)
	}
}

#if DEBUG
#Preview("With favorites") {
	NavigationStack {
		FavoriteEmojisEditorView(
			viewModel: FavoriteEmojisEditorViewModelMock(favorites: ["❤️", "😀", "🚀", "🎉", "🐶"])
		)
	}
	.preferredColorScheme(.dark)
}

#Preview("Frequency") {
	NavigationStack {
		FavoriteEmojisEditorView(
			viewModel: FavoriteEmojisEditorViewModelMock(
				favorites: ["❤️", "😀", "🚀", "🎉", "🐶"],
				sortMode: .frequency,
				counts: ["🚀": 20, "🐶": 12, "😀": 5]
			)
		)
	}
	.preferredColorScheme(.dark)
}

#Preview("Empty") {
	NavigationStack {
		FavoriteEmojisEditorView(viewModel: FavoriteEmojisEditorViewModelMock(favorites: []))
	}
	.preferredColorScheme(.dark)
}
#endif
