//
//  OnboardingStep.swift
//  Onboarding
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation

/// Steps shown in the onboarding flow. The first three are manual actions the user has to take in
/// iOS Settings before Keybo is usable; the fourth is a feature tour that surfaces capabilities
/// the user wouldn't otherwise discover from the keyboard layout.
public enum OnboardingStep: Sendable, Hashable, CaseIterable {
	/// Settings → General → Keyboards → Keyboards → Add New Keyboard → Keybo
	case addKeyboard
	/// Settings → General → Keyboards → Keybo → Allow Full Access
	case allowFullAccess
	/// In any text field, tap the globe key and pick Keybo
	case selectKeyboard
	/// Discovery screen — see [[FeatureHighlight]] for the rendered list.
	case featureTour
}
