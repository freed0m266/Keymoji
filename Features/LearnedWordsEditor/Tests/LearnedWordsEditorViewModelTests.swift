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

	private var tempDirs: [URL] = []

	override func tearDown() {
		for dir in tempDirs { try? FileManager.default.removeItem(at: dir) }
		tempDirs = []
		super.tearDown()
	}

	/// An isolated, file-backed store in a throwaway temp directory (task 73). Using the directory init
	/// — not `PersonalRecentsStore(store:)` — keeps each test's pool separate; the production init shares
	/// one in-memory index per App Group container, which would cross-contaminate tests.
	private func makeStore() -> PersonalRecentsStore {
		let dir = FileManager.default.temporaryDirectory
			.appendingPathComponent("keymoji.tests.learnedWordsEditor.\(UUID().uuidString)", isDirectory: true)
		try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		tempDirs.append(dir)
		return PersonalRecentsStore(directory: dir)
	}

	private func seed(_ store: PersonalRecentsStore) {
		// Each word learned twice so it clears the editor's display threshold (task 77 hides count == 1).
		// Distinct last-used ordering preserved: banana (newest) → cherry → apple (oldest).
		store.learn("apple", fromContextType: .prose, now: Date(timeIntervalSince1970: 100))
		store.learn("apple", fromContextType: .prose, now: Date(timeIntervalSince1970: 105))
		store.learn("cherry", fromContextType: .prose, now: Date(timeIntervalSince1970: 200))
		store.learn("cherry", fromContextType: .prose, now: Date(timeIntervalSince1970: 205))
		store.learn("banana", fromContextType: .prose, now: Date(timeIntervalSince1970: 300))
		store.learn("banana", fromContextType: .prose, now: Date(timeIntervalSince1970: 305))
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

	func testSearch_filtersByCaseInsensitiveSubstring() {
		let store = makeStore()
		seed(store) // apple, banana, cherry
		let vm = LearnedWordsEditorViewModel(store: store, sort: .alphabetical)

		vm.searchText = "an"
		XCTAssertEqual(vm.words.map(\.word), ["banana"])

		vm.searchText = "E" // case-insensitive: apple, cherry both contain "e"
		XCTAssertEqual(vm.words.map(\.word), ["apple", "cherry"])

		vm.searchText = ""
		XCTAssertEqual(vm.words.map(\.word), ["apple", "banana", "cherry"])
	}

	func testSearch_thenRemove_deletesTheFilteredWord() {
		let store = makeStore()
		seed(store)
		let vm = LearnedWordsEditorViewModel(store: store, sort: .alphabetical)
		vm.searchText = "an" // [banana]
		vm.remove(at: IndexSet(integer: 0))
		// Filter still active; banana is gone, nothing else matches "an".
		XCTAssertTrue(vm.words.isEmpty)
		XCTAssertEqual(store.count, 2)
	}

	// MARK: - Display threshold (task 77 — list shows only what the pool can offer)

	func testBelowThreshold_hiddenFromList() {
		let store = makeStore()
		store.learn("typo", fromContextType: .prose, now: Date(timeIntervalSince1970: 100)) // count 1 → hidden
		store.learn("apple", fromContextType: .prose, now: Date(timeIntervalSince1970: 200))
		store.learn("apple", fromContextType: .prose, now: Date(timeIntervalSince1970: 210)) // count 2 → shown
		let vm = LearnedWordsEditorViewModel(store: store, sort: .mostUsed)
		XCTAssertEqual(vm.words.map(\.word), ["apple"], "the count-1 singleton is hidden; the count-2 word shows")
		XCTAssertEqual(store.count, 2, "but both stay in the pool — the cut is display-only")
	}

	func testThreshold_tiedToMinSuggestCount() {
		// The boundary is exactly `minSuggestCount`, read from the same constant the providers use:
		// a word at the threshold shows, one below hides. If the constant moves, this follows.
		let store = makeStore()
		for i in 0..<WordCompletionProvider.minSuggestCount {
			store.learn("exact", fromContextType: .prose, now: Date(timeIntervalSince1970: Double(100 + i)))
		}
		for i in 0..<(WordCompletionProvider.minSuggestCount - 1) {
			store.learn("below", fromContextType: .prose, now: Date(timeIntervalSince1970: Double(200 + i)))
		}
		let vm = LearnedWordsEditorViewModel(store: store, sort: .alphabetical)
		XCTAssertEqual(vm.words.map(\.word), ["exact"])
	}

	func testPoolOfOnlySingletons_listEmptyButPoolKept() {
		// Every word is sub-threshold → the list is empty (the view shows its empty state), yet the pool
		// still holds them so Clear All can purge them. Asserts the new invariant without crashing.
		let store = makeStore()
		store.learn("alpha", fromContextType: .prose, now: Date(timeIntervalSince1970: 100))
		store.learn("beta", fromContextType: .prose, now: Date(timeIntervalSince1970: 200))
		let vm = LearnedWordsEditorViewModel(store: store)
		XCTAssertTrue(vm.words.isEmpty)
		XCTAssertTrue(vm.hasLearnedWords, "the pool is non-empty, so Clear All must stay reachable")
		XCTAssertEqual(store.count, 2)
		vm.clearAll()
		XCTAssertEqual(store.count, 0, "Clear All purges the hidden singletons too")
		XCTAssertFalse(vm.hasLearnedWords, "after purge the pool is empty")
	}

	func testEmptyPool_hasNoLearnedWords() {
		// A genuinely empty pool exposes `hasLearnedWords == false` so Clear All stays hidden.
		let vm = LearnedWordsEditorViewModel(store: makeStore())
		XCTAssertTrue(vm.words.isEmpty)
		XCTAssertFalse(vm.hasLearnedWords)
	}
}
