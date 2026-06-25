//
//  SettingsViewModel.swift
//  Settings
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation
import KeymojiCore
import KeyboardCore
import Paywall

/// The four mutually-exclusive states of the Settings "Keymoji Plus" row. Replaces the old 2-state
/// `if isPlus` so the opt-in Welcome trial gets a permanent entry point (S2) that turns into a
/// countdown (S3) and finally a loss-aversion paywall (S4). See task 64 Scope 6.
public enum PlusRowState: Equatable, Sendable {
	/// Paid Plus owned. "Unlocked ✓", no action.
	case paid
	/// Free user who hasn't taken the Welcome gift and isn't in a trial — offer it (confirm → activate).
	case welcomeAvailable
	/// A Welcome promo trial is running. Info only, no CTA (don't upsell mid-trial).
	case trialActive(daysLeft: Int)
	/// The Welcome trial was taken and has expired — the loss-aversion paywall entry (`.afterTrial`).
	case afterTrial
}

@MainActor
public protocol SettingsViewModeling: Observable, AnyObject {
	var showNumberRow: Bool { get set }
	var hapticFeedbackEnabled: Bool { get set }
	var keyClickSoundEnabled: Bool { get set }
	var appearance: AppearancePreference { get set }
	var spaceDoubleTapAction: SpaceDoubleTapAction { get set }
	var letterLayout: LetterLayout { get set }
	var letterAlternateSet: LetterAlternateSet { get set }
	var suggestionsEnabled: Bool { get set }
	var learnedWordCount: Int { get }
	/// *Effective* Plus — paid or an active promo trial. Convenience for non-row gates.
	var isPlus: Bool { get }
	/// Drives the 4-state Plus row (unlocked / activate-gift / trial-countdown / get-it-back).
	var plusRowState: PlusRowState { get }
	/// The active *Plus trial expiry*, or `nil` when no trial is running — drives the activation toast's date.
	var trialActiveUntil: Date? { get }

	/// Recompute `learnedWordCount` from the store (the keyboard mutates it out-of-process, and the
	/// Learned words editor can delete entries). Refresh on view appear.
	func refreshLearnedWordCount()
	/// Activate the opt-in Welcome trial (after the confirm alert). No-op if already consumed or paid.
	func activateWelcomeTrial()
}

@MainActor
public func settingsVM() -> some SettingsViewModeling {
	let promoStore = PromoTrialStore.makeShared()
	return SettingsViewModel(
		purchaseService: PurchaseService.shared,
		promoStore: promoStore,
		welcomeActivator: WelcomeTrialActivator(promoStore: promoStore, purchaseService: PurchaseService.shared)
	)
}

@Observable
final class SettingsViewModel: BaseViewModel, SettingsViewModeling {

	var showNumberRow: Bool {
		didSet {
			store.showNumberRow = showNumberRow
			notifier.post(.showNumberRow)
		}
	}

	var hapticFeedbackEnabled: Bool {
		didSet {
			store.hapticFeedbackEnabled = hapticFeedbackEnabled
			notifier.post(.hapticFeedbackEnabled)
		}
	}

	var keyClickSoundEnabled: Bool {
		didSet {
			store.keyClickSoundEnabled = keyClickSoundEnabled
			notifier.post(.keyClickSoundEnabled)
		}
	}

	var appearance: AppearancePreference {
		didSet {
			store.appearance = appearance
			notifier.post(.appearance)
		}
	}

	var spaceDoubleTapAction: SpaceDoubleTapAction {
		didSet {
			store.spaceDoubleTapAction = spaceDoubleTapAction
			notifier.post(.spaceDoubleTapAction)
		}
	}

	var letterLayout: LetterLayout {
		didSet {
			store.letterLayout = letterLayout
			notifier.post(.letterLayout)
		}
	}

	var letterAlternateSet: LetterAlternateSet {
		didSet {
			store.letterAlternateSet = letterAlternateSet
			notifier.post(.letterAlternateSet)
		}
	}

	var suggestionsEnabled: Bool {
		didSet {
			store.suggestionsEnabled = suggestionsEnabled
			notifier.post(.suggestionsEnabled)
		}
	}

	private(set) var learnedWordCount: Int = 0

	/// Observable mirrors of the promo state so the row recomputes live after an in-screen activation
	/// (and any cross-process change to the shared promo expiry, via `.promoPlusExpiresAt`).
	private var promoExpiresAt: Date?
	private var welcomeConsumed: Bool = false

	/// *Effective* Plus — paid or an active promo trial.
	var isPlus: Bool {
		effectiveIsPlus(paid: purchaseService.isPlus, promoExpiresAt: promoExpiresAt, now: Date())
	}

	var plusRowState: PlusRowState {
		if purchaseService.isPlus { return .paid }                          // S1
		let now = Date()
		if let expiry = promoExpiresAt, now < expiry {                      // S3 — any active trial
			// Ceil so a just-activated 30-day trial reads "30 days", and the last ~hours read "1 day".
			let daysLeft = max(1, Int(ceil(expiry.timeIntervalSince(now) / 86_400)))
			return .trialActive(daysLeft: daysLeft)
		}
		// Not paid, no active trial. If the Welcome gift was already taken (and lapsed) → loss-aversion
		// paywall. Otherwise it's still on the table (the gift hasn't been taken).
		return welcomeConsumed ? .afterTrial : .welcomeAvailable            // S4 / S2
	}

	var trialActiveUntil: Date? {
		guard let expiry = promoExpiresAt, Date() < expiry else { return nil }
		return expiry
	}

	private let store: AppGroupStore
	private let notifier: SettingsChangeNotifier
	private let recentsStore: PersonalRecentsStore
	private let purchaseService: any PurchaseServicing
	private let promoStore: any PromoTrialStoring
	private let welcomeActivator: any WelcomeTrialActivating
	/// Keeps the `.promoPlusExpiresAt` subscription alive for the VM's lifetime.
	private var promoObservation: SettingsObservationToken?

	// MARK: - Init

	init(
		store: AppGroupStore = .shared,
		notifier: SettingsChangeNotifier = .shared,
		purchaseService: any PurchaseServicing,
		promoStore: any PromoTrialStoring,
		welcomeActivator: any WelcomeTrialActivating
	) {
		self.store = store
		self.notifier = notifier
		self.purchaseService = purchaseService
		self.promoStore = promoStore
		self.welcomeActivator = welcomeActivator
		self.recentsStore = PersonalRecentsStore(store: store)
		self.showNumberRow = store.showNumberRow
		self.hapticFeedbackEnabled = store.hapticFeedbackEnabled
		self.keyClickSoundEnabled = store.keyClickSoundEnabled
		self.appearance = store.appearance
		self.spaceDoubleTapAction = store.spaceDoubleTapAction
		self.letterLayout = store.letterLayout
		self.letterAlternateSet = store.letterAlternateSet
		self.suggestionsEnabled = store.suggestionsEnabled
		super.init()
		self.learnedWordCount = recentsStore.count(atLeast: WordCompletionProvider.minSuggestCount)
		refreshPromoState()
		// A cross-process change to the shared promo expiry lands here — refresh the row live.
		promoObservation = notifier.addObserver(for: .promoPlusExpiresAt) { [weak self] in
			self?.refreshPromoState()
		}
	}

	// MARK: - Public API

	func refreshLearnedWordCount() {
		learnedWordCount = recentsStore.count(atLeast: WordCompletionProvider.minSuggestCount)
	}

	func activateWelcomeTrial() {
		// The activator owns consume → App Group mirror → notify; we just re-read the resulting state so
		// the row flips S2 → S3 immediately (the notifier round-trip would also refresh, but async).
		welcomeActivator.activate()
		refreshPromoState()
	}

	// MARK: - Private API

	/// Pull the promo mirrors from the Keychain master + App Group hot path into observable state.
	private func refreshPromoState() {
		promoExpiresAt = store.promoPlusExpiresAt
		welcomeConsumed = promoStore.record.welcomeConsumed
	}
}
