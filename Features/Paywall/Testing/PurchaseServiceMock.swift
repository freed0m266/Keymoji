//
//  PurchaseServiceMock.swift
//  Paywall
//
//  Created by Martin Svoboda on 15.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

#if DEBUG
import Foundation
import Observation
import KeymojiCore

/// In-memory `PurchaseServicing` for previews, snapshots, and view-model tests across features
/// (favorites editor, settings, paywall). Lives in `Paywall/Testing` so any feature that depends on
/// `Paywall` can inject a deterministic entitlement without touching StoreKit.
@Observable
@MainActor
public final class PurchaseServiceMock: PurchaseServicing {
	public var isPlus: Bool
	public var displayPrice: String?
	public var isProductLoaded: Bool

	/// Outcome the next `purchase()` should yield. Defaults to a clean unlock.
	public var nextPurchaseOutcome: PurchaseOutcome
	/// What `restore()` should resolve the entitlement to.
	public var restoreGrantsPlus: Bool

	public private(set) var loadProductsCallCount = 0
	public private(set) var purchaseCallCount = 0
	public private(set) var restoreCallCount = 0

	public init(
		isPlus: Bool = false,
		displayPrice: String? = "$3.99",
		isProductLoaded: Bool = true,
		nextPurchaseOutcome: PurchaseOutcome = .success,
		restoreGrantsPlus: Bool = false
	) {
		self.isPlus = isPlus
		self.displayPrice = displayPrice
		self.isProductLoaded = isProductLoaded
		self.nextPurchaseOutcome = nextPurchaseOutcome
		self.restoreGrantsPlus = restoreGrantsPlus
	}

	public func loadProducts() async {
		loadProductsCallCount += 1
		isProductLoaded = true
	}

	public func purchase() async -> PurchaseOutcome {
		purchaseCallCount += 1
		if case .success = nextPurchaseOutcome {
			isPlus = true
		}
		return nextPurchaseOutcome
	}

	public func restore() async -> Bool {
		restoreCallCount += 1
		if restoreGrantsPlus {
			isPlus = true
		}
		return isPlus
	}

	public func refreshEntitlement() async {}
}
#endif
