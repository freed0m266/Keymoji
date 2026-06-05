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

	/// Distinct counts with a tie: banana=3, apple=2, cherry=2.
	/// Most-used order is therefore banana, then apple/cherry tie broken by word ASC.
	private func seedVaryingCounts(_ store: PersonalRecentsStore) {
		store.learn("apple", fromContextType: .prose, now: Date(timeIntervalSince1970: 100))
		store.learn("apple", fromContextType: .prose, now: Date(timeIntervalSince1970: 110))
		store.learn("banana", fromContextType: .prose, now: Date(timeIntervalSince1970: 200))
		store.learn("banana", fromContextType: .prose, now: Date(timeIntervalSince1970: 210))
		store.learn("banana", fromContextType: .prose, now: Date(timeIntervalSince1970: 220))
		store.learn("cherry", fromContextType: .prose, now: Date(timeIntervalSince1970: 300))
		store.learn("cherry", fromContextType: .prose, now: Date(timeIntervalSince1970: 310))
	}

	func testMostUsedSort_ordersByCountDescendingThenWord() {
		let store = makeStore()
		seedVaryingCounts(store)
		let vm = LearnedWordsEditorViewModel(store: store, sort: .mostUsed)
		XCTAssertEqual(vm.words.map(\.word), ["banana", "apple", "cherry"])
		XCTAssertEqual(vm.words.map(\.count), [3, 2, 2])
	}

	func testDefaultSort_isMostUsed() {
		let store = makeStore()
		seedVaryingCounts(store)
		// No explicit `sort:` argument → default must be `.mostUsed`.
		let vm = LearnedWordsEditorViewModel(store: store)
		XCTAssertEqual(vm.sort, .mostUsed)
		XCTAssertEqual(vm.words.map(\.word), ["banana", "apple", "cherry"])
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
