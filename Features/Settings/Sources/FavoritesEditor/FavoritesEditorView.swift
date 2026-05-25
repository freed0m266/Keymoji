//
//  FavoritesEditorView.swift
//  Settings
//
//  Created by Martin Svoboda on 25.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import KeyboardCore
import KeyboResources

public struct FavoritesEditorView<ViewModel: FavoritesEditorViewModeling>: View {
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
			if !viewModel.favorites.isEmpty {
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
				ForEach(viewModel.favorites, id: \.self) { emoji in
					HStack(spacing: 12) {
						Text(emoji)
							.font(.system(size: 28))
						Text(emoji)
							.font(.body)
							.foregroundStyle(.secondary)
					}
					.accessibilityElement()
					.accessibilityLabel(emoji)
				}
				.onDelete { offsets in viewModel.remove(at: offsets) }
				.onMove { source, destination in viewModel.move(fromOffsets: source, toOffset: destination) }
			} footer: {
				Text(Texts.listFooter)
			}
		}
	}
}

#if DEBUG
#Preview("With favorites") {
	NavigationStack {
		FavoritesEditorView(
			viewModel: FavoritesEditorViewModelMock(favorites: ["❤️", "😀", "🚀", "🎉", "🐶"])
		)
	}
	.preferredColorScheme(.dark)
}

#Preview("Empty") {
	NavigationStack {
		FavoritesEditorView(viewModel: FavoritesEditorViewModelMock(favorites: []))
	}
	.preferredColorScheme(.dark)
}
#endif
