//
//  KeymojiApp.swift
//  Keymoji
//
//  Created by Martin Svoboda on 26.04.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import SwiftyBeaver
import Analytics
import KeymojiCore
import Onboarding
import Paywall
import Settings

@main
struct KeymojiApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

	var body: some Scene {
		WindowGroup {
			RootView(
				onboardingViewModel: onboardingVM(),
				settingsViewModel: settingsVM()
			)
		}
	}
}

// MARK: - UIApplicationDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
	func application(
		_ application: UIApplication,
		didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
	) -> Bool {
		setupLogger()
		startAnalytics()
		startPurchases()
		// Restore the promo-trial expiry mirror from the Keychain master after a reinstall (the App Group
		// container is wiped on uninstall; the Keychain survives). Cheap, runs once, before any UI gates read.
		PromoTrialReconciliation.reconcileShared()
		// Plant the What's New content-version baseline on first run, before any What's New content ships, so a
		// fresh install never sees a What's New for the version it was born on (task 76). Seed-on-absence; no UI.
		WhatsNewBaseline.seedIfNeeded()
		return true
	}

	/// Emit the anonymous settings snapshot every time the host app becomes active (task 86, signal A).
	/// Re-reading on each activation keeps the distribution fresh when a user changes a setting and comes
	/// back. No-op when the user has opted out — `TelemetryDeckAnalyticsService.report` drops it. The
	/// keyboard extension never runs this and never links the SDK (boundary 1, ADR 0004).
	func applicationDidBecomeActive(_ application: UIApplication) {
		dependencies.analytics.report(.settingsSnapshot(.current()))
	}

	/// Install the host-app analytics sink at launch (task 86, ADR 0004). The concrete
	/// `TelemetryDeckAnalyticsService` lives in the host-only `Analytics` framework; everywhere else the
	/// default `NoopAnalyticsService` keeps emission inert. Initializing the SDK sends nothing on its own
	/// — signals only flow from `report`, and only while the user hasn't opted out.
	@MainActor
	private func startAnalytics() {
		dependencies.analytics = TelemetryDeckAnalyticsService()
	}

	/// Bring up the StoreKit gateway once at launch: start the `Transaction.updates` listener (catches
	/// Ask-to-Buy approvals and cross-device purchases) and pre-load the product so the price is ready
	/// before the user ever reaches the paywall. The keyboard extension never touches StoreKit; it reads
	/// the `AppGroupStore.isPlus` mirror this keeps current.
	@MainActor
	private func startPurchases() {
		let service = PurchaseService.shared
		service.start()
		Task { await service.loadProducts() }
	}
}

// MARK: - Logger setup
private extension AppDelegate {
	func setupLogger() {
		let consoleDestination = ConsoleDestination()
		consoleDestination.format = "$DHH:mm:ss.SSS$d ~ $C$L$c $N.$F:$l - $M $X"
		consoleDestination.levelColor.verbose = "📝 "
		consoleDestination.levelColor.debug = "🐛 "
		consoleDestination.levelColor.info = "ℹ️ "
		consoleDestination.levelColor.warning = "⚠️ "
		consoleDestination.levelColor.error = "❌ "
		#if DEBUG
		consoleDestination.minLevel = .verbose
		#else
		consoleDestination.minLevel = .warning
		#endif
		Logger.addDestination(consoleDestination)
	}
}
