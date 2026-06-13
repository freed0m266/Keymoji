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
import KeyboardCore

@MainActor
public protocol OnboardingViewModeling: Observable, AnyObject {
	var currentStep: OnboardingStep { get set }
	var isKeyboardActivated: Bool { get }
	/// Favorites the user has tapped in the picker step, in tap order (= manual bar order).
	var selectedFavorites: [String] { get }

	func didConfirmKeyboardAdded()
	func didConfirmFullAccess()
	/// Toggles `glyph` in `selectedFavorites`: appends if absent (keeping tap order), removes otherwise.
	func toggleFavorite(_ glyph: String)
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
	private(set) var selectedFavorites: [String]

	private let dependencies: OnboardingDependencies
	/// The step the flow started on — used to tell whether the picker was actually part of this run.
	private let initialStep: OnboardingStep
	private var pollTask: Task<Void, Never>?

	// MARK: - Init

	init(dependencies: OnboardingDependencies, initialStep: OnboardingStep) {
		self.dependencies = dependencies
		self.initialStep = initialStep
		self.currentStep = initialStep
		// Empty for a fresh install; pre-filled with the stored set on a re-run from Settings.
		self.selectedFavorites = dependencies.preferences.currentFavorites
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

	func toggleFavorite(_ glyph: String) {
		if let index = selectedFavorites.firstIndex(of: glyph) {
			selectedFavorites.remove(at: index)
		} else {
			selectedFavorites.append(glyph)
		}
	}

	func didFinishOnboarding() {
		persistFavoritesIfPickerWasShown()
		dependencies.preferences.markOnboardingComplete()
	}

	/// Single chokepoint that enforces the non-empty invariant: an empty selection (skip, or Continue
	/// without picking) falls back to the curated 12 — never random, never empty.
	///
	/// Gated on the picker actually being part of this flow. The Settings "What Keymoji can do"
	/// shortcut re-enters the tour directly at `.featureTour`, skipping the picker; closing it must
	/// not silently overwrite favorites the user may have intentionally cleared. First-run and the
	/// full "Setup instructions" re-run both start at/before the picker, so the invariant still holds.
	private func persistFavoritesIfPickerWasShown() {
		guard initialStep.rawValue <= OnboardingStep.pickFavorites.rawValue else { return }
		let resolved = selectedFavorites.isEmpty ? EmojiCatalog.defaultFavorites : selectedFavorites
		dependencies.preferences.persistOnboardingFavorites(resolved)
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

		if detected {
			currentStep = .allowFullAccess
		}
	}

	// MARK: - Private API

	private func detectKeyboardActivated() -> Bool {
		UITextInputMode.activeInputModes
			.compactMap { $0.value(forKey: "identifier") as? String }
			.contains { $0.contains("com.freedommartin.keymoji.keyboard") }
	}
}
