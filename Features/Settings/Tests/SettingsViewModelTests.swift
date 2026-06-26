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
	private let consentSuiteName = "keymoji.SettingsViewModelTests.consent"
	private var appGroup: AppGroupStore!
	private var consentDefaults: UserDefaults!
	private var consent: AnalyticsConsentStore!
	private var backing: InMemoryPromoBacking!

	override func setUp() {
		super.setUp()
		appGroup = AppGroupStore(suiteName: suiteName)
		appGroup.reset()
		consentDefaults = UserDefaults(suiteName: consentSuiteName)
		consentDefaults.removePersistentDomain(forName: consentSuiteName)
		consent = AnalyticsConsentStore(defaults: consentDefaults)
		backing = InMemoryPromoBacking()
	}

	override func tearDown() {
		appGroup.reset()
		consentDefaults.removePersistentDomain(forName: consentSuiteName)
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
			consent: consent,
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

	// MARK: - Analytics opt-out

	func testAnalyticsEnabled_defaultsToOptedIn() {
		XCTAssertTrue(makeVM().analyticsEnabled)
	}

	func testAnalyticsEnabled_readsExistingConsent() {
		consent.isEnabled = false
		XCTAssertFalse(makeVM().analyticsEnabled)
	}

	func testTogglingAnalytics_writesThroughToConsentStore() {
		let vm = makeVM()
		vm.analyticsEnabled = false
		XCTAssertFalse(consent.isEnabled)
		vm.analyticsEnabled = true
		XCTAssertTrue(consent.isEnabled)
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
}
