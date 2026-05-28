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
	var keyClickSoundEnabled: Bool { get set }
	var appearance: AppearancePreference { get set }
	var spaceDoubleTapAction: SpaceDoubleTapAction { get set }
	var versionString: String { get }
}

@MainActor
public func settingsVM() -> some SettingsViewModeling {
	SettingsViewModel()
}

@Observable
final class SettingsViewModel: BaseViewModel, SettingsViewModeling {

	var showNumberRow: Bool {
		didSet {
			store.showNumberRow = showNumberRow
			notifier.post(.showNumberRow)
		}
	}

	var hapticFeedbackEnabled: Bool {
		didSet {
			store.hapticFeedbackEnabled = hapticFeedbackEnabled
			notifier.post(.hapticFeedbackEnabled)
		}
	}

	var keyClickSoundEnabled: Bool {
		didSet {
			store.keyClickSoundEnabled = keyClickSoundEnabled
			notifier.post(.keyClickSoundEnabled)
		}
	}

	var appearance: AppearancePreference {
		didSet {
			store.appearance = appearance
			notifier.post(.appearance)
		}
	}

	var spaceDoubleTapAction: SpaceDoubleTapAction {
		didSet {
			store.spaceDoubleTapAction = spaceDoubleTapAction
			notifier.post(.spaceDoubleTapAction)
		}
	}

	private let store: AppGroupStore
	private let notifier: SettingsChangeNotifier

	// MARK: - Init

	init(
		store: AppGroupStore = .shared,
		notifier: SettingsChangeNotifier = .shared
	) {
		self.store = store
		self.notifier = notifier
		self.showNumberRow = store.showNumberRow
		self.hapticFeedbackEnabled = store.hapticFeedbackEnabled
		self.keyClickSoundEnabled = store.keyClickSoundEnabled
		self.appearance = store.appearance
		self.spaceDoubleTapAction = store.spaceDoubleTapAction
		super.init()
	}
}
