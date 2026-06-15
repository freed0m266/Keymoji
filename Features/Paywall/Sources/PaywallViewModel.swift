//
//  PaywallViewModel.swift
//  Paywall
//
//  Created by Martin Svoboda on 15.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import Foundation
import Observation
import KeymojiCore
import KeymojiResources

@MainActor
public protocol PaywallViewModeling: Observable, AnyObject {
	/// Entry point that opened the paywall — drives only the headline.
	var context: PaywallContext { get }
	/// Whether Plus is already owned (drives the already-unlocked layout).
	var isPlus: Bool { get }
	/// Localized price from StoreKit, or nil while loading. Never hardcoded.
	var displayPrice: String? { get }
	/// True once the product (and its price) has loaded — until then the CTA shows a loading state.
	var isProductLoaded: Bool { get }
	/// A product fetch is in flight. Lets the view tell "still loading" (spinner) from "load failed"
	/// (retry) instead of spinning forever when the App Store can't return the product.
	var isLoadingProducts: Bool { get }
	/// A purchase or restore is in flight (CTA spinner; controls disabled).
	var isWorking: Bool { get }
	/// Set the instant a buy/restore unlocks Plus — drives the celebratory success state.
	var didUnlock: Bool { get }
	/// A graceful, already-localized error to show inline (never a scary system alert). Named
	/// `purchaseError` rather than `errorMessage` to avoid colliding with `BaseViewModel.errorMessage`.
	var purchaseError: String? { get }

	/// Resolve the product so `displayPrice` is ready. Call on appear.
	func onAppear() async
	func purchase() async
	func restore() async
	func dismissError()
}

@MainActor
public func paywallVM(context: PaywallContext) -> some PaywallViewModeling {
	PaywallViewModel(context: context, service: PurchaseService.shared)
}

@Observable
final class PaywallViewModel: BaseViewModel, PaywallViewModeling {

	let context: PaywallContext

	private(set) var isWorking = false
	private(set) var didUnlock = false
	private(set) var isLoadingProducts = false
	// Named distinctly from `BaseViewModel.errorMessage`, which isn't `@Observable`-tracked here.
	private(set) var purchaseError: String?

	private let service: any PurchaseServicing

	typealias Texts = L10n.Paywall

	var isPlus: Bool { service.isPlus }
	var displayPrice: String? { service.displayPrice }
	var isProductLoaded: Bool { service.isProductLoaded }

	init(context: PaywallContext, service: any PurchaseServicing) {
		self.context = context
		self.service = service
		super.init()
	}

	func onAppear() async {
		guard !service.isProductLoaded else { return }
		isLoadingProducts = true
		await service.loadProducts()
		isLoadingProducts = false
	}

	func purchase() async {
		guard !isWorking else { return }
		isWorking = true
		purchaseError = nil
		defer { isWorking = false }

		switch await service.purchase() {
		case .success:
			didUnlock = true
		case .cancelled, .pending:
			break   // user backed out or it's awaiting approval — say nothing, leave the offer up
		case .failed:
			purchaseError = Texts.errorPurchase
		}
	}

	func restore() async {
		guard !isWorking else { return }
		isWorking = true
		purchaseError = nil
		defer { isWorking = false }

		let owned = await service.restore()
		if owned {
			didUnlock = true
		} else {
			purchaseError = Texts.errorNothingToRestore
		}
	}

	func dismissError() {
		purchaseError = nil
	}
}
