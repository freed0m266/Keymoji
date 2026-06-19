//
//  OnboardingDependencies.swift
//  Onboarding
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation
import KeymojiCore

public protocol OnboardingPreferencesProviding: Sendable {
	var isOnboardingComplete: Bool { get }
	/// Currently stored favorites — read once at view-model init to pre-fill the picker on re-run.
	var currentFavorites: [String] { get }
	/// Whether the user owns Keymoji Plus — caps the onboarding favorites selection for free users so
	/// they can't save more than the keyboard would show (which would look like a silent loss).
	var isPlus: Bool { get }
	/// Whether to offer the opt-in Welcome gift: not paid, not already consumed, and no trial running.
	var canShowWelcomeOffer: Bool { get }
	/// The active *Plus trial expiry*, or `nil` when no trial is running — drives the success banner.
	var welcomeTrialActiveUntil: Date? { get }
	func markOnboardingComplete()
	/// Final, single write of the onboarding favorites selection (already resolved against the
	/// non-empty fallback and the free cap by the view model). Also notifies a possibly-active keyboard.
	func persistOnboardingFavorites(_ favorites: [String])
	/// Activate the opt-in Welcome trial from the onboarding banner. No-op if already consumed or paid.
	@MainActor func activateWelcomeTrial()
}

public struct OnboardingPreferences: OnboardingPreferencesProviding {
	private let store: AppGroupStore
	private let notifier: SettingsChangeNotifier
	private let promoStore: any PromoTrialStoring

	public init(
		store: AppGroupStore = .shared,
		notifier: SettingsChangeNotifier = .shared,
		promoStore: any PromoTrialStoring = PromoTrialStore.makeShared()
	) {
		self.store = store
		self.notifier = notifier
		self.promoStore = promoStore
	}

	public var isOnboardingComplete: Bool {
		store.onboardingComplete
	}

	public var currentFavorites: [String] {
		store.favoriteEmojis
	}

	public var isPlus: Bool {
		// *Effective* Plus — paid or an active promo trial. An active Welcome/cheat code grant lifts the
		// onboarding favorites cap exactly like a paid unlock would.
		effectiveIsPlus(paid: store.isPlus, promoExpiresAt: store.promoPlusExpiresAt, now: Date())
	}

	public var canShowWelcomeOffer: Bool {
		guard !store.isPlus else { return false }                 // paid — nothing to gift
		guard !promoStore.record.welcomeConsumed else { return false }   // already taken
		return welcomeTrialActiveUntil == nil                     // not mid-trial (e.g. cheat code running)
	}

	public var welcomeTrialActiveUntil: Date? {
		guard let expiry = store.promoPlusExpiresAt, Date() < expiry else { return nil }
		return expiry
	}

	public func markOnboardingComplete() {
		store.onboardingComplete = true
	}

	public func persistOnboardingFavorites(_ favorites: [String]) {
		store.favoriteEmojis = favorites
		// No-op unless the user already added the keyboard in step 1 and it's live; harmless otherwise.
		notifier.post(.favoriteEmojis)
	}

	@MainActor
	public func activateWelcomeTrial() {
		// Shares this provider's promo store with the activator so reads/writes hit the same Keychain.
		WelcomeTrialActivator(promoStore: promoStore, purchaseService: PurchaseService.shared).activate()
	}
}

public struct OnboardingDependencies: Sendable {
	public let preferences: any OnboardingPreferencesProviding

	public init(preferences: any OnboardingPreferencesProviding = OnboardingPreferences()) {
		self.preferences = preferences
	}
}

extension AppDependency {
	var onboarding: OnboardingDependencies {
		.init()
	}
}
