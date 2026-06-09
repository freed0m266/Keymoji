//
//  LearnedWordsEditorSnapshots.swift
//  LearnedWordsEditor_Tests
//
//  Created by Martin Svoboda on 03.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import XCTest
import SwiftUI
import SnapshotTesting
import KeyboardCore
@testable import LearnedWordsEditor

@MainActor
final class LearnedWordsEditorSnapshots: XCTestCase {

	private static let size = CGSize(width: 393, height: 852)

	// Stored lowercase (the store's canonical form); the row renders each with a leading capital,
	// including the accented "čauko" → "Čauko".
	private static let sampleWords: [LearnedWord] = [
		LearnedWord(word: "keyboard", count: 12, lastUsed: 1_700_000_300),
		LearnedWord(word: "emoji", count: 8, lastUsed: 1_700_000_500),
		LearnedWord(word: "hello", count: 5, lastUsed: 1_700_000_100),
		LearnedWord(word: "čauko", count: 4, lastUsed: 1_700_000_600),
		LearnedWord(word: "suggestion", count: 3, lastUsed: 1_700_000_400),
		LearnedWord(word: "typing", count: 2, lastUsed: 1_700_000_200)
	]

	func testLearnedWordsEditor_mostUsed_dark() {
		let view = NavigationStack {
			LearnedWordsEditorView(
				viewModel: LearnedWordsEditorViewModelMock(words: Self.sampleWords, sort: .mostUsed)
			)
		}
		.preferredColorScheme(.dark)
		assertSnapshot(view)
	}

	func testLearnedWordsEditor_recency_dark() {
		let view = NavigationStack {
			LearnedWordsEditorView(
				viewModel: LearnedWordsEditorViewModelMock(words: Self.sampleWords, sort: .recency)
			)
		}
		.preferredColorScheme(.dark)
		assertSnapshot(view)
	}

	func testLearnedWordsEditor_alphabetical_dark() {
		let view = NavigationStack {
			LearnedWordsEditorView(
				viewModel: LearnedWordsEditorViewModelMock(words: Self.sampleWords, sort: .alphabetical)
			)
		}
		.preferredColorScheme(.dark)
		assertSnapshot(view)
	}

	func testLearnedWordsEditor_empty_dark() {
		let view = NavigationStack {
			LearnedWordsEditorView(viewModel: LearnedWordsEditorViewModelMock(words: []))
		}
		.preferredColorScheme(.dark)
		assertSnapshot(view)
	}

	private func assertSnapshot<V: View>(
		_ view: V,
		record: Bool = false,
		file: StaticString = #filePath,
		testName: String = #function,
		line: UInt = #line
	) {
		let host = view.frame(width: Self.size.width, height: Self.size.height)
		SnapshotTesting.assertSnapshot(
			of: host,
			as: .image(
				drawHierarchyInKeyWindow: false,
				perceptualPrecision: 0.93,
				layout: .fixed(width: Self.size.width, height: Self.size.height),
				traits: .init(userInterfaceStyle: .dark)
			),
			record: record,
			file: file,
			testName: testName + "_dark",
			line: line
		)
	}
}
