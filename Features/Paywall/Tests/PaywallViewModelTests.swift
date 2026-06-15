//
//  PaywallViewModelTests.swift
//  Paywall_Tests
//
//  Created by Martin Svoboda on 15.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import XCTest
import KeymojiCore
@testable import Paywall

@MainActor
final class PaywallViewModelTests: XCTestCase {

	func testInit_mirrorsServiceState() {
		let service = PurchaseServiceMock(isPlus: true, displayPrice: "99 Kč")
		let vm = PaywallViewModel(context: .settings, service: service)
		XCTAssertTrue(vm.isPlus)
		XCTAssertEqual(vm.displayPrice, "99 Kč")
		XCTAssertEqual(vm.context, .settings)
	}

	func testOnAppear_loadsProducts() async {
		let service = PurchaseServiceMock(isProductLoaded: false)
		let vm = PaywallViewModel(context: .favoritesLimit, service: service)
		await vm.onAppear()
		XCTAssertEqual(service.loadProductsCallCount, 1)
		XCTAssertTrue(vm.isProductLoaded)
	}

	func testPurchase_success_setsDidUnlock() async {
		let service = PurchaseServiceMock(nextPurchaseOutcome: .success)
		let vm = PaywallViewModel(context: .favoritesLimit, service: service)
		await vm.purchase()
		XCTAssertTrue(vm.didUnlock)
		XCTAssertTrue(vm.isPlus)
		XCTAssertNil(vm.purchaseError)
		XCTAssertFalse(vm.isWorking)
	}

	func testPurchase_cancelled_staysSilent() async {
		let service = PurchaseServiceMock(nextPurchaseOutcome: .cancelled)
		let vm = PaywallViewModel(context: .favoritesLimit, service: service)
		await vm.purchase()
		XCTAssertFalse(vm.didUnlock)
		XCTAssertNil(vm.purchaseError)
	}

	func testPurchase_failed_showsGracefulError() async {
		let service = PurchaseServiceMock(nextPurchaseOutcome: .failed(message: "boom"))
		let vm = PaywallViewModel(context: .favoritesLimit, service: service)
		await vm.purchase()
		XCTAssertFalse(vm.didUnlock)
		XCTAssertNotNil(vm.purchaseError)
		// The user-facing copy is the friendly generic string, not the raw StoreKit message.
		XCTAssertNotEqual(vm.purchaseError, "boom")
	}

	func testRestore_grantsPlus_setsDidUnlock() async {
		let service = PurchaseServiceMock(restoreGrantsPlus: true)
		let vm = PaywallViewModel(context: .settings, service: service)
		await vm.restore()
		XCTAssertTrue(vm.didUnlock)
		XCTAssertTrue(vm.isPlus)
	}

	func testRestore_nothingToRestore_showsError() async {
		let service = PurchaseServiceMock(restoreGrantsPlus: false)
		let vm = PaywallViewModel(context: .settings, service: service)
		await vm.restore()
		XCTAssertFalse(vm.didUnlock)
		XCTAssertNotNil(vm.purchaseError)
	}

	func testDismissError_clears() async {
		let service = PurchaseServiceMock(nextPurchaseOutcome: .failed(message: "x"))
		let vm = PaywallViewModel(context: .favoritesLimit, service: service)
		await vm.purchase()
		XCTAssertNotNil(vm.purchaseError)
		vm.dismissError()
		XCTAssertNil(vm.purchaseError)
	}
}
