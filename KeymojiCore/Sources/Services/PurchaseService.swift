//
//  PurchaseService.swift
//  KeymojiCore
//
//  Created by Martin Svoboda on 15.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation
import Observation
import StoreKit

/// StoreKit 2 gateway for the single "Keymoji Plus" non-consumable unlock. The purchase flow runs
/// **only in the host app** — the keyboard extension never references this type; it reads only the
/// `AppGroupStore.isPlus` mirror this writes and reacts to the `.isPlus` Darwin notification.
///
/// On-device verification only (`VerificationResult.verified`): the app has no backend and won't get
/// one. Anti-piracy is deliberately not handled — App Store buyers overwhelmingly just pay, and the
/// trust/brand is the asset worth protecting.
@MainActor
@Observable
public final class PurchaseService: PurchaseServicing {

	/// App-wide shared instance. One observable source of truth so a purchase or restore made on any
	/// screen live-updates every paywall / gated control. Feature view models default to this.
	public static let shared = PurchaseService()

	/// Must match the product identifier in App Store Connect and the local `.storekit` config.
	public static let plusProductID = "com.freedommartin.keymoji.plus"

	public private(set) var isPlus: Bool
	public private(set) var displayPrice: String?
	public private(set) var isProductLoaded = false

	private var plusProduct: Product?
	private let store: AppGroupStore
	private let notifier: SettingsChangeNotifier
	/// Long-lived listener for transactions that arrive outside an explicit `purchase()` — Ask-to-Buy
	/// approvals, purchases made on another device, or a restore on a fresh install.
	private var updatesTask: Task<Void, Never>?

	public init(store: AppGroupStore = .shared, notifier: SettingsChangeNotifier = .shared) {
		self.store = store
		self.notifier = notifier
		// Seed from the last-known mirror so gated UI is correct on launch before StoreKit answers.
		self.isPlus = store.isPlus
	}

	// No `deinit` cleanup: `start()` is only called on the app-lifetime `shared` singleton, and the
	// listener task captures `[weak self]`, so a (test-only) instance that's released without `start()`
	// leaks nothing. Swift 6 also forbids touching the main-actor `updatesTask` from a nonisolated deinit.

	// MARK: - Lifecycle

	/// Start the `Transaction.updates` listener and do an initial entitlement check. Call once at app
	/// launch (idempotent). Catches purchases that complete while the app wasn't the one to start them.
	public func start() {
		guard updatesTask == nil else { return }
		updatesTask = Task { [weak self] in
			for await update in Transaction.updates {
				guard let self else { return }
				if case .verified(let transaction) = update {
					await transaction.finish()
				}
				await self.refreshEntitlement()
			}
		}
		Task { [weak self] in await self?.refreshEntitlement() }
	}

	// MARK: - PurchaseServicing

	public func loadProducts() async {
		do {
			let products = try await Product.products(for: [Self.plusProductID])
			guard let product = products.first else { return }
			plusProduct = product
			displayPrice = product.displayPrice
			isProductLoaded = true
		} catch {
			// Leave `isProductLoaded == false` → paywall keeps its loading/retry state. No crash, and
			// the only network touched is Apple's own product lookup (see the privacy reconciliation).
		}
	}

	public func purchase() async -> PurchaseOutcome {
		// Resolve lazily so a paywall that opened before `loadProducts()` finished can still buy.
		if plusProduct == nil { await loadProducts() }
		guard let product = plusProduct else {
			return .failed(message: "Product unavailable")
		}
		do {
			let result = try await product.purchase()
			switch result {
			case .success(let verification):
				guard case .verified(let transaction) = verification else {
					// Unverified (jailbreak / tampering). Don't unlock; let the user retry/restore.
					return .failed(message: "Could not verify the purchase")
				}
				await transaction.finish()
				await refreshEntitlement()
				return .success
			case .userCancelled:
				return .cancelled
			case .pending:
				return .pending
			@unknown default:
				return .failed(message: "Unknown purchase state")
			}
		} catch {
			return .failed(message: error.localizedDescription)
		}
	}

	public func restore() async -> Bool {
		do {
			try await AppStore.sync()
		} catch {
			// `AppStore.sync()` throws on user cancel of the sign-in sheet — not fatal. Re-check
			// entitlements anyway: a previously-synced purchase may already be present.
		}
		await refreshEntitlement()
		return isPlus
	}

	public func refreshEntitlement() async {
		var owned = false
		for await entitlement in Transaction.currentEntitlements {
			guard case .verified(let transaction) = entitlement else { continue }
			if transaction.productID == Self.plusProductID, transaction.revocationDate == nil {
				owned = true
			}
		}
		applyEntitlement(owned)
	}

	// MARK: - Private

	/// Writes the entitlement through to the shared store and posts the cross-process notification so a
	/// running keyboard unlocks live. Always reconciles the mirror (even when our in-memory copy already
	/// matched) so a store that drifted — e.g. reset in a test — is corrected.
	private func applyEntitlement(_ owned: Bool) {
		#if DEBUG
		// Debug "simulate a free user" override: mask a real (paid) entitlement to free so QA can exercise
		// the welcome / downgrade surfaces without resetting StoreKit. The real entitlement is
		// untouched — turning the flag off and refreshing re-applies the true `owned` value. Release builds
		// compile this branch out entirely (see `#else`), so no debug logic can leak into production.
		let effectiveOwned = owned && !DebugOverrides.forceFreeTier
		#else
		let effectiveOwned = owned
		#endif
		if store.isPlus != effectiveOwned {
			store.isPlus = effectiveOwned
			notifier.post(.isPlus)
		}
		if isPlus != effectiveOwned {
			isPlus = effectiveOwned
		}
	}
}

#if DEBUG
extension PurchaseService {
	/// Test seam: drive the entitlement writer directly (bypassing StoreKit) so the `forceFreeTier` mask
	/// can be unit-tested without a real transaction. DEBUG-only — never referenced by shipping code.
	func applyEntitlementForTesting(_ owned: Bool) {
		applyEntitlement(owned)
	}
}
#endif
