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

@Observable
@MainActor
public final class FavoriteEmojisEditorViewModelMock: FavoriteEmojisEditorViewModeling {
	public var favorites: [String]

	public init(favorites: [String] = ["❤️", "😀", "🚀"]) {
		self.favorites = favorites
	}

	public func toggle(_ emoji: String) {
		if let index = favorites.firstIndex(of: emoji) {
			favorites.remove(at: index)
		} else {
			favorites.append(emoji)
		}
	}

	public func remove(at offsets: IndexSet) {
		favorites.remove(atOffsets: offsets)
	}

	public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
		favorites.move(fromOffsets: source, toOffset: destination)
	}
}
#endif
