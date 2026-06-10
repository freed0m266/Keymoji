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
	var appearance: AppearancePreference
	var spaceDoubleTapAction: SpaceDoubleTapAction
	var letterLayout: LetterLayout
	var suggestionsEnabled: Bool
	private(set) var learnedWordCount: Int

	init(
		showNumberRow: Bool = true,
		hapticFeedbackEnabled: Bool = true,
		keyClickSoundEnabled: Bool = false,
		appearance: AppearancePreference = .system,
		spaceDoubleTapAction: SpaceDoubleTapAction = .insertPeriod,
		letterLayout: LetterLayout = .qwerty,
		suggestionsEnabled: Bool = true,
		learnedWordCount: Int = 128,
	) {
		self.showNumberRow = showNumberRow
		self.hapticFeedbackEnabled = hapticFeedbackEnabled
		self.keyClickSoundEnabled = keyClickSoundEnabled
		self.appearance = appearance
		self.spaceDoubleTapAction = spaceDoubleTapAction
		self.letterLayout = letterLayout
		self.suggestionsEnabled = suggestionsEnabled
		self.learnedWordCount = learnedWordCount
	}

	func refreshLearnedWordCount() {}
}
#endif
