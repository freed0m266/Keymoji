//
//  FavoriteEmojisEditorViewModelTests.swift
//  FavoriteEmojisEditor_Tests
//
//  Created by Martin Svoboda on 06.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import XCTest
import KeymojiCore
import Paywall
@testable import FavoriteEmojisEditor

@MainActor
final class FavoriteEmojisEditorViewModelTests: XCTestCase {

	private func makeStore() -> AppGroupStore {
		AppGroupStore(suiteName: "keymoji.tests.favoriteEmojisEditor.\(UUID().uuidString)")
	}

	private func makeVM(
		store: AppGroupStore,
		notifier: SettingsChangeNotifier = .shared,
		isPlus: Bool = true,
		promoStore: any PromoTrialStoring = PromoTrialStore(backing: InMemoryPromoBacking())
	) -> FavoriteEmojisEditorViewModel {
		FavoriteEmojisEditorViewModel(
			store: store,
			notifier: notifier,
			purchaseService: PurchaseServiceMock(isPlus: isPlus),
			promoStore: promoStore
		)
	}

	// MARK: - Defaults

	func testSortMode_defaultsToManual() {
		let vm = makeVM(store: makeStore())
		XCTAssertEqual(vm.sortMode, .manual)
	}

	func testInit_readsSortModeFromStore_whenPlus() {
		let store = makeStore()
		store.favoritesSortMode = .frequency
		let vm = makeVM(store: store, isPlus: true)
		XCTAssertEqual(vm.sortMode, .frequency)
	}

	func testInit_freeUser_fallsBackToManual_evenIfStoredFrequency() {
		let store = makeStore()
		store.favoritesSortMode = .frequency
		let vm = makeVM(store: store, isPlus: false)
		// A stale Plus-era `.frequency` must not survive a downgrade.
		XCTAssertEqual(vm.sortMode, .manual)
	}

	// MARK: - Sort mode persistence + notification (Plus)

	func testSettingSortMode_plus_persistsAndPostsNotification() async {
		let store = makeStore()
		let notifier = SettingsChangeNotifier()
		let vm = makeVM(store: store, notifier: notifier, isPlus: true)
		let fired = expectation(description: "favoritesSortMode notification fires")
		let token = notifier.addObserver(for: .favoritesSortMode) { fired.fulfill() }

		vm.setSortMode(.frequency)

		await fulfillment(of: [fired], timeout: 2.0)
		XCTAssertEqual(vm.sortMode, .frequency)
		XCTAssertEqual(store.favoritesSortMode, .frequency)
		_ = token
	}

	func testSettingSortMode_toSameValue_doesNotPost() async {
		let store = makeStore()
		let notifier = SettingsChangeNotifier()
		let vm = makeVM(store: store, notifier: notifier, isPlus: true)
		let unwanted = expectation(description: "no notification on no-op set")
		unwanted.isInverted = true
		let token = notifier.addObserver(for: .favoritesSortMode) { unwanted.fulfill() }

		vm.setSortMode(.manual)   // already manual

		await fulfillment(of: [unwanted], timeout: 0.5)
		_ = token
	}

	// MARK: - Frequency sort gate (Plus-only)

	func testSettingFrequency_freeUser_isRejectedAndOpensPaywall() {
		let store = makeStore()
		let vm = makeVM(store: store, isPlus: false)
		vm.setSortMode(.frequency)
		XCTAssertEqual(vm.sortMode, .manual)               // gate held
		XCTAssertEqual(vm.paywallContext, .frequencySort)  // invited to Plus
		XCTAssertEqual(store.favoritesSortMode, .manual)   // nothing persisted
	}

	// MARK: - Favorites limit gate

	func testAddFavorite_freeUserAtLimit_isBlockedAndOpensPaywall() {
		let store = makeStore()
		store.favoriteEmojis = ["❤️", "😂", "👍", "🙏", "😍", "🔥"]   // 6 = the free cap
		let vm = makeVM(store: store, isPlus: false)
		XCTAssertFalse(vm.canAddMoreFavorites)

		vm.toggle("🎉")   // 7th

		XCTAssertEqual(vm.favorites.count, FavoritesEntitlement.freeFavoritesLimit)
		XCTAssertFalse(vm.favorites.contains("🎉"))
		XCTAssertEqual(vm.paywallContext, .favoritesLimit)
		XCTAssertEqual(store.favoriteEmojis.count, FavoritesEntitlement.freeFavoritesLimit)
	}

	func testAddFavorite_freeUserBelowLimit_succeeds() {
		let store = makeStore()
		store.favoriteEmojis = ["❤️", "😂", "👍"]
		let vm = makeVM(store: store, isPlus: false)
		vm.toggle("🎉")
		XCTAssertEqual(vm.favorites, ["❤️", "😂", "👍", "🎉"])
		XCTAssertNil(vm.paywallContext)
	}

	func testRemoveFavorite_freeUserAtLimit_isAlwaysAllowed() {
		let store = makeStore()
		store.favoriteEmojis = ["❤️", "😂", "👍", "🙏", "😍", "🔥"]
		let vm = makeVM(store: store, isPlus: false)
		vm.toggle("🔥")   // remove existing — must not be gated
		XCTAssertFalse(vm.favorites.contains("🔥"))
		XCTAssertNil(vm.paywallContext)
	}

	func testAddFavorite_plusUser_canExceedLimit() {
		let store = makeStore()
		store.favoriteEmojis = ["❤️", "😂", "👍", "🙏", "😍", "🔥"]
		let vm = makeVM(store: store, isPlus: true)
		XCTAssertTrue(vm.canAddMoreFavorites)
		vm.toggle("🎉")
		XCTAssertEqual(vm.favorites.count, 7)
		XCTAssertNil(vm.paywallContext)
	}

	// MARK: - Loss-aversion (lapsed trial)

	/// Builds a promo store whose Welcome grant has lapsed (consumed, expiry in the past).
	private func lapsedTrialStore() -> PromoTrialStore {
		let promo = PromoTrialStore(backing: InMemoryPromoBacking())
		promo.consumeWelcome(now: Date(timeIntervalSinceNow: -60 * 24 * 60 * 60))   // 60 days ago → expired
		return promo
	}

	func testLossAversion_lapsedTrialOverCap_showsBannerAndRoutesAfterTrial() {
		let store = makeStore()
		store.favoriteEmojis = ["❤️", "😂", "👍", "🙏", "😍", "🔥", "🎉", "🥰"]   // 8 > free cap
		let vm = makeVM(store: store, isPlus: false, promoStore: lapsedTrialStore())

		XCTAssertTrue(vm.showLossAversionBanner)
		XCTAssertEqual(vm.lossAversionExtraCount, 2)

		vm.toggle("✨")   // adding past the cap → loss-aversion paywall, not the plain limit one
		XCTAssertEqual(vm.paywallContext, .afterTrial)
	}

	func testLossAversion_neverSubscribedFreeUser_usesPlainLimitPaywall() {
		let store = makeStore()
		store.favoriteEmojis = ["❤️", "😂", "👍", "🙏", "😍", "🔥"]   // at cap, no trial ever
		let vm = makeVM(store: store, isPlus: false)   // default empty promo store

		XCTAssertFalse(vm.showLossAversionBanner)
		vm.toggle("🎉")
		XCTAssertEqual(vm.paywallContext, .favoritesLimit)
	}

	func testLossAversion_plusUser_noBanner() {
		let store = makeStore()
		store.favoriteEmojis = ["❤️", "😂", "👍", "🙏", "😍", "🔥", "🎉", "🥰"]
		let vm = makeVM(store: store, isPlus: true, promoStore: lapsedTrialStore())
		XCTAssertFalse(vm.showLossAversionBanner)   // paid → no downgrade
	}

	// MARK: - Displayed favorites

	func testDisplayedFavorites_manual_matchesStoredOrder() {
		let store = makeStore()
		store.favoriteEmojis = ["❤️", "😀", "🚀"]
		store.emojiUsageCounts = ["🚀": 10]
		let vm = makeVM(store: store)
		XCTAssertEqual(vm.displayedFavorites, ["❤️", "😀", "🚀"])
	}

	func testDisplayedFavorites_frequency_ordersByCount() {
		let store = makeStore()
		store.favoriteEmojis = ["❤️", "😀", "🚀"]
		store.emojiUsageCounts = ["🚀": 10, "❤️": 2, "😀": 5]
		store.favoritesSortMode = .frequency
		let vm = makeVM(store: store, isPlus: true)
		XCTAssertEqual(vm.displayedFavorites, ["🚀", "😀", "❤️"])
	}

	// MARK: - Remove maps displayed offset → emoji (regression: not stored index)

	func testRemove_inFrequency_deletesCorrectEmoji() {
		let store = makeStore()
		store.favoriteEmojis = ["❤️", "😀", "🚀"]   // stored (manual) order
		store.emojiUsageCounts = ["🚀": 10, "❤️": 2, "😀": 5]
		store.favoritesSortMode = .frequency
		let vm = makeVM(store: store, isPlus: true)
		// Displayed: [🚀, 😀, ❤️]. Delete index 0 → must remove 🚀, not stored[0] (❤️).
		vm.remove(at: IndexSet(integer: 0))
		XCTAssertEqual(vm.favorites, ["❤️", "😀"])
		XCTAssertEqual(store.favoriteEmojis, ["❤️", "😀"])
	}

	func testRemove_inManual_deletesByOffset() {
		let store = makeStore()
		store.favoriteEmojis = ["❤️", "😀", "🚀"]
		let vm = makeVM(store: store)
		vm.remove(at: IndexSet(integer: 1))   // 😀
		XCTAssertEqual(vm.favorites, ["❤️", "🚀"])
	}

	// MARK: - Move only mutates in manual mode

	func testMove_inFrequency_isNoOp() {
		let store = makeStore()
		store.favoriteEmojis = ["❤️", "😀", "🚀"]
		store.favoritesSortMode = .frequency
		let vm = makeVM(store: store, isPlus: true)
		vm.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
		XCTAssertEqual(vm.favorites, ["❤️", "😀", "🚀"])
	}

	func testMove_inManual_reorders() {
		let store = makeStore()
		store.favoriteEmojis = ["❤️", "😀", "🚀"]
		let vm = makeVM(store: store)
		vm.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
		XCTAssertEqual(vm.favorites, ["😀", "🚀", "❤️"])
	}
}

/// In-memory promo Keychain backing so editor tests are deterministic (no real Keychain).
private final class InMemoryPromoBacking: PromoTrialKeychainBacking, @unchecked Sendable {
	private var storage: [String: Data] = [:]
	func data(forKey key: String) -> Data? { storage[key] }
	func set(_ data: Data, forKey key: String) { storage[key] = data }
	func removeAll() { storage.removeAll() }
}
