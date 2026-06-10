//
//  OnboardingViewModel.swift
//  Onboarding
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation
import UIKit
import KeymojiCore

@MainActor
public protocol OnboardingViewModeling: Observable, AnyObject {
	var currentStep: OnboardingStep { get set }
	var isKeyboardActivated: Bool { get }

	func didConfirmKeyboardAdded()
	func didConfirmFullAccess()
	func didFinishOnboarding()
	func openSettings()
	func refreshKeyboardStatus()
}

@MainActor
public func onboardingVM(initialStep: OnboardingStep = .addKeyboard) -> some OnboardingViewModeling {
	OnboardingViewModel(dependencies: dependencies.onboarding, initialStep: initialStep)
}

@Observable
final class OnboardingViewModel: BaseViewModel, OnboardingViewModeling {

	var currentStep: OnboardingStep
	private(set) var isKeyboardActivated: Bool = false

	private let dependencies: OnboardingDependencies
	private var pollTask: Task<Void, Never>?

	// MARK: - Init

	init(dependencies: OnboardingDependencies, initialStep: OnboardingStep) {
		self.dependencies = dependencies
		self.currentStep = initialStep
		super.init()
		refreshKeyboardStatus()
	}

	// MARK: - Public API

	func didConfirmKeyboardAdded() {
		currentStep = .allowFullAccess
	}

	func didConfirmFullAccess() {
		currentStep = .selectKeyboard
	}

	func didFinishOnboarding() {
		dependencies.preferences.markOnboardingComplete()
	}

	func openSettings() {
		guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
		UIApplication.shared.open(url)
	}

	/// `UITextInputMode.activeInputModes` is the only reliable way
	///  to detect that the user has added our keyboard via iOS Settings.
	func refreshKeyboardStatus() {
		let detected = detectKeyboardActivated()

		if detected != isKeyboardActivated {
			isKeyboardActivated = detected
		}
	}

	// MARK: - Private API

	private func detectKeyboardActivated() -> Bool {
		UITextInputMode.activeInputModes
			.compactMap { $0.value(forKey: "identifier") as? String }
			.contains { $0.contains("com.freedommartin.keymoji.keyboard") }
	}
}
