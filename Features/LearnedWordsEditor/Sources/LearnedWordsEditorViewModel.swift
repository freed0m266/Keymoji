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
	/// The displayed rows: sorted per `sort`, then filtered by `searchText`. With a large pool (task 73
	/// targets 10k) this is what the lazy `List` renders, so it stays navigable.
	var words: [LearnedWord] { get }
	/// Whether the underlying pool holds any learned word — including sub-threshold singletons hidden
	/// from `words` (task 77). Drives Clear All's availability so the purge escape hatch stays reachable
	/// even when every entry is below the display threshold and the list reads empty.
	var hasLearnedWords: Bool { get }
	var sort: LearnedWordsSort { get set }
	/// Case-insensitive substring filter over the learned words. Empty shows everything.
	var searchText: String { get set }
	/// Offsets into the *currently displayed* (sorted + filtered) array.
	func remove(at offsets: IndexSet)
	func clearAll()
}

@MainActor
public func learnedWordsEditorVM() -> some LearnedWordsEditorViewModeling {
	LearnedWordsEditorViewModel()
}

@Observable
final class LearnedWordsEditorViewModel: BaseViewModel, LearnedWordsEditorViewModeling {

	/// Displayed rows: `allWords` sorted, then filtered by `searchText`.
	private(set) var words: [LearnedWord] = []
	/// Mirrors whether the store holds *any* learned word, threshold notwithstanding — so Clear All
	/// stays reachable when the visible list is empty but hidden singletons remain.
	private(set) var hasLearnedWords: Bool = false
	/// The full sorted pool, kept in memory so re-sorting and filtering don't re-read the store. Loaded
	/// once on init; at the task-73 target (10k) the read is from the in-memory index and the sort is a
	/// one-time cost on screen open (not the typing hot path).
	private var allWords: [LearnedWord] = []

	var sort: LearnedWordsSort {
		didSet { applySortAndFilter() }
	}

	var searchText: String = "" {
		didSet { applyFilter() }
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
		// Map offsets to words from the *displayed* (sorted + filtered) array — store order is
		// dictionary-undefined, so deleting by index into the store would remove the wrong entries.
		let removed = offsets.map { words[$0].word }
		for word in removed { store.remove(word) }
		reload()
	}

	func clearAll() {
		store.clear()
		allWords = []
		words = []
		hasLearnedWords = false
	}

	// MARK: - Private API

	private func reload() {
		// Show only what the pool can actually offer (task 77): hide sub-threshold singletons so the
		// editor lists exactly the words `WordCompletionProvider` would surface. The same constant gates
		// the providers, so this stays one source of truth — tune `minSuggestCount` and the list follows.
		// The cut belongs here on `allWords` (not in `applyFilter()`, which is the search box) so search
		// and sort both run over the already-thresholded pool.
		let all = store.allLearnedWords()
		hasLearnedWords = !all.isEmpty
		let offerable = all.filter { $0.count >= WordCompletionProvider.minSuggestCount }
		allWords = sorted(offerable)
		applyFilter()
	}

	/// Re-sort the in-memory pool (no disk re-read) and reapply the active filter.
	private func applySortAndFilter() {
		allWords = sorted(allWords)
		applyFilter()
	}

	/// Project `allWords` to the displayed `words` through the case-insensitive substring filter.
	private func applyFilter() {
		let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
		words = query.isEmpty ? allWords : allWords.filter { $0.word.localizedCaseInsensitiveContains(query) }
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
