//
//  OnboardingStep.swift
//  Onboarding
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation

/// Three manual steps the user has to take in iOS Settings before Keybo is usable.
public enum OnboardingStep: Sendable, Hashable, CaseIterable {
	/// Settings → General → Keyboards → Keyboards → Add New Keyboard → Keybo
	case addKeyboard
	/// Settings → General → Keyboards → Keybo → Allow Full Access
	case allowFullAccess
	/// In any text field, tap the globe key and pick Keybo
	case selectKeyboard
}
