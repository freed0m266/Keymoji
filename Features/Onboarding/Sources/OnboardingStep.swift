//
//  OnboardingStep.swift
//  Onboarding
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation

/// Steps shown in the onboarding flow. The first three are manual actions the user has to take in
/// iOS Settings before Keymoji is usable; the fourth lets the user seed their favorites and the
/// last is a feature tour that surfaces capabilities the user wouldn't otherwise discover from the
/// keyboard layout.
public enum OnboardingStep: Int, CaseIterable, Identifiable {
	/// Settings → General → Keyboards → Keyboards → Add New Keyboard → Keymoji
	case addKeyboard
	/// Settings → General → Keyboards → Keymoji → Allow Full Access
	case allowFullAccess
	/// In any text field, tap the globe key and pick Keymoji
	case selectKeyboard
	/// In-app pick of starter favorite emoji — see [[OnboardingView]]'s favorites grid.
	case pickFavorites
	/// Discovery screen — see [[FeatureHighlight]] for the rendered list.
	case featureTour

	public var id: Int { rawValue }
}
