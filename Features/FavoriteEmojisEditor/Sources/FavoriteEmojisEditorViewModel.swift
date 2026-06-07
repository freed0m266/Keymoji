//
//  FavoriteEmojisEditorViewModel.swift
//  FavoriteEmojisEditor
//
//  Created by Martin Svoboda on 25.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation
import SwiftUI
import KeymojiCore

@MainActor
public protocol FavoriteEmojisEditorViewModeling: Observable, AnyObject {
	var favorites: [String] { get }
	/// How the favorites bar is ordered. Persisted cross-process; setting it notifies the keyboard.
	var sortMode: FavoritesSortMode { get set }
	/// Favorites in the order they'll appear in the bar — manual order, or frequency-sorted.
	var displayedFavorites: [String] { get }
	func toggle(_ emoji: String)
	func remove(at offsets: IndexSet)
	func move(fromOffsets source: IndexSet, toOffset destination: Int)
}

@MainActor
public func favoriteEmojisEditorVM() -> some FavoriteEmojisEditorViewModeling {
	FavoriteEmojisEditorViewModel()
}

@Observable
final class FavoriteEmojisEditorViewModel: BaseViewModel, FavoriteEmojisEditorViewModeling {

	private(set) var favorites: [String]

	var sortMode: FavoritesSortMode {
		didSet {
			guard sortMode != oldValue else { return }
			store.favoritesSortMode = sortMode
			notifier.post(.favoritesSortMode)
		}
	}

	/// Favorites in display order. In `.frequency` this differs from the stored manual order, so
	/// `remove`/`move` must map back to the stored array (see those methods).
	var displayedFavorites: [String] {
		FavoritesOrdering.ordered(favorites, counts: store.emojiUsageCounts, mode: sortMode)
	}

	private let store: AppGroupStore
	private let notifier: SettingsChangeNotifier

	// MARK: - Init

	init(
		store: AppGroupStore = .shared,
		notifier: SettingsChangeNotifier = .shared
	) {
		self.store = store
		self.notifier = notifier
		self.favorites = store.favoriteEmojis
		self.sortMode = store.favoritesSortMode
		super.init()
	}

	// MARK: - Public API

	func toggle(_ emoji: String) {
		if let index = favorites.firstIndex(of: emoji) {
			favorites.remove(at: index)
		} else {
			favorites.append(emoji)
		}
		persist()
	}

	func remove(at offsets: IndexSet) {
		// `offsets` index into `displayedFavorites`, which in `.frequency` is reordered relative to
		// the stored manual array — map each offset to its emoji and remove by value, not by index.
		let displayed = displayedFavorites
		let removed = offsets.compactMap { displayed.indices.contains($0) ? displayed[$0] : nil }
		favorites.removeAll { removed.contains($0) }
		persist()
	}

	func move(fromOffsets source: IndexSet, toOffset destination: Int) {
		// Reordering only makes sense in `.manual`; in `.frequency` the order is derived from counts
		// and the drag handle is hidden in the view, so this is a no-op safeguard.
		guard sortMode == .manual else { return }
		favorites.move(fromOffsets: source, toOffset: destination)
		persist()
	}

	// MARK: - Private API

	private func persist() {
		store.favoriteEmojis = favorites
		notifier.post(.favoriteEmojis)
	}
}
