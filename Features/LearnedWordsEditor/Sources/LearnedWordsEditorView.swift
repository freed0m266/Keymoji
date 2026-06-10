//
//  LearnedWordsEditorView.swift
//  LearnedWordsEditor
//
//  Created by Martin Svoboda on 03.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import KeyboardCore
import KeymojiResources

public struct LearnedWordsEditorView<ViewModel: LearnedWordsEditorViewModeling>: View {
	@State private var viewModel: ViewModel
	@State private var showClearAllAlert = false

	typealias Texts = L10n.Settings.LearnedWords

	public init(viewModel: ViewModel) {
		_viewModel = State(initialValue: viewModel)
	}

	public var body: some View {
		@Bindable var viewModel = viewModel
		return Group {
			if viewModel.words.isEmpty {
				emptyState
			} else {
				List {
					Section {
						Picker(Texts.title, selection: $viewModel.sort) {
							Text(Texts.Sort.mostUsed).tag(LearnedWordsSort.mostUsed)
							Text(Texts.Sort.recency).tag(LearnedWordsSort.recency)
							Text(Texts.Sort.alphabetical).tag(LearnedWordsSort.alphabetical)
						}
						.pickerStyle(.segmented)
						.labelsHidden()
					}
					Section {
						ForEach(viewModel.words, id: \.word) { row(for: $0) }
							.onDelete { viewModel.remove(at: $0) }
					} footer: {
						Text(Texts.listFooter)
					}
				}
			}
		}
		.navigationTitle(Texts.title)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			if !viewModel.words.isEmpty {
				ToolbarItem(placement: .topBarLeading) {
					EditButton()
				}
				ToolbarItem(placement: .topBarTrailing) {
					Button(role: .destructive) {
						showClearAllAlert = true
					} label: {
						Text(Texts.clearAll)
					}
				}
			}
		}
		.alert(Texts.clearAlertTitle, isPresented: $showClearAllAlert) {
			Button(Texts.clearAlertConfirm, role: .destructive) { viewModel.clearAll() }
			Button(L10n.General.cancel, role: .cancel) {}
		} message: {
			Text(Texts.clearAlertMessage)
		}
	}

	private var emptyState: some View {
		ContentUnavailableView {
			Label(Texts.emptyTitle, systemImage: "text.book.closed")
		} description: {
			Text(Texts.emptyMessage)
		}
	}

	private func row(for word: LearnedWord) -> some View {
		HStack {
			Text(word.word)
			Spacer()
			Text(Texts.count(word.count))
				.foregroundStyle(.secondary)
		}
		.accessibilityElement()
		.accessibilityLabel(Texts.accessibilityLabel(word.word, word.count))
	}
}

#if DEBUG
private let sampleWords: [LearnedWord] = [
	LearnedWord(word: "keyboard", count: 12, lastUsed: 1_700_000_300),
	LearnedWord(word: "emoji", count: 8, lastUsed: 1_700_000_500),
	LearnedWord(word: "hello", count: 5, lastUsed: 1_700_000_100),
	LearnedWord(word: "čauko", count: 4, lastUsed: 1_700_000_600),
	LearnedWord(word: "suggestion", count: 3, lastUsed: 1_700_000_400),
	LearnedWord(word: "typing", count: 2, lastUsed: 1_700_000_200)
]

#Preview("Most used") {
	NavigationStack {
		LearnedWordsEditorView(
			viewModel: LearnedWordsEditorViewModelMock(words: sampleWords, sort: .mostUsed)
		)
	}
	.preferredColorScheme(.dark)
}

#Preview("Recently used") {
	NavigationStack {
		LearnedWordsEditorView(
			viewModel: LearnedWordsEditorViewModelMock(words: sampleWords, sort: .recency)
		)
	}
	.preferredColorScheme(.dark)
}

#Preview("Alphabetical") {
	NavigationStack {
		LearnedWordsEditorView(
			viewModel: LearnedWordsEditorViewModelMock(words: sampleWords, sort: .alphabetical)
		)
	}
	.preferredColorScheme(.dark)
}

#Preview("Empty") {
	NavigationStack {
		LearnedWordsEditorView(viewModel: LearnedWordsEditorViewModelMock(words: []))
	}
	.preferredColorScheme(.dark)
}
#endif
