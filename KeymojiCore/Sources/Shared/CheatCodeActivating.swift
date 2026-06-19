import Foundation

/// Outcome of typing the cheat code cheat code — drives the keyboard's effect + banner copy.
public enum CheatCodeOutcome: Equatable, Sendable {
	/// Promo granted (or extended). `wasExtension` is true when a trial was already running before this
	/// grant (Welcome or an earlier promo) — drives "Plus extended" vs "Plus unlocked — 60 days".
	case granted(newExpiry: Date, wasExtension: Bool)
	/// Paid Plus is already owned — celebrate, but don't spend the one-shot token.
	case alreadyHavePaidPlus
	/// The cheat code bonus was already consumed on this device — no effect, no grant.
	case alreadyUsed
}

/// Activates the cheat code promo bonus from the keyboard extension. The extension counterpart of
/// `WelcomeTrialActivating` — lighter: it has **no `PurchaseServicing`** (the extension never links
/// StoreKit), so the paid check reads the `AppGroupStore.isPlus` mirror instead.
@MainActor
public protocol CheatCodeActivating {
	/// Resolve the cheat: grant (+60 days, stacking), or report already-paid / already-used.
	func activate(now: Date) -> CheatCodeOutcome
}

@MainActor
public final class CheatCodeActivator: CheatCodeActivating {

	private let promoStore: any PromoTrialStoring
	private let appGroup: AppGroupStore
	private let notifier: SettingsChangeNotifier

	public init(
		promoStore: any PromoTrialStoring,
		appGroup: AppGroupStore = .shared,
		notifier: SettingsChangeNotifier = .shared
	) {
		self.promoStore = promoStore
		self.appGroup = appGroup
		self.notifier = notifier
	}

	public func activate(now: Date) -> CheatCodeOutcome {
		// Paid wins — read the paid-only mirror (NOT effective Plus): a user mid-promo-trial (not paid)
		// must still be able to stack cheat code on top, so we only short-circuit for a real purchase.
		guard !appGroup.isPlus else { return .alreadyHavePaidPlus }
		guard !promoStore.record.cheatCodeConsumed else { return .alreadyUsed }

		// "Extension" vs "cold unlock": was a trial already running the instant before we granted?
		let wasExtension = promoStore.record.expiresAt.map { now < $0 } ?? false
		let newExpiry = promoStore.consumeCheatCode(now: now)
		appGroup.promoPlusExpiresAt = newExpiry
		notifier.post(.promoPlusExpiresAt)
		return .granted(newExpiry: newExpiry, wasExtension: wasExtension)
	}
}
