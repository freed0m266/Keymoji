//
//  PurchaseServiceTests.swift
//  Paywall_Tests
//
//  Created by Martin Svoboda on 15.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import XCTest
import StoreKit
import StoreKitTest
import KeymojiCore

/// Exercises the real StoreKit 2 `PurchaseService` (in `KeymojiCore`) against the bundled
/// `Keymoji.storekit` config via `SKTestSession`. Lives in this app-hosted test target — not
/// `KeymojiCore_Tests`, which runs standalone — because `SKTestSession(configurationFileNamed:)`
/// resolves the config from the host app bundle. Purchases are simulated at the StoreKit layer
/// (`buyProduct`) so the test stays headless (no UIScene) and verifies the part we own: the
/// entitlement → `AppGroupStore.isPlus` mirror + `.isPlus` cross-process post.
@MainActor
final class PurchaseServiceTests: XCTestCase {

	private var session: SKTestSession!

	override func setUpWithError() throws {
		do {
			session = try SKTestSession(configurationFileNamed: "Keymoji")
		} catch {
			throw XCTSkip("StoreKit test config 'Keymoji' unavailable in this environment: \(error)")
		}
		session.disableDialogs = true
		session.clearTransactions()
	}

	override func tearDown() {
		session?.clearTransactions()
		session = nil
	}

	private func makeStore() -> AppGroupStore {
		AppGroupStore(suiteName: "keymoji.tests.purchase.\(UUID().uuidString)")
	}

	func testLoadProducts_resolvesLocalizedPrice() async {
		let service = PurchaseService(store: makeStore(), notifier: SettingsChangeNotifier())
		await service.loadProducts()
		XCTAssertTrue(service.isProductLoaded)
		XCTAssertNotNil(service.displayPrice)
	}

	func testRefreshEntitlement_noPurchase_isFree() async {
		let store = makeStore()
		let service = PurchaseService(store: store, notifier: SettingsChangeNotifier())
		await service.refreshEntitlement()
		XCTAssertFalse(service.isPlus)
		XCTAssertFalse(store.isPlus)
	}

	func testEntitlement_afterPurchase_unlocksMirrorsAndPosts() async throws {
		let store = makeStore()
		let notifier = SettingsChangeNotifier()
		let service = PurchaseService(store: store, notifier: notifier)
		let posted = expectation(description: ".isPlus notification fires")
		let token = notifier.addObserver(for: .isPlus) { posted.fulfill() }

		XCTAssertFalse(service.isPlus)
		try await session.buyProduct(productIdentifier: PurchaseService.plusProductID)
		await service.refreshEntitlement()

		XCTAssertTrue(service.isPlus)
		XCTAssertTrue(store.isPlus)
		await fulfillment(of: [posted], timeout: 2)
		_ = token
	}

	func testRestore_afterPurchase_keepsPlus() async throws {
		let store = makeStore()
		let service = PurchaseService(store: store, notifier: SettingsChangeNotifier())
		try await session.buyProduct(productIdentifier: PurchaseService.plusProductID)

		let owned = await service.restore()
		XCTAssertTrue(owned)
		XCTAssertTrue(service.isPlus)
		XCTAssertTrue(store.isPlus)
	}

	// Note: the revocation/downgrade path (a refund dropping the entitlement) isn't tested here —
	// `SKTestSession.refundTransaction` doesn't reliably remove the transaction from
	// `Transaction.currentEntitlements`, so it would assert StoreKitTest's simulation rather than our
	// code. The clamp side of a downgrade is covered by `FavoritesEntitlementTests`, and the
	// "no entitlement → free" mirror by `testRefreshEntitlement_noPurchase_isFree` above.
}
