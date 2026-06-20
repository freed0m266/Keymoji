import Foundation
import Observation

/// Why the paywall was presented. Drives only the headline copy — the offer, price, and CTA are
/// identical regardless of entry point (one SKU, one price; no paradox-of-choice). `Identifiable`
/// so it can directly drive a SwiftUI `.sheet(item:)`.
public enum PaywallContext: String, Identifiable, Sendable, CaseIterable {
	/// User tried to add a favorite past the free limit.
	case favoritesLimit
	/// User tapped the locked "Most used" (frequency) sort.
	case frequencySort
	/// User opened the paywall from the Settings "Keymoji Plus" row.
	case settings
	/// User had a Welcome Plus trial that has since expired — the loss-aversion entry point. Drives the
	/// "You loved Plus. Get it back." headline. See task 64 Scope 8.
	case afterTrial

	public var id: String { rawValue }
}

/// Host-app gateway to the single "Keymoji Plus" non-consumable unlock, abstracted behind a protocol
/// so view models can be driven by a mock in tests and SwiftUI previews.
///
/// The concrete `PurchaseService` (StoreKit 2) lives in the **`Paywall` feature**, not here and not in
/// the keyboard extension: `KeymojiCore` is linked into the extension and built extension-safe, so it
/// must stay StoreKit-free. The extension only ever reads the `AppGroupStore.isPlus` mirror that the
/// concrete service writes after each entitlement change.
///
/// `Observable` so SwiftUI re-renders paywall / gated UI the instant `isPlus` flips (e.g. a restore on
/// another screen). `@MainActor` because every conformer mutates observable state and touches StoreKit.
@MainActor
public protocol PurchaseServicing: Observable, AnyObject {

	/// Whether the user owns Keymoji Plus. Mirrors `AppGroupStore.isPlus`; flipping it gates the whole
	/// freemium boundary (favorites limit, frequency sort, paging).
	var isPlus: Bool { get }

	/// Localized price string for the Plus product straight from StoreKit (e.g. "$3.99", "99 Kč"),
	/// or `nil` until `loadProducts()` resolves. **Never hardcode the price in UI — show this.**
	var displayPrice: String? { get }

	/// True once `loadProducts()` has resolved the Plus product (success path). Paywall shows a loading
	/// state until then so the CTA never renders without a real, localized price.
	var isProductLoaded: Bool { get }

	/// Resolve the Plus product from the App Store (or local `.storekit` config in the simulator) so
	/// `displayPrice` becomes available. Idempotent; safe to call on every paywall appearance.
	func loadProducts() async

	/// Kick off the system purchase sheet. Returns the outcome so the paywall can show success,
	/// stay put on user-cancel, or surface a graceful error. On `.success`, `isPlus` is already `true`
	/// and the `AppGroupStore` mirror + `.isPlus` notification have been posted.
	func purchase() async -> PurchaseOutcome

	/// Apple-required restore for non-consumables: re-sync transactions, then refresh the entitlement.
	/// Returns whether Plus is owned after the sync.
	func restore() async -> Bool

	/// Re-evaluate current entitlements on demand (also run by the launch-time `Transaction.updates`
	/// listener) and write the result through to `AppGroupStore.isPlus` + post `.isPlus`.
	func refreshEntitlement() async
}

/// Outcome of a purchase attempt, kept deliberately small so the paywall can branch on it without
/// knowing any StoreKit types.
public enum PurchaseOutcome: Sendable, Equatable {
	/// Verified purchase finished; Plus is unlocked.
	case success
	/// User dismissed the purchase sheet — not an error, the paywall just stays open.
	case cancelled
	/// Purchase is deferred (e.g. Ask to Buy) — nothing to celebrate yet, no error to show.
	case pending
	/// Something failed; `message` is a short, already-localized, user-safe string.
	case failed(message: String)
}
