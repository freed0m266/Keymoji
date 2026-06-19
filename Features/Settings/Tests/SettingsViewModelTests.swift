//
//  SettingsViewModelTests.swift
//  Settings_Tests
//
//  Created by Martin Svoboda on 19.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import XCTest
import KeymojiCore
import Paywall
@testable import Settings

/// In-memory promo Keychain backing so the row state machine runs without entitlements.
private final class InMemoryPromoBacking: PromoTrialKeychainBacking, @unchecked Sendable {
	private var storage: [String: Data] = [:]
	func data(forKey key: String) -> Data? { storage[key] }
	func set(_ data: Data, forKey key: String) throws { storage[key] = data }
	func removeAll() { storage.removeAll() }
}

@MainActor
final class SettingsViewModelTests: XCTestCase {

	private let suiteName = "keymoji.SettingsViewModelTests"
	private var appGroup: AppGroupStore!
	private var backing: InMemoryPromoBacking!

	override func setUp() {
		super.setUp()
		appGroup = AppGroupStore(suiteName: suiteName)
		appGroup.reset()
		backing = InMemoryPromoBacking()
	}

	override func tearDown() {
		appGroup.reset()
		super.tearDown()
	}

	/// Builds the real VM over the shared test stores. `seed` runs *before* the VM is created so init's
	/// `refreshPromoState()` observes the desired store state.
	private func makeVM(paid: Bool = false, seed: (AppGroupStore, PromoTrialStore) -> Void = { _, _ in }) -> SettingsViewModel {
		let promoStore = PromoTrialStore(backing: backing)
		seed(appGroup, promoStore)
		let purchase = PurchaseServiceMock(isPlus: paid)
		let notifier = SettingsChangeNotifier()
		let activator = WelcomeTrialActivator(
			promoStore: promoStore,
			appGroup: appGroup,
			notifier: notifier,
			purchaseService: purchase
		)
		return SettingsViewModel(
			store: appGroup,
			notifier: notifier,
			purchaseService: purchase,
			promoStore: promoStore,
			welcomeActivator: activator
		)
	}

	// MARK: - State machine

	func testFreeUser_noTrial_isWelcomeAvailable() {
		XCTAssertEqual(makeVM().plusRowState, .welcomeAvailable)
	}

	func testPaidUser_isPaid() {
		XCTAssertEqual(makeVM(paid: true).plusRowState, .paid)
	}

	func testActivateWelcome_movesToTrialActive_30Days() {
		let vm = makeVM()
		vm.activateWelcomeTrial()

		XCTAssertEqual(vm.plusRowState, .trialActive(daysLeft: 30))
		XCTAssertTrue(vm.isPlus)
		XCTAssertNotNil(vm.trialActiveUntil)
	}

	func testActivateWelcome_isIdempotent() {
		let vm = makeVM()
		vm.activateWelcomeTrial()
		let firstExpiry = vm.trialActiveUntil
		vm.activateWelcomeTrial()   // second tap — no extra grant

		XCTAssertEqual(vm.plusRowState, .trialActive(daysLeft: 30))
		XCTAssertEqual(vm.trialActiveUntil, firstExpiry)
	}

	func testPaidUser_activateWelcome_isNoOp() {
		let vm = makeVM(paid: true)
		vm.activateWelcomeTrial()
		// Paid overrides — no token spent, row stays paid.
		XCTAssertEqual(vm.plusRowState, .paid)
		XCTAssertNil(vm.trialActiveUntil)
	}

	func testExpiredWelcome_isAfterTrial() {
		// Welcome consumed, but the expiry now lies in the past.
		let vm = makeVM { appGroup, promoStore in
			_ = promoStore.consumeWelcome(now: Date())           // welcomeConsumed = true (Keychain)
			appGroup.promoPlusExpiresAt = Date(timeIntervalSinceNow: -60)  // mirror expired
		}
		XCTAssertEqual(vm.plusRowState, .afterTrial)
		XCTAssertNil(vm.trialActiveUntil)
	}

	func testActiveCheatCode_welcomeNeverTaken_isTrialActive_notWelcomeAvailable() {
		// A cheat code grant is active but Welcome was never consumed — don't upsell mid-trial.
		let vm = makeVM { appGroup, _ in
			appGroup.promoPlusExpiresAt = Date(timeIntervalSinceNow: 10 * 24 * 60 * 60)
		}
		guard case .trialActive = vm.plusRowState else {
			return XCTFail("Expected .trialActive, got \(vm.plusRowState)")
		}
	}

	func testExpiredCheatCode_welcomeNeverTaken_stillOffersWelcome() {
		// cheat code expired and Welcome was never taken → the gift is still available (not afterTrial).
		let vm = makeVM { appGroup, _ in
			appGroup.promoPlusExpiresAt = Date(timeIntervalSinceNow: -60)
		}
		XCTAssertEqual(vm.plusRowState, .welcomeAvailable)
	}
}
