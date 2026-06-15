//
//  OnboardingDependencies.swift
//  Onboarding
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import KeymojiCore

public protocol OnboardingPreferencesProviding: Sendable {
	var isOnboardingComplete: Bool { get }
	/// Currently stored favorites — read once at view-model init to pre-fill the picker on re-run.
	var currentFavorites: [String] { get }
	/// Whether the user owns Keymoji Plus — caps the onboarding favorites selection for free users so
	/// they can't save more than the keyboard would show (which would look like a silent loss).
	var isPlus: Bool { get }
	func markOnboardingComplete()
	/// Final, single write of the onboarding favorites selection (already resolved against the
	/// non-empty fallback and the free cap by the view model). Also notifies a possibly-active keyboard.
	func persistOnboardingFavorites(_ favorites: [String])
}

public struct OnboardingPreferences: OnboardingPreferencesProviding {
	private let store: AppGroupStore
	private let notifier: SettingsChangeNotifier

	public init(store: AppGroupStore = .shared, notifier: SettingsChangeNotifier = .shared) {
		self.store = store
		self.notifier = notifier
	}

	public var isOnboardingComplete: Bool {
		store.onboardingComplete
	}

	public var currentFavorites: [String] {
		store.favoriteEmojis
	}

	public var isPlus: Bool {
		store.isPlus
	}

	public func markOnboardingComplete() {
		store.onboardingComplete = true
	}

	public func persistOnboardingFavorites(_ favorites: [String]) {
		store.favoriteEmojis = favorites
		// No-op unless the user already added the keyboard in step 1 and it's live; harmless otherwise.
		notifier.post(.favoriteEmojis)
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
