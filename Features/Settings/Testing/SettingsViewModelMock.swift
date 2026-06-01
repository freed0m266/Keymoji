//
//  SettingsViewModelMock.swift
//  Settings
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

#if DEBUG
import Foundation
import KeyboCore

@Observable
@MainActor
public final class SettingsViewModelMock: SettingsViewModeling {
	public var showNumberRow: Bool
	public var hapticFeedbackEnabled: Bool
	public var keyClickSoundEnabled: Bool
	public var appearance: AppearancePreference
	public var spaceDoubleTapAction: SpaceDoubleTapAction
	public var letterLayout: LetterLayout
	public var suggestionsEnabled: Bool
	public private(set) var learnedWordCount: Int
	public var versionString: String

	public init(
		showNumberRow: Bool = true,
		hapticFeedbackEnabled: Bool = true,
		keyClickSoundEnabled: Bool = false,
		appearance: AppearancePreference = .system,
		spaceDoubleTapAction: SpaceDoubleTapAction = .insertPeriod,
		letterLayout: LetterLayout = .qwerty,
		suggestionsEnabled: Bool = true,
		learnedWordCount: Int = 128,
		versionString: String = "1.0 (1)"
	) {
		self.showNumberRow = showNumberRow
		self.hapticFeedbackEnabled = hapticFeedbackEnabled
		self.keyClickSoundEnabled = keyClickSoundEnabled
		self.appearance = appearance
		self.spaceDoubleTapAction = spaceDoubleTapAction
		self.letterLayout = letterLayout
		self.suggestionsEnabled = suggestionsEnabled
		self.learnedWordCount = learnedWordCount
		self.versionString = versionString
	}

	public func refreshLearnedWordCount() {}

	public func clearLearnedWords() {
		learnedWordCount = 0
	}
}
#endif
