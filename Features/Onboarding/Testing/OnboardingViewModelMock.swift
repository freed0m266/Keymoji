//
//  OnboardingViewModelMock.swift
//  Onboarding
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

#if DEBUG
import Foundation

@Observable
@MainActor
public final class OnboardingViewModelMock: OnboardingViewModeling {
	public var currentStep: OnboardingStep
	public private(set) var isKeyboardActivated: Bool
	public private(set) var selectedFavorites: [String]

	public var openSettingsCallCount = 0
	public var didFinishCallCount = 0

	public init(
		currentStep: OnboardingStep = .addKeyboard,
		isKeyboardActivated: Bool = false,
		selectedFavorites: [String] = []
	) {
		self.currentStep = currentStep
		self.isKeyboardActivated = isKeyboardActivated
		self.selectedFavorites = selectedFavorites
	}

	public func didConfirmKeyboardAdded() { currentStep = .allowFullAccess }
	public func didConfirmFullAccess() { currentStep = .selectKeyboard }
	public func toggleFavorite(_ glyph: String) {
		if let index = selectedFavorites.firstIndex(of: glyph) {
			selectedFavorites.remove(at: index)
		} else {
			selectedFavorites.append(glyph)
		}
	}
	public func didFinishOnboarding() { didFinishCallCount += 1 }
	public func openSettings() { openSettingsCallCount += 1 }
	public func refreshKeyboardStatus() { }
}
#endif
