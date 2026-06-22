//
//  LearnedWordsEditorViewModelMock.swift
//  LearnedWordsEditor
//
//  Created by Martin Svoboda on 03.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

#if DEBUG
import Foundation
import SwiftUI
import KeyboardCore

@Observable
@MainActor
public final class LearnedWordsEditorViewModelMock: LearnedWordsEditorViewModeling {
	public private(set) var words: [LearnedWord] = []
	private var allWords: [LearnedWord] = []

	public var sort: LearnedWordsSort {
		didSet { applySortAndFilter() }
	}

	public var searchText: String = "" {
		didSet { applyFilter() }
	}

	public init(words: [LearnedWord] = [], sort: LearnedWordsSort = .mostUsed) {
		self.sort = sort
		self.allWords = Self.sorted(words, by: sort)
		self.words = allWords
	}

	public func remove(at offsets: IndexSet) {
		let removed = offsets.map { words[$0].word }
		allWords.removeAll { removed.contains($0.word) }
		applyFilter()
	}

	public func clearAll() {
		allWords = []
		words = []
	}

	private func applySortAndFilter() {
		allWords = Self.sorted(allWords, by: sort)
		applyFilter()
	}

	private func applyFilter() {
		let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
		words = query.isEmpty ? allWords : allWords.filter { $0.word.localizedCaseInsensitiveContains(query) }
	}

	private static func sorted(_ input: [LearnedWord], by sort: LearnedWordsSort) -> [LearnedWord] {
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
#endif
