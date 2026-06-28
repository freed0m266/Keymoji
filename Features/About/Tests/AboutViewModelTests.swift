//
//  AboutViewModelTests.swift
//  About_Tests
//
//  Created by Martin Svoboda on 28.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import XCTest
import KeymojiCore
@testable import About

@MainActor
final class AboutViewModelTests: XCTestCase {

	private let consentSuiteName = "keymoji.AboutViewModelTests.consent"
	private var consentDefaults: UserDefaults!
	private var consent: AnalyticsConsentStore!

	override func setUp() {
		super.setUp()
		consentDefaults = UserDefaults(suiteName: consentSuiteName)
		consentDefaults.removePersistentDomain(forName: consentSuiteName)
		consent = AnalyticsConsentStore(defaults: consentDefaults)
	}

	override func tearDown() {
		consentDefaults.removePersistentDomain(forName: consentSuiteName)
		super.tearDown()
	}

	// MARK: - Analytics opt-out

	func testAnalyticsEnabled_defaultsToOptedIn() {
		XCTAssertTrue(AboutViewModel(consent: consent).analyticsEnabled)
	}

	func testAnalyticsEnabled_readsExistingConsent() {
		consent.isEnabled = false
		XCTAssertFalse(AboutViewModel(consent: consent).analyticsEnabled)
	}

	func testTogglingAnalytics_writesThroughToConsentStore() {
		let vm = AboutViewModel(consent: consent)
		vm.analyticsEnabled = false
		XCTAssertFalse(consent.isEnabled)
		vm.analyticsEnabled = true
		XCTAssertTrue(consent.isEnabled)
	}
}
