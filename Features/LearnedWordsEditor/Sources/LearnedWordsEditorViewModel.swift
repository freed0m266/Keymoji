//
//  LearnedWordsEditorViewModel.swift
//  LearnedWordsEditor
//
//  Created by Martin Svoboda on 03.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation
import SwiftUI
import KeymojiCore
import KeyboardCore

/// Sort order for the learned-words list. View-level state owned by the view model.
public enum LearnedWordsSort: Sendable, Hashable {
	/// Most-written first (default).
	case mostUsed
	/// Last-used first.
	case recency
	/// A→Z, case-insensitive.
	case alphabetical
}

@MainActor
public protocol LearnedWordsEditorViewModeling: Observable, AnyObject {
	/// Already sorted per `sort`.
	var words: [LearnedWord] { get }
	var sort: LearnedWordsSort { get set }
	/// Offsets into the *currently displayed* (sorted) array.
	func remove(at offsets: IndexSet)
	func clearAll()
}

@MainActor
public func learnedWordsEditorVM() -> some LearnedWordsEditorViewModeling {
	LearnedWordsEditorViewModel()
}

@Observable
final class LearnedWordsEditorViewModel: BaseViewModel, LearnedWordsEditorViewModeling {

	private(set) var words: [LearnedWord] = []

	var sort: LearnedWordsSort {
		didSet { applySort() }
	}

	private let store: PersonalRecentsStore

	// MARK: - Init

	init(
		store: PersonalRecentsStore = PersonalRecentsStore(store: .shared),
		sort: LearnedWordsSort = .mostUsed
	) {
		self.store = store
		self.sort = sort
		super.init()
		reload()
	}

	// MARK: - Public API

	func remove(at offsets: IndexSet) {
		// Map offsets to words from the *displayed* array — store order is dictionary-undefined,
		// so deleting by index into the store would remove the wrong entries.
		let removed = offsets.map { words[$0].word }
		for word in removed { store.remove(word) }
		reload()
	}

	func clearAll() {
		store.clear()
		words = []
	}

	// MARK: - Private API

	private func reload() {
		words = sorted(store.allLearnedWords())
	}

	/// Re-sort the in-memory list without re-reading from disk.
	private func applySort() {
		words = sorted(words)
	}

	private func sorted(_ input: [LearnedWord]) -> [LearnedWord] {
		switch sort {
		case .mostUsed:
			return input.sorted {
				if $0.count != $1.count { return $0.count > $1.count }
				return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
			}
		case .recency:
			return input.sorted {
				if $0.lastUsed != $1.lastUsed { return $0.lastUsed > $1.lastUsed }
				return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
			}
		case .alphabetical:
			return input.sorted { $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending }
		}
	}
}
