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
import KeymojiUI
import Paywall

public struct FavoriteEmojisEditorView<ViewModel: FavoriteEmojisEditorViewModeling>: View {
	@State private var viewModel: ViewModel
	@State private var sheet: EditorSheet?

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
					sheet = .picker
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
		// All paywall triggers (picker over-limit add, frequency lock, upsell row) funnel through the
		// view model's `paywallContext`; bridge it into the single sheet so the picker→paywall swap
		// happens in one presentation instead of racing two sheets.
		.onChange(of: viewModel.paywallContext) { _, context in
			if let context { sheet = .paywall(context) }
		}
		.sheet(item: $sheet, onDismiss: { viewModel.paywallContext = nil }, content: sheetContent)
	}

	@ViewBuilder
	private func sheetContent(_ kind: EditorSheet) -> some View {
		switch kind {
		case .picker:
			NavigationStack {
				EmojiCatalogPickerView(
					selectedEmojis: Set(viewModel.favorites),
					onToggle: { emoji in viewModel.toggle(emoji) },
					onDone: { sheet = nil }
				)
			}
		case .paywall(let context):
			PaywallView(
				viewModel: paywallVM(context: context),
				onFinish: { sheet = nil }
			)
		}
	}

	private var emptyState: some View {
		ContentUnavailableView {
			Label(Texts.emptyTitle, systemImage: "star")
		} description: {
			Text(Texts.emptyMessage)
		} actions: {
			Button(Texts.add) { sheet = .picker }
				.buttonStyle(.borderedProminent)
		}
	}

	private var favoritesList: some View {
		List {
			Section {
				Picker(Texts.Sort.title, selection: sortSelection) {
					Text(Texts.Sort.manual).tag(FavoritesSortMode.manual)
					frequencyLabel.tag(FavoritesSortMode.frequency)
				}
				.pickerStyle(.segmented)
				.labelsHidden()
			} footer: {
				if !viewModel.isPlus {
					Text(Texts.frequencyLockedFooter)
				}
			}

			if showsUpsellRow {
				Section {
					upsellRow
				}
			}

			Section {
				ForEach(viewModel.displayedFavorites, id: \.self) { emoji in
					row(for: emoji)
				}
				.onDelete { offsets in
					viewModel.remove(at: offsets)
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

	/// Routes the segmented control through `setSortMode` so the Plus gate can intercept `.frequency`
	/// and snap the selection back to `.manual` (the value never changed) while opening the paywall.
	private var sortSelection: Binding<FavoritesSortMode> {
		Binding(
			get: { viewModel.sortMode },
			set: { viewModel.setSortMode($0) }
		)
	}

	/// "Most used" gains a lock for free users so the gate reads as an invitation, not a dead control.
	@ViewBuilder
	private var frequencyLabel: some View {
		if viewModel.isPlus {
			Text(Texts.Sort.frequency)
		} else {
			Label(Texts.Sort.frequency, systemImage: "lock.fill")
		}
	}

	/// Shown to a free user who has filled (or, after a downgrade, overfilled) the free favorites cap.
	private var showsUpsellRow: Bool {
		!viewModel.isPlus && !viewModel.canAddMoreFavorites
	}

	private var upsellRow: some View {
		Button {
			viewModel.requestPaywall(.favoritesLimit)
		} label: {
			HStack(spacing: 12) {
				Icon.starCircleFill
					.font(.system(size: 26))
					.foregroundStyle(.tint)
				VStack(alignment: .leading, spacing: 2) {
					Text(Texts.limitTitle)
						.font(.body.weight(.semibold))
						.foregroundStyle(.primary)
					Text(Texts.limitCaption(viewModel.favorites.count, viewModel.freeFavoritesLimit))
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
				Spacer()
				Icon.chevronRight
					.font(.footnote.weight(.semibold))
					.foregroundStyle(.tertiary)
			}
		}
		.buttonStyle(.plain)
	}

	private func row(for emoji: String) -> some View {
		// Prefer the human-readable catalog name (covers ~every glyph incl. flags); fall back to
		// the Slack shortcode for the rare entry that has one but no name.
		let name = EmojiCatalog.emoji(for: emoji)?.name
		let shortcode = SlackEmojiTable.shortcode(for: emoji)
		let label = name.flatMap { $0.isEmpty ? nil : $0.capitalized }
		return HStack(spacing: 12) {
			Text(emoji)
				.font(.system(size: 28))
				.frame(width: 40, alignment: .center)
			if let label {
				Text(label)
					.font(.body)
					.foregroundStyle(.primary)
					.lineLimit(1)
			} else if let shortcode {
				Text(":\(shortcode):")
					.font(.body.monospaced())
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
		}
		.accessibilityElement()
		.accessibilityLabel(label.map { "\(emoji), \($0)" } ?? shortcode.map { "\(emoji), :\($0):" } ?? emoji)
	}

	private enum EditorSheet: Identifiable {
		case picker
		case paywall(PaywallContext)

		var id: String {
			switch self {
			case .picker: "picker"
			case .paywall(let context): "paywall.\(context.rawValue)"
			}
		}
	}
}

#if DEBUG
#Preview("With favorites (Plus)") {
	NavigationStack {
		FavoriteEmojisEditorView(
			viewModel: FavoriteEmojisEditorViewModelMock(favorites: ["❤️", "😀", "🚀", "🎉", "🇨🇿"])
		)
	}
	.preferredColorScheme(.dark)
}

#Preview("Frequency (Plus)") {
	NavigationStack {
		FavoriteEmojisEditorView(
			viewModel: FavoriteEmojisEditorViewModelMock(
				favorites: ["❤️", "😀", "🚀", "🎉", "🐶"],
				sortMode: .frequency,
				counts: ["🚀": 20, "🐶": 12, "😀": 5],
				isPlus: true
			)
		)
	}
	.preferredColorScheme(.dark)
}

#Preview("Free at limit") {
	NavigationStack {
		FavoriteEmojisEditorView(
			viewModel: FavoriteEmojisEditorViewModelMock(
				favorites: ["❤️", "😂", "👍", "🙏", "😍", "🔥"],
				isPlus: false
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
