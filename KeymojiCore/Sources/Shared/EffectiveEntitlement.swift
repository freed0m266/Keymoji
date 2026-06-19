import Foundation

/// The unified "is this user entitled to Plus features right now" check, used at **every** gate
/// (favorites limit, frequency sort, paging, paywall headlines). Combines the permanent paid
/// entitlement with a time-boxed promo trial expiry into one boolean.
///
/// `AppGroupStore.isPlus` deliberately stays **paid-only** (the clean StoreKit truth source); the
/// promo trial lives alongside it as `AppGroupStore.promoPlusExpiresAt`. Gating code must read this
/// helper, never `isPlus` directly — see task 64 Scope 4 for the migrated call sites.
///
/// Pure and StoreKit-free so the keyboard extension can call it from the `AppGroupStore` mirrors it
/// already reads, without linking StoreKit.
///
/// - Parameters:
///   - paid: The permanent paid entitlement (`AppGroupStore.isPlus`). Wins unconditionally.
///   - promoExpiresAt: The shared *Plus trial expiry* (`AppGroupStore.promoPlusExpiresAt`), or `nil`
///     when no trial/promo grant is active.
///   - now: The current instant. Injected so callers (and tests) control the clock.
/// - Returns: `true` if the user owns Plus, or a promo grant is still in the future.
public func effectiveIsPlus(paid: Bool, promoExpiresAt: Date?, now: Date) -> Bool {
	if paid { return true }
	if let expiry = promoExpiresAt, now < expiry { return true }
	return false
}
