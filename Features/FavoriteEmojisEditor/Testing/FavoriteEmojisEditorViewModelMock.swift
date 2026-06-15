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
	public private(set) var sortMode: FavoritesSortMode
	public var isPlus: Bool
	public var paywallContext: PaywallContext?

	public let freeFavoritesLimit = FavoritesEntitlement.freeFavoritesLimit

	private let counts: [String: Int]

	public var canAddMoreFavorites: Bool {
		FavoritesEntitlement.canAddFavorite(currentCount: favorites.count, isPlus: isPlus)
	}

	public var displayedFavorites: [String] {
		FavoritesOrdering.ordered(favorites, counts: counts, mode: sortMode)
	}

	public init(
		favorites: [String] = ["❤️", "😀", "🚀"],
		sortMode: FavoritesSortMode = .manual,
		counts: [String: Int] = [:],
		isPlus: Bool = true
	) {
		self.favorites = favorites
		self.sortMode = sortMode
		self.counts = counts
		self.isPlus = isPlus
	}

	public func toggle(_ emoji: String) {
		if let index = favorites.firstIndex(of: emoji) {
			favorites.remove(at: index)
		} else {
			guard canAddMoreFavorites else {
				paywallContext = .favoritesLimit
				return
			}
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

	public func setSortMode(_ newValue: FavoritesSortMode) {
		guard newValue != sortMode else { return }
		if newValue == .frequency, !isPlus {
			paywallContext = .frequencySort
			return
		}
		sortMode = newValue
	}

	public func requestPaywall(_ context: PaywallContext) {
		paywallContext = context
	}
}
#endif
