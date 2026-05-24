//
//  RootView.swift
//  Keybo
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import KeyboCore
import Onboarding
import Settings

/// Top-level switch between onboarding flow and the main settings UI.
/// Onboarding is shown the first time the app launches; afterwards the user lands in Settings.
struct RootView: View {
	// `@State` initializers run once per view instance — this guarantees we don't spawn a fresh
	// polling task on every `body` recomputation. Codex P2 from task 11.
	@State private var onboardingViewModel: OnboardingViewModel = onboardingVM()
	@State private var settingsViewModel: SettingsViewModel = settingsVM()
	@State private var hasFinishedOnboarding: Bool = OnboardingPreferences().isOnboardingComplete

	var body: some View {
		if hasFinishedOnboarding {
			SettingsView(viewModel: settingsViewModel)
				.preferredColorScheme(.dark)
		} else {
			OnboardingView(viewModel: onboardingViewModel, onFinish: {
				hasFinishedOnboarding = true
			})
		}
	}
}
