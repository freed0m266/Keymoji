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
}

@MainActor
public func onboardingVM() -> some OnboardingViewModeling {
	OnboardingViewModel(dependencies: dependencies.onboarding)
}

@Observable
final class OnboardingViewModel: BaseViewModel, OnboardingViewModeling {

	var currentStep: OnboardingStep = .addKeyboard
	private(set) var isKeyboardActivated: Bool = false

	private let dependencies: OnboardingDependencies
	private var pollTask: Task<Void, Never>?

	// MARK: - Init

	init(dependencies: OnboardingDependencies) {
		self.dependencies = dependencies
		super.init()
		startPollingKeyboardStatus()
	}

	// No deinit cancel — Swift 6 prohibits touching `@MainActor` state from `deinit`. The polling
	// task already captures `self` weakly, so once the VM deallocates the body becomes a no-op.
	// The resulting 1s/iter idle wake-up is negligible; proper view-lifecycle cancellation can
	// be wired in later if it ever shows up in profiles.

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

	// MARK: - Private API

	/// `UITextInputMode.activeInputModes` is the only reliable way to detect that the user has
	/// added our keyboard via iOS Settings. We probe each input mode's KVC `identifier` for the
	/// extension's bundle ID. iOS Settings can be entered/exited at any moment, so we poll
	/// every second while the onboarding view is alive.
	private func startPollingKeyboardStatus() {
		pollTask = Task { [weak self] in
			while !Task.isCancelled {
				await self?.refreshKeyboardStatus()
				try? await Task.sleep(for: .seconds(1))
			}
		}
	}

	@MainActor
	private func refreshKeyboardStatus() {
		let detected = Self.detectKeyboardActivated()
		if detected != isKeyboardActivated {
			isKeyboardActivated = detected
			// Auto-advance only from the first step — never roll users back.
			if detected, currentStep == .addKeyboard {
				currentStep = .allowFullAccess
			}
		}
	}

	private static func detectKeyboardActivated() -> Bool {
		UITextInputMode.activeInputModes
			.compactMap { $0.value(forKey: "identifier") as? String }
			.contains { $0.contains("com.freedommartin.keymoji.keyboard") }
	}
}
