//
//  KeymojiApp.swift
//  Keymoji
//
//  Created by Martin Svoboda on 26.04.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import SwiftyBeaver
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
		startPurchases()
		// Restore the promo-trial expiry mirror from the Keychain master after a reinstall (the App Group
		// container is wiped on uninstall; the Keychain survives). Cheap, runs once, before any UI gates read.
		PromoTrialReconciliation.reconcileShared()
		// Plant the What's New content-version baseline on first run, before any What's New content ships, so a
		// fresh install never sees a What's New for the version it was born on (task 76). Seed-on-absence; no UI.
		WhatsNewBaseline.seedIfNeeded()
		return true
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
