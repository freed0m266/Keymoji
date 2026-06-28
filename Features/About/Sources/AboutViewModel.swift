//
//  AboutViewModel.swift
//  About
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation
import UIKit
import KeymojiCore

@MainActor
public protocol AboutViewModeling: Observable, AnyObject {
	var versionString: String { get }
	/// Opt-out switch for anonymous usage analytics (task 86). Default ON; OFF stops all emission.
	var analyticsEnabled: Bool { get set }

	func openAppStoreReview()
	func openPrivacyPolicy()
	func openSupportEmail()
}

@MainActor
public func aboutVM() -> some AboutViewModeling {
	AboutViewModel()
}

@Observable
final class AboutViewModel: BaseViewModel, AboutViewModeling {

	/// Opt-out toggle for anonymous analytics. Persisted host-side (not the App Group — the keyboard
	/// never reads it). Flipping it takes effect on the next emission: the service re-reads consent per
	/// `report`, so OFF stops all signals at once (task 86, ADR 0004).
	var analyticsEnabled: Bool {
		didSet {
			consent.isEnabled = analyticsEnabled
			// Start/stop the underlying SDK immediately — guarding emission alone wouldn't silence
			// TelemetryDeck's own session signals (task 86, Codex P1 / ADR 0004).
			dependencies.analytics.consentDidChange()
		}
	}

	private let consent: AnalyticsConsentStore

	// MARK: - Init

	init(consent: AnalyticsConsentStore = .shared) {
		self.consent = consent
		self.analyticsEnabled = consent.isEnabled
		super.init()
	}

	// MARK: - Public API

	func openAppStoreReview() {
		dependencies.analytics.report(.reviewTapped)   // funnel: review tap (task 86, B / task 83)
		guard let url = URL(string: KeymojiURLs.appStoreReview) else { return }
		UIApplication.shared.open(url)
	}

	func openPrivacyPolicy() {
		guard let url = URL(string: KeymojiURLs.privacyPolicy) else { return }
		UIApplication.shared.open(url)
	}

	func openSupportEmail() {
		guard let url = URL(string: KeymojiURLs.supportEmail) else { return }
		UIApplication.shared.open(url)
	}
}
