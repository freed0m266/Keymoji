//
//  BaseViewModel.swift
//  KeymojiCore
//
//  Created by Martin Svoboda on 26.04.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation
import os.log

@MainActor
open class BaseViewModel {
	public var isLoading = false
	public var errorMessage: String?

	public var versionString: String {
		let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
		let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
		return "\(version) (\(build))"
	}

	// MARK: - Init
	
	public init() {
		os_log("🧠 👶 %@", log: Self.lifecycleLog(), type: .info, "\(self)")
	}
	
	// MARK: - Deinit
	
	deinit {
		os_log("🧠 ⚰️ %@", log: Self.lifecycleLog(), type: .info, "\(self)")
	}
	
	// MARK: - Public API
	
	public func showError(_ message: String) {
		Logger.error(message)
		errorMessage = message
	}
	
	// MARK: - Private API
	
	private nonisolated static func lifecycleLog() -> OSLog {
		OSLog(subsystem: Bundle.main.bundleIdentifier ?? "-", category: "Lifecycle")
	}
}
