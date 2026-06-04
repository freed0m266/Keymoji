//
//  LearnedWordsEditorViewModelTests.swift
//  LearnedWordsEditor_Tests
//
//  Created by Martin Svoboda on 03.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import XCTest
import KeymojiCore
import KeyboardCore
@testable import LearnedWordsEditor

@MainActor
final class LearnedWordsEditorViewModelTests: XCTestCase {

	private func makeStore() -> PersonalRecentsStore {
		let suite = "keymoji.tests.learnedWordsEditor.\(UUID().uuidString)"
		return PersonalRecentsStore(store: AppGroupStore(suiteName: suite))
	}

	private func seed(_ store: PersonalRecentsStore) {
		// Distinct last-used ordering: banana (newest) → cherry → apple (oldest).
		store.learn("apple", fromContextType: .prose, now: Date(timeIntervalSince1970: 100))
		store.learn("cherry", fromContextType: .prose, now: Date(timeIntervalSince1970: 200))
		store.learn("banana", fromContextType: .prose, now: Date(timeIntervalSince1970: 300))
	}

	func testRecencySort_ordersByLastUsedDescending() {
		let store = makeStore()
		seed(store)
		let vm = LearnedWordsEditorViewModel(store: store, sort: .recency)
		XCTAssertEqual(vm.words.map(\.word), ["banana", "cherry", "apple"])
	}

	func testAlphabeticalSort_ordersCaseInsensitively() {
		let store = makeStore()
		seed(store)
		let vm = LearnedWordsEditorViewModel(store: store, sort: .recency)
		vm.sort = .alphabetical
		XCTAssertEqual(vm.words.map(\.word), ["apple", "banana", "cherry"])
	}

	func testRemoveAt_deletesTheDisplayedWord() {
		let store = makeStore()
		seed(store)
		let vm = LearnedWordsEditorViewModel(store: store, sort: .recency)
		// Displayed: [banana, cherry, apple]. Delete index 0 → banana.
		vm.remove(at: IndexSet(integer: 0))
		XCTAssertEqual(vm.words.map(\.word), ["cherry", "apple"])
		XCTAssertEqual(store.count, 2)
	}

	func testClearAll_emptiesStoreAndList() {
		let store = makeStore()
		seed(store)
		let vm = LearnedWordsEditorViewModel(store: store, sort: .recency)
		vm.clearAll()
		XCTAssertTrue(vm.words.isEmpty)
		XCTAssertEqual(store.count, 0)
	}
}
