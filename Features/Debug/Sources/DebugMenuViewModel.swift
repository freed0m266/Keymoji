//
//  DebugMenuViewModel.swift
//  Debug
//
//  Created by Martin Svoboda on 19.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

#if DEBUG
import Foundation
import KeymojiCore

/// Concrete, DEBUG-only view model behind the developer "simulate a fresh / free user" menu (task 67).
/// Deliberately **no protocol / no mock** — it lives outside the shipped surface, exercised by hand on
/// device. Every action is **non-destructive to user content**: it never touches favorites, learned
/// words, recents, or usage counts — only the entitlement / promo / onboarding flags those flows read.
///
/// Two mutation strategies, matching the task's hybrid decision:
/// - **Override** (Plus): a real StoreKit entitlement can't be reset from inside the app, so `forceFreeTier`
///   *masks* it. Toggle off → `refreshEntitlement()` re-applies the true value and real Plus returns.
/// - **Reset** (onboarding / gift / cheat code): really rewrites the app-owned flag so the corresponding
///   flow can be replayed for real.
@Observable
@MainActor
public final class DebugMenuViewModel: BaseViewModel {

	private let store: AppGroupStore
	private let notifier: SettingsChangeNotifier
	private let promoStore: PromoTrialStore
	private let purchaseService: any PurchaseServicing

	/// Keep the live-readout subscriptions alive for the VM's lifetime. A grant from the keyboard
	/// (`.promoPlusExpiresAt`) or the async entitlement refresh (`.isPlus`) refreshes the readout in place.
	private var promoObservation: SettingsObservationToken?
	private var isPlusObservation: SettingsObservationToken?

	// MARK: - Live readout (observable mirrors, refreshed after every action)

	/// `forceFreeTier` is on — paid Plus is being masked to free.
	public private(set) var forceFreeTier: Bool = false
	/// The (possibly masked) paid-Plus mirror the rest of the app reads (`AppGroupStore.isPlus`).
	public private(set) var paidMirror: Bool = false
	/// The shared *Plus trial expiry* mirror, or `nil` when no promo grant is active.
	public private(set) var promoExpiresAt: Date?
	public private(set) var onboardingComplete: Bool = false
	public private(set) var welcomeConsumed: Bool = false
	public private(set) var cheatCodeConsumed: Bool = false

	/// Effective Plus exactly as every gate computes it (paid mirror OR an active promo trial). With
	/// `forceFreeTier` on and no active promo, this reads `false` — the simulated free-user state.
	public var effectivePlus: Bool {
		effectiveIsPlus(paid: paidMirror, promoExpiresAt: promoExpiresAt, now: Date())
	}

	// MARK: - Init

	public init(
		store: AppGroupStore = .shared,
		notifier: SettingsChangeNotifier = .shared,
		promoStore: PromoTrialStore = .makeShared(),
		purchaseService: any PurchaseServicing = PurchaseService.shared
	) {
		self.store = store
		self.notifier = notifier
		self.promoStore = promoStore
		self.purchaseService = purchaseService
		super.init()
		refresh()
		promoObservation = notifier.addObserver(for: .promoPlusExpiresAt) { [weak self] in
			self?.refresh()
		}
		isPlusObservation = notifier.addObserver(for: .isPlus) { [weak self] in
			self?.refresh()
		}
	}

	// MARK: - Actions

	/// Toggle the "simulate a free user" mask, then re-run the entitlement check so the App Group mirror,
	/// observable `isPlus`, and the `.isPlus` notification all update live (UI + a running keyboard). The
	/// real StoreKit entitlement is never written — turning the mask off restores real Plus.
	public func toggleForceFreeTier() {
		DebugOverrides.forceFreeTier.toggle()
		refresh()                                  // reflect the flag immediately
		Task {
			await purchaseService.refreshEntitlement()
			refresh()                              // reflect the re-applied (masked / restored) entitlement
		}
	}

	/// Reset onboarding so the welcome flow runs again. **Takes effect only after an app restart** —
	/// `RootView` reads `onboardingComplete` once at `@State` init. Favorites / learned words are untouched.
	public func resetOnboarding() {
		store.onboardingComplete = false
		refresh()
	}

	/// Reset the opt-in Welcome gift so it can be taken again. Clears `welcomeConsumed` **and the whole
	/// shared promo expiry** (the two grants stack into one `Date` that can't be unstacked → resetting any
	/// grant zeroes the promo clock, deliberately). Mirrors `nil` + notify so a running keyboard relocks.
	public func resetGift() {
		var record = promoStore.record
		record.welcomeConsumed = false
		record.expiresAt = nil
		clearPromo(record)
	}

	/// Reset the cheat code promo so it fires again. Same shared-expiry caveat as `resetGift()`: clears
	/// `cheatCodeConsumed` and zeroes the promo clock.
	public func resetCheatCode() {
		var record = promoStore.record
		record.cheatCodeConsumed = false
		record.expiresAt = nil
		clearPromo(record)
	}

	/// Expire an active trial *now*: mark Welcome consumed and push the shared expiry into the past, so the
	/// "trial ended" surfaces unlock — Settings S4, the editor loss-aversion banner, and the `.afterTrial`
	/// paywall. Visible only with `forceFreeTier` on (otherwise real paid Plus masks the lapsed promo).
	public func expireTrialNow() {
		let past = Date().addingTimeInterval(-3600)
		var record = promoStore.record
		record.welcomeConsumed = true
		record.expiresAt = past
		promoStore.debugWrite(record)
		store.promoPlusExpiresAt = past
		notifier.post(.promoPlusExpiresAt)
		refresh()
	}

	// MARK: - Private

	/// Persist the rewritten record, drop the App Group mirror, and announce the change so the keyboard
	/// re-reads the (now-absent) promo. Shared by the two reset actions.
	private func clearPromo(_ record: PromoTrialRecord) {
		promoStore.debugWrite(record)
		store.promoPlusExpiresAt = nil
		notifier.post(.promoPlusExpiresAt)
		refresh()
	}

	/// Pull the current state from the stores into the observable mirrors so the readout reflects it.
	private func refresh() {
		forceFreeTier = DebugOverrides.forceFreeTier
		paidMirror = store.isPlus
		promoExpiresAt = store.promoPlusExpiresAt
		onboardingComplete = store.onboardingComplete
		let record = promoStore.record
		welcomeConsumed = record.welcomeConsumed
		cheatCodeConsumed = record.cheatCodeConsumed
	}
}

@MainActor
public func debugMenuVM() -> DebugMenuViewModel {
	DebugMenuViewModel()
}
#endif
