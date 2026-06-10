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
public final class SettingsViewModelMock: SettingsViewModeling {
	public var showNumberRow: Bool
	public var hapticFeedbackEnabled: Bool
	public var keyClickSoundEnabled: Bool
	public var appearance: AppearancePreference
	public var spaceDoubleTapAction: SpaceDoubleTapAction
	public var letterLayout: LetterLayout
	public var suggestionsEnabled: Bool
	public private(set) var learnedWordCount: Int

	public init(
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

	public func refreshLearnedWordCount() {}
}
#endif
