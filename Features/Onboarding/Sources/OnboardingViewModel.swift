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
	/// Whether the user may select another favorite. False once a free user hits the free cap, so the
	/// picker can dim the remaining cells instead of silently swallowing taps (no mid-onboarding upsell).
	var canSelectMoreFavorites: Bool { get }
	/// The favorites selection cap — `freeFavoritesLimit` for free users, `.max` after Welcome/paid.
	/// Surfaced so the "Browse all" picker sheet can apply the same cap.
	var favoritesLimit: Int { get }
	/// Whether to show the opt-in Welcome gift button above the grid (see `OnboardingPreferencesProviding`).
	var canShowWelcomeOffer: Bool { get }
	/// The active *Plus trial expiry*, or `nil` — drives the read-only "Plus active until {date}" banner.
	var welcomeTrialActiveUntil: Date? { get }

	func didConfirmKeyboardAdded()
	func didConfirmFullAccess()
	/// Toggles `glyph` in `selectedFavorites`: appends if absent (keeping tap order), removes otherwise.
	/// A free user who has hit the cap can still deselect, but adding past it is ignored.
	func toggleFavorite(_ glyph: String)
	func didFinishOnboarding()
	func openSettings()
	func refreshKeyboardStatus()
	/// Activate the opt-in Welcome trial from the banner — unlocks the grid (cap → `.max`) in place.
	func activateWelcomeTrial()
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
	/// Cap on the favorites a free user may pick — the keyboard would clamp anything beyond it, so we
	/// never let onboarding save more (which would read as a silent loss). Unbounded for Plus/Welcome.
	/// Observable so activating the Welcome gift relaxes the cap (6 → `.max`) and the grid un-dims live.
	private(set) var favoritesLimit: Int
	private(set) var canShowWelcomeOffer: Bool
	private(set) var welcomeTrialActiveUntil: Date?
	private var pollTask: Task<Void, Never>?

	var canSelectMoreFavorites: Bool {
		selectedFavorites.count < favoritesLimit
	}

	// MARK: - Init

	init(dependencies: OnboardingDependencies, initialStep: OnboardingStep) {
		self.dependencies = dependencies
		self.initialStep = initialStep
		self.currentStep = initialStep
		// Provisional entitlement values; `refreshEntitlement()` recomputes them after `super.init`.
		let prefs = dependencies.preferences
		self.favoritesLimit = prefs.isPlus ? .max : FavoritesEntitlement.freeFavoritesLimit
		self.canShowWelcomeOffer = prefs.canShowWelcomeOffer
		self.welcomeTrialActiveUntil = prefs.welcomeTrialActiveUntil
		// Empty for a fresh install; pre-filled with the stored set on a re-run from Settings.
		self.selectedFavorites = prefs.currentFavorites
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

	func activateWelcomeTrial() {
		dependencies.preferences.activateWelcomeTrial()
		// Re-read entitlement so the banner flips to its success state and the grid cap relaxes (6 → .max)
		// in place — both `favoritesLimit` and `welcomeTrialActiveUntil` are observable.
		refreshEntitlement()
	}

	func toggleFavorite(_ glyph: String) {
		if let index = selectedFavorites.firstIndex(of: glyph) {
			selectedFavorites.remove(at: index)
		} else if canSelectMoreFavorites {
			selectedFavorites.append(glyph)
		}
		// Adding past the free cap is a no-op — the picker dims further cells, no upsell mid-flow.
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
	/// Pull entitlement-derived state from the preferences provider into observable VM state. Called at
	/// init and after a Welcome activation so the banner + grid cap update in place.
	private func refreshEntitlement() {
		let prefs = dependencies.preferences
		favoritesLimit = prefs.isPlus ? .max : FavoritesEntitlement.freeFavoritesLimit
		canShowWelcomeOffer = prefs.canShowWelcomeOffer
		welcomeTrialActiveUntil = prefs.welcomeTrialActiveUntil
	}

	private func persistFavoritesIfPickerWasShown() {
		guard initialStep.rawValue <= OnboardingStep.pickFavorites.rawValue else { return }
		let resolved = selectedFavorites.isEmpty ? EmojiCatalog.defaultFavorites : selectedFavorites
		// Cap the write to the free limit: the curated fallback has 12, but a free user can only keep
		// `freeFavoritesLimit`, so save the first N rather than let the keyboard clamp it inconsistently.
		dependencies.preferences.persistOnboardingFavorites(Array(resolved.prefix(favoritesLimit)))
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
