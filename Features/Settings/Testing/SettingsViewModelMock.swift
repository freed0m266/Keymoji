//
//  SettingsViewModelMock.swift
//  Settings
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

#if DEBUG
import Foundation
import KeymojiCore

@Observable
@MainActor
final class SettingsViewModelMock: SettingsViewModeling {
	var showNumberRow: Bool
	var hapticFeedbackEnabled: Bool
	var keyClickSoundEnabled: Bool
	var autoCapitalizationEnabled: Bool
	var appearance: AppearancePreference
	var spaceDoubleTapAction: SpaceDoubleTapAction
	var letterLayout: LetterLayout
	var letterAlternateSet: LetterAlternateSet
	var suggestionsEnabled: Bool
	private(set) var learnedWordCount: Int
	var isPlus: Bool
	var plusRowState: PlusRowState
	var trialActiveUntil: Date?

	init(
		showNumberRow: Bool = true,
		hapticFeedbackEnabled: Bool = true,
		keyClickSoundEnabled: Bool = false,
		autoCapitalizationEnabled: Bool = true,
		appearance: AppearancePreference = .system,
		spaceDoubleTapAction: SpaceDoubleTapAction = .insertPeriod,
		letterLayout: LetterLayout = .qwerty,
		letterAlternateSet: LetterAlternateSet = .czech,
		suggestionsEnabled: Bool = true,
		learnedWordCount: Int = 128,
		isPlus: Bool = false,
		plusRowState: PlusRowState = .welcomeAvailable,
		trialActiveUntil: Date? = nil,
	) {
		self.showNumberRow = showNumberRow
		self.hapticFeedbackEnabled = hapticFeedbackEnabled
		self.keyClickSoundEnabled = keyClickSoundEnabled
		self.autoCapitalizationEnabled = autoCapitalizationEnabled
		self.appearance = appearance
		self.spaceDoubleTapAction = spaceDoubleTapAction
		self.letterLayout = letterLayout
		self.letterAlternateSet = letterAlternateSet
		self.suggestionsEnabled = suggestionsEnabled
		self.learnedWordCount = learnedWordCount
		self.isPlus = isPlus
		self.plusRowState = plusRowState
		self.trialActiveUntil = trialActiveUntil
	}

	func refreshLearnedWordCount() {}

	func activateWelcomeTrial() {
		plusRowState = .trialActive(daysLeft: 30)
		trialActiveUntil = Date().addingTimeInterval(30 * 24 * 60 * 60)
	}
}
#endif
