//
//  PaywallViewModelMock.swift
//  Paywall
//
//  Created by Martin Svoboda on 15.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

#if DEBUG
import Foundation
import Observation
import KeymojiCore

@Observable
@MainActor
public final class PaywallViewModelMock: PaywallViewModeling {
	public var context: PaywallContext
	public var isPlus: Bool
	public var displayPrice: String?
	public var isProductLoaded: Bool
	public var isLoadingProducts: Bool
	public var isWorking: Bool
	public var didUnlock: Bool
	public var purchaseError: String?

	public init(
		context: PaywallContext = .favoritesLimit,
		isPlus: Bool = false,
		displayPrice: String? = "$3.99",
		isProductLoaded: Bool = true,
		isLoadingProducts: Bool = false,
		isWorking: Bool = false,
		didUnlock: Bool = false,
		purchaseError: String? = nil
	) {
		self.context = context
		self.isPlus = isPlus
		self.displayPrice = displayPrice
		self.isProductLoaded = isProductLoaded
		self.isLoadingProducts = isLoadingProducts
		self.isWorking = isWorking
		self.didUnlock = didUnlock
		self.purchaseError = purchaseError
	}

	public func onAppear() async {}

	public func purchase() async {
		didUnlock = true
		isPlus = true
	}

	public func restore() async {
		didUnlock = isPlus
	}

	public func dismissError() {
		purchaseError = nil
	}
}
#endif
