//
//  FavoritesEditorViewModel.swift
//  Settings
//
//  Created by Martin Svoboda on 25.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation
import SwiftUI
import KeyboCore

@MainActor
public protocol FavoritesEditorViewModeling: Observable, AnyObject {
	var favorites: [String] { get }
	func toggle(_ emoji: String)
	func remove(at offsets: IndexSet)
	func move(fromOffsets source: IndexSet, toOffset destination: Int)
}

@MainActor
public func favoritesEditorVM() -> FavoritesEditorViewModel {
	FavoritesEditorViewModel()
}

@Observable
public final class FavoritesEditorViewModel: BaseViewModel, FavoritesEditorViewModeling {

	public private(set) var favorites: [String]

	private let store: AppGroupStore
	private let notifier: SettingsChangeNotifier

	public init(
		store: AppGroupStore = .shared,
		notifier: SettingsChangeNotifier = .shared
	) {
		self.store = store
		self.notifier = notifier
		self.favorites = store.favoriteEmojis
		super.init()
	}

	public func toggle(_ emoji: String) {
		if let index = favorites.firstIndex(of: emoji) {
			favorites.remove(at: index)
		} else {
			favorites.append(emoji)
		}
		persist()
	}

	public func remove(at offsets: IndexSet) {
		favorites.remove(atOffsets: offsets)
		persist()
	}

	public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
		favorites.move(fromOffsets: source, toOffset: destination)
		persist()
	}

	private func persist() {
		store.favoriteEmojis = favorites
		notifier.post(.favoriteEmojis)
	}
}
