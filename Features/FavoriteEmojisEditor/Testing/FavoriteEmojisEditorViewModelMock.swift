//
//  FavoriteEmojisEditorViewModelMock.swift
//  FavoriteEmojisEditor
//
//  Created by Martin Svoboda on 25.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

#if DEBUG
import Foundation
import SwiftUI
import KeymojiCore

@Observable
@MainActor
public final class FavoriteEmojisEditorViewModelMock: FavoriteEmojisEditorViewModeling {
	public var favorites: [String]
	public var sortMode: FavoritesSortMode

	private let counts: [String: Int]

	public var displayedFavorites: [String] {
		FavoritesOrdering.ordered(favorites, counts: counts, mode: sortMode)
	}

	public init(
		favorites: [String] = ["❤️", "😀", "🚀"],
		sortMode: FavoritesSortMode = .manual,
		counts: [String: Int] = [:]
	) {
		self.favorites = favorites
		self.sortMode = sortMode
		self.counts = counts
	}

	public func toggle(_ emoji: String) {
		if let index = favorites.firstIndex(of: emoji) {
			favorites.remove(at: index)
		} else {
			favorites.append(emoji)
		}
	}

	public func remove(at offsets: IndexSet) {
		let displayed = displayedFavorites
		let removed = offsets.compactMap { displayed.indices.contains($0) ? displayed[$0] : nil }
		favorites.removeAll { removed.contains($0) }
	}

	public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
		guard sortMode == .manual else { return }
		favorites.move(fromOffsets: source, toOffset: destination)
	}
}
#endif
