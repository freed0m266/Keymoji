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

	public var openSettingsCallCount = 0
	public var didFinishCallCount = 0

	public init(currentStep: OnboardingStep = .addKeyboard, isKeyboardActivated: Bool = false) {
		self.currentStep = currentStep
		self.isKeyboardActivated = isKeyboardActivated
	}

	public func didConfirmKeyboardAdded() { currentStep = .allowFullAccess }
	public func didConfirmFullAccess() { currentStep = .selectKeyboard }
	public func didFinishOnboarding() { didFinishCallCount += 1 }
	public func openSettings() { openSettingsCallCount += 1 }
	public func refreshKeyboardStatus() { }
}
#endif
