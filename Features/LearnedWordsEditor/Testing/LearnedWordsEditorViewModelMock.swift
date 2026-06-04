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

	public var sort: LearnedWordsSort {
		didSet { words = Self.sorted(words, by: sort) }
	}

	public init(words: [LearnedWord] = [], sort: LearnedWordsSort = .recency) {
		self.sort = sort
		self.words = Self.sorted(words, by: sort)
	}

	public func remove(at offsets: IndexSet) {
		words.remove(atOffsets: offsets)
	}

	public func clearAll() {
		words = []
	}

	private static func sorted(_ input: [LearnedWord], by sort: LearnedWordsSort) -> [LearnedWord] {
		switch sort {
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
