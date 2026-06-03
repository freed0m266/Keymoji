//
//  RootView.swift
//  Keymoji
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import KeymojiCore
import Onboarding
import Settings

/// Top-level switch between onboarding flow and the main settings UI.
/// Onboarding is shown the first time the app launches; afterwards the user lands in Settings.
struct RootView<OnboardingVM: OnboardingViewModeling, SettingsVM: SettingsViewModeling>: View {
	// `@State` initializers run once per view instance — this guarantees we don't spawn a fresh
	// polling task on every `body` recomputation. Codex P2 from task 11.
	@State private var onboardingViewModel: OnboardingVM
	@State private var settingsViewModel: SettingsVM
	@State private var hasFinishedOnboarding: Bool = OnboardingPreferences().isOnboardingComplete

	init(onboardingViewModel: OnboardingVM, settingsViewModel: SettingsVM) {
		_onboardingViewModel = State(initialValue: onboardingViewModel)
		_settingsViewModel = State(initialValue: settingsViewModel)
	}

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
