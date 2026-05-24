//
//  OnboardingDependencies.swift
//  Onboarding
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import KeyboCore

public protocol OnboardingPreferencesProviding: Sendable {
	var isOnboardingComplete: Bool { get }
	func markOnboardingComplete()
}

public struct OnboardingPreferences: OnboardingPreferencesProviding {
	private let store: AppGroupStore

	public init(store: AppGroupStore = .shared) {
		self.store = store
	}

	public var isOnboardingComplete: Bool {
		store.onboardingComplete
	}

	public func markOnboardingComplete() {
		store.onboardingComplete = true
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
