import Foundation

/// Activates the opt-in Welcome Plus trial. One use case, two surfaces (onboarding banner + Settings
/// row): consume the one-shot Keychain token, mirror the new *Plus trial expiry* into the App Group
/// hot path, and post `.promoPlusExpiresAt` so a running keyboard unlocks live. Keeping the
/// consume→mirror→notify sequence in one place is what makes the onboarding↔Settings consume race
/// safe (one `PromoTrialStoring`, one `AppGroupStore`, one notifier — see task 64 Rizika).
@MainActor
public protocol WelcomeTrialActivating {
	/// Activate the Welcome trial. Returns the new expiry on success, or `nil` when the gift was already
	/// taken on this device **or** paid Plus is already active — no token is spent in either case.
	@discardableResult func activate() -> Date?
}

@MainActor
public final class WelcomeTrialActivator: WelcomeTrialActivating {

	private let promoStore: any PromoTrialStoring
	private let appGroup: AppGroupStore
	private let notifier: SettingsChangeNotifier
	private let purchaseService: any PurchaseServicing

	public init(
		promoStore: any PromoTrialStoring,
		appGroup: AppGroupStore = .shared,
		notifier: SettingsChangeNotifier = .shared,
		purchaseService: any PurchaseServicing
	) {
		self.promoStore = promoStore
		self.appGroup = appGroup
		self.notifier = notifier
		self.purchaseService = purchaseService
	}

	@discardableResult
	public func activate() -> Date? {
		// Paid Plus already covers everything — don't burn the one-shot gift on someone who owns Plus.
		// Guard on the **paid** flag, not effective Plus: a user mid-cheat code (promo, not paid) may still
		// take Welcome — the grants stack onto the same expiry.
		guard !purchaseService.isPlus else { return nil }
		// Already taken on this device — idempotent no-op (covers a double tap and the onboarding↔Settings race).
		guard !promoStore.record.welcomeConsumed else { return nil }

		let expiry = promoStore.consumeWelcome(now: Date())
		appGroup.promoPlusExpiresAt = expiry
		notifier.post(.promoPlusExpiresAt)
		return expiry
	}
}

public extension WelcomeTrialActivator {
	/// Production activator wired to the shared Keychain store and the StoreKit purchase service.
	static func makeShared() -> WelcomeTrialActivator {
		WelcomeTrialActivator(
			promoStore: PromoTrialStore.makeShared(),
			purchaseService: PurchaseService.shared
		)
	}
}
