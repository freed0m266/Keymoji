//
//  FavoriteEmojisEditorViewModelTests.swift
//  FavoriteEmojisEditor_Tests
//
//  Created by Martin Svoboda on 06.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import XCTest
import KeymojiCore
@testable import FavoriteEmojisEditor

@MainActor
final class FavoriteEmojisEditorViewModelTests: XCTestCase {

	private func makeStore() -> AppGroupStore {
		AppGroupStore(suiteName: "keymoji.tests.favoriteEmojisEditor.\(UUID().uuidString)")
	}

	// MARK: - Defaults

	func testSortMode_defaultsToManual() {
		let vm = FavoriteEmojisEditorViewModel(store: makeStore())
		XCTAssertEqual(vm.sortMode, .manual)
	}

	func testInit_readsSortModeFromStore() {
		let store = makeStore()
		store.favoritesSortMode = .frequency
		let vm = FavoriteEmojisEditorViewModel(store: store)
		XCTAssertEqual(vm.sortMode, .frequency)
	}

	// MARK: - Sort mode persistence + notification

	// Darwin notifications round-trip within a single process, so post → observe proves the
	// live-propagation wiring (same approach as SettingsChangeNotifierTests).
	func testSettingSortMode_persistsAndPostsNotification() async {
		let store = makeStore()
		let notifier = SettingsChangeNotifier()
		let vm = FavoriteEmojisEditorViewModel(store: store, notifier: notifier)
		let fired = expectation(description: "favoritesSortMode notification fires")
		let token = notifier.addObserver(for: .favoritesSortMode) { fired.fulfill() }

		vm.sortMode = .frequency

		await fulfillment(of: [fired], timeout: 2.0)
		XCTAssertEqual(store.favoritesSortMode, .frequency)
		_ = token
	}

	func testSettingSortMode_toSameValue_doesNotPost() async {
		let store = makeStore()
		let notifier = SettingsChangeNotifier()
		let vm = FavoriteEmojisEditorViewModel(store: store, notifier: notifier)
		let unwanted = expectation(description: "no notification on no-op set")
		unwanted.isInverted = true
		let token = notifier.addObserver(for: .favoritesSortMode) { unwanted.fulfill() }

		vm.sortMode = .manual   // already manual

		await fulfillment(of: [unwanted], timeout: 0.5)
		_ = token
	}

	// MARK: - Displayed favorites

	func testDisplayedFavorites_manual_matchesStoredOrder() {
		let store = makeStore()
		store.favoriteEmojis = ["❤️", "😀", "🚀"]
		store.emojiUsageCounts = ["🚀": 10]
		let vm = FavoriteEmojisEditorViewModel(store: store)
		XCTAssertEqual(vm.displayedFavorites, ["❤️", "😀", "🚀"])
	}

	func testDisplayedFavorites_frequency_ordersByCount() {
		let store = makeStore()
		store.favoriteEmojis = ["❤️", "😀", "🚀"]
		store.emojiUsageCounts = ["🚀": 10, "❤️": 2, "😀": 5]
		store.favoritesSortMode = .frequency
		let vm = FavoriteEmojisEditorViewModel(store: store)
		XCTAssertEqual(vm.displayedFavorites, ["🚀", "😀", "❤️"])
	}

	// MARK: - Remove maps displayed offset → emoji (regression: not stored index)

	func testRemove_inFrequency_deletesCorrectEmoji() {
		let store = makeStore()
		store.favoriteEmojis = ["❤️", "😀", "🚀"]   // stored (manual) order
		store.emojiUsageCounts = ["🚀": 10, "❤️": 2, "😀": 5]
		store.favoritesSortMode = .frequency
		let vm = FavoriteEmojisEditorViewModel(store: store)
		// Displayed: [🚀, 😀, ❤️]. Delete index 0 → must remove 🚀, not stored[0] (❤️).
		vm.remove(at: IndexSet(integer: 0))
		XCTAssertEqual(vm.favorites, ["❤️", "😀"])
		XCTAssertEqual(store.favoriteEmojis, ["❤️", "😀"])
	}

	func testRemove_inManual_deletesByOffset() {
		let store = makeStore()
		store.favoriteEmojis = ["❤️", "😀", "🚀"]
		let vm = FavoriteEmojisEditorViewModel(store: store)
		vm.remove(at: IndexSet(integer: 1))   // 😀
		XCTAssertEqual(vm.favorites, ["❤️", "🚀"])
	}

	// MARK: - Move only mutates in manual mode

	func testMove_inFrequency_isNoOp() {
		let store = makeStore()
		store.favoriteEmojis = ["❤️", "😀", "🚀"]
		store.favoritesSortMode = .frequency
		let vm = FavoriteEmojisEditorViewModel(store: store)
		vm.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
		XCTAssertEqual(vm.favorites, ["❤️", "😀", "🚀"])
	}

	func testMove_inManual_reorders() {
		let store = makeStore()
		store.favoriteEmojis = ["❤️", "😀", "🚀"]
		let vm = FavoriteEmojisEditorViewModel(store: store)
		vm.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
		XCTAssertEqual(vm.favorites, ["😀", "🚀", "❤️"])
	}
}
