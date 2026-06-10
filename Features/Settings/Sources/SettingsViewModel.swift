//
//  SettingsViewModel.swift
//  Settings
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation
import KeymojiCore
import KeyboardCore

@MainActor
public protocol SettingsViewModeling: Observable, AnyObject {
	var showNumberRow: Bool { get set }
	var hapticFeedbackEnabled: Bool { get set }
	var keyClickSoundEnabled: Bool { get set }
	var appearance: AppearancePreference { get set }
	var spaceDoubleTapAction: SpaceDoubleTapAction { get set }
	var letterLayout: LetterLayout { get set }
	var suggestionsEnabled: Bool { get set }
	var learnedWordCount: Int { get }

	/// Recompute `learnedWordCount` from the store (the keyboard mutates it out-of-process, and the
	/// Learned words editor can delete entries). Refresh on view appear.
	func refreshLearnedWordCount()
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

	var letterLayout: LetterLayout {
		didSet {
			store.letterLayout = letterLayout
			notifier.post(.letterLayout)
		}
	}

	var suggestionsEnabled: Bool {
		didSet {
			store.suggestionsEnabled = suggestionsEnabled
			notifier.post(.suggestionsEnabled)
		}
	}

	private(set) var learnedWordCount: Int = 0

	private let store: AppGroupStore
	private let notifier: SettingsChangeNotifier
	private let recentsStore: PersonalRecentsStore

	// MARK: - Init

	init(
		store: AppGroupStore = .shared,
		notifier: SettingsChangeNotifier = .shared
	) {
		self.store = store
		self.notifier = notifier
		self.recentsStore = PersonalRecentsStore(store: store)
		self.showNumberRow = store.showNumberRow
		self.hapticFeedbackEnabled = store.hapticFeedbackEnabled
		self.keyClickSoundEnabled = store.keyClickSoundEnabled
		self.appearance = store.appearance
		self.spaceDoubleTapAction = store.spaceDoubleTapAction
		self.letterLayout = store.letterLayout
		self.suggestionsEnabled = store.suggestionsEnabled
		super.init()
		self.learnedWordCount = recentsStore.count
	}

	// MARK: - Learned words

	func refreshLearnedWordCount() {
		learnedWordCount = recentsStore.count
	}
}
