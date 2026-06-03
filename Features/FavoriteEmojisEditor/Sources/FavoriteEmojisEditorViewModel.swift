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
		favorites.remove(atOffsets: offsets)
		persist()
	}

	func move(fromOffsets source: IndexSet, toOffset destination: Int) {
		favorites.move(fromOffsets: source, toOffset: destination)
		persist()
	}

	// MARK: - Private API

	private func persist() {
		store.favoriteEmojis = favorites
		notifier.post(.favoriteEmojis)
	}
}
