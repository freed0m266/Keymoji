//
//  KeyboApp.swift
//  Keybo
//
//  Created by Martin Svoboda on 26.04.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import SwiftyBeaver
import KeyboCore

@main
struct KeyboApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

	var body: some Scene {
		WindowGroup {
			RootView()
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
		return true
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
