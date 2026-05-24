//
//  SettingsViewModel.swift
//  Settings
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation
import KeyboCore

@MainActor
public protocol SettingsViewModeling: Observable, AnyObject {
	var showNumberRow: Bool { get set }
	var hapticFeedbackEnabled: Bool { get set }
	var versionString: String { get }
}

@MainActor
public func settingsVM() -> SettingsViewModel {
	SettingsViewModel()
}

@Observable
public final class SettingsViewModel: BaseViewModel, SettingsViewModeling {

	public var showNumberRow: Bool {
		didSet { store.showNumberRow = showNumberRow }
	}

	public var hapticFeedbackEnabled: Bool {
		didSet { store.hapticFeedbackEnabled = hapticFeedbackEnabled }
	}

	public let versionString: String

	private let store: AppGroupStore

	public init(store: AppGroupStore = .shared) {
		self.store = store
		self.showNumberRow = store.showNumberRow
		self.hapticFeedbackEnabled = store.hapticFeedbackEnabled
		self.versionString = Self.makeVersionString()
		super.init()
	}

	private static func makeVersionString() -> String {
		let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
		let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
		return "\(version) (\(build))"
	}
}
