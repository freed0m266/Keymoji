import Foundation

/// A single anonymous analytics event. A closed enum (not a free-form name+dictionary) so boundary 2
/// — *never any content* — is enforced by the type system: there is no case that can carry typed
/// text, a learned word, a favourite emoji, or a search query. Every payload is an enumerated state
/// or a coarse bucket. See ADR 0004 and task 86 "Co trackovat".
public enum AnalyticsEvent: Sendable, Equatable {
	/// One snapshot of *which settings the user runs* — the core "what do people use" signal. Emitted
	/// by the host app at launch (`applicationDidBecomeActive`).
	case settingsSnapshot(AnalyticsSettingsSnapshot)
	/// First-run onboarding finished (funnel: activation).
	case onboardingCompleted
	/// The Plus paywall was surfaced (funnel: top). Carries only the entry-point label, never content.
	case paywallShown(context: PaywallContext)
	/// A Plus purchase completed (funnel: conversion).
	case purchaseCompleted
	/// The opt-in Welcome Plus trial was activated (funnel: conversion).
	case trialActivated
	/// The "Review on the App Store" button was tapped (task 83).
	case reviewTapped
	/// A Settings sub-screen was opened (navigation funnel).
	case settingsSubScreenOpened(AnalyticsSubScreen)

	/// Stable, dot-namespaced TelemetryDeck signal name. Fixed identifiers — never derived from user
	/// input. Renaming one splits its history in the dashboard, so treat these as a wire contract.
	public var signalName: String {
		switch self {
		case .settingsSnapshot:        return "Settings.snapshot"
		case .onboardingCompleted:     return "Lifecycle.onboardingCompleted"
		case .paywallShown:            return "Funnel.paywallShown"
		case .purchaseCompleted:       return "Funnel.purchaseCompleted"
		case .trialActivated:          return "Funnel.trialActivated"
		case .reviewTapped:            return "Funnel.reviewTapped"
		case .settingsSubScreenOpened: return "Navigation.settingsSubScreen"
		}
	}

	/// Custom signal parameters. **Allow-list only** — every value is an enum raw value or a coarse
	/// bucket, so no free text / content can ever reach the wire (boundary 2). Verified by
	/// `AnalyticsEventTests`.
	public var parameters: [String: String] {
		switch self {
		case .settingsSnapshot(let snapshot):
			return snapshot.parameters
		case .paywallShown(let context):
			return ["context": context.rawValue]
		case .settingsSubScreenOpened(let screen):
			return ["screen": screen.rawValue]
		case .onboardingCompleted, .purchaseCompleted, .trialActivated, .reviewTapped:
			return [:]
		}
	}
}

/// Which Settings sub-screen was opened. Raw values are the wire labels — fixed identifiers, no content.
public enum AnalyticsSubScreen: String, Sendable, Equatable, CaseIterable {
	case about
	case emojiCodes
	case learnedWords
	case favoritesEditor
}
