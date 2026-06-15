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
import Paywall

@MainActor
public protocol FavoriteEmojisEditorViewModeling: Observable, AnyObject {
	var favorites: [String] { get }
	/// How the favorites bar is ordered. Persisted cross-process; changing it notifies the keyboard.
	/// Read-only here — go through `setSortMode(_:)` so the Plus gate can intercept `.frequency`.
	var sortMode: FavoritesSortMode { get }
	/// Favorites in the order they'll appear in the bar — manual order, or frequency-sorted.
	var displayedFavorites: [String] { get }
	/// Whether the user owns Keymoji Plus (drives the favorites limit and frequency-sort gates).
	var isPlus: Bool { get }
	/// Whether a free user has room for another favorite (always true for Plus).
	var canAddMoreFavorites: Bool { get }
	/// The free favorites cap, surfaced for the "X of Y used" upsell caption.
	var freeFavoritesLimit: Int { get }
	/// Non-nil while a paywall should be presented; the entry point drives the headline. Settable so a
	/// SwiftUI `.sheet(item:)` can clear it on dismiss.
	var paywallContext: PaywallContext? { get set }

	func toggle(_ emoji: String)
	func remove(at offsets: IndexSet)
	func move(fromOffsets source: IndexSet, toOffset destination: Int)
	/// Change the sort mode. Selecting `.frequency` without Plus is rejected and opens the paywall.
	func setSortMode(_ newValue: FavoritesSortMode)
	/// Explicitly open the paywall (e.g. tapping the "unlock unlimited" upsell row).
	func requestPaywall(_ context: PaywallContext)
}

@MainActor
public func favoriteEmojisEditorVM() -> some FavoriteEmojisEditorViewModeling {
	FavoriteEmojisEditorViewModel(purchaseService: PurchaseService.shared)
}

@Observable
final class FavoriteEmojisEditorViewModel: BaseViewModel, FavoriteEmojisEditorViewModeling {

	private(set) var favorites: [String]
	private(set) var sortMode: FavoritesSortMode
	var paywallContext: PaywallContext?

	let freeFavoritesLimit = FavoritesEntitlement.freeFavoritesLimit

	var isPlus: Bool { purchaseService.isPlus }

	var canAddMoreFavorites: Bool {
		FavoritesEntitlement.canAddFavorite(currentCount: favorites.count, isPlus: isPlus)
	}

	/// Favorites in display order. In `.frequency` this differs from the stored manual order, so
	/// `remove`/`move` must map back to the stored array (see those methods). The editor shows every
	/// stored favorite even past the free limit (so a downgraded user can trim); only *adding* is gated.
	var displayedFavorites: [String] {
		FavoritesOrdering.ordered(favorites, counts: store.emojiUsageCounts, mode: sortMode)
	}

	private let store: AppGroupStore
	private let notifier: SettingsChangeNotifier
	private let purchaseService: any PurchaseServicing

	// MARK: - Init

	init(
		store: AppGroupStore = .shared,
		notifier: SettingsChangeNotifier = .shared,
		purchaseService: any PurchaseServicing
	) {
		self.store = store
		self.notifier = notifier
		self.purchaseService = purchaseService
		self.favorites = store.favoriteEmojis
		// Free users can't be in `.frequency` (Plus-only); fall back so a stale stored value can't show
		// the keyboard a locked mode. Plus users keep their chosen mode.
		let stored = store.favoritesSortMode
		self.sortMode = (stored == .frequency && !purchaseService.isPlus) ? .manual : stored
		super.init()
	}

	// MARK: - Public API

	func toggle(_ emoji: String) {
		if let index = favorites.firstIndex(of: emoji) {
			favorites.remove(at: index)   // removing is always allowed
			persist()
		} else {
			guard canAddMoreFavorites else {
				// Hit the free cap — invite to Plus instead of silently dropping the tap.
				requestPaywall(.favoritesLimit)
				return
			}
			favorites.append(emoji)
			persist()
		}
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

	func setSortMode(_ newValue: FavoritesSortMode) {
		guard newValue != sortMode else { return }
		// Frequency auto-sort is Plus-only. Reject the switch and open the paywall; the segmented
		// control snaps back to `.manual` because `sortMode` never changed.
		if newValue == .frequency, !isPlus {
			requestPaywall(.frequencySort)
			return
		}
		sortMode = newValue
		store.favoritesSortMode = sortMode
		notifier.post(.favoritesSortMode)
	}

	func requestPaywall(_ context: PaywallContext) {
		paywallContext = context
	}

	// MARK: - Private API

	private func persist() {
		store.favoriteEmojis = favorites
		notifier.post(.favoriteEmojis)
	}
}
