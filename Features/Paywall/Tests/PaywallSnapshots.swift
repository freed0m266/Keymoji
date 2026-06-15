//
//  PaywallSnapshots.swift
//  Paywall_Tests
//
//  Created by Martin Svoboda on 15.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import XCTest
import SwiftUI
import SnapshotTesting
import KeymojiCore
@testable import Paywall

@MainActor
final class PaywallSnapshots: XCTestCase {

	private static let size = CGSize(width: 393, height: 852)

	func testPaywall_limit_purchasable_dark() {
		assertSnapshot(
			PaywallView(viewModel: PaywallViewModelMock(context: .favoritesLimit))
		)
	}

	func testPaywall_frequency_purchasable_dark() {
		assertSnapshot(
			PaywallView(viewModel: PaywallViewModelMock(context: .frequencySort))
		)
	}

	func testPaywall_loadingPrice_dark() {
		assertSnapshot(
			PaywallView(
				viewModel: PaywallViewModelMock(
					context: .settings,
					displayPrice: nil,
					isProductLoaded: false,
					isLoadingProducts: true
				)
			)
		)
	}

	func testPaywall_productsUnavailable_dark() {
		assertSnapshot(
			PaywallView(
				viewModel: PaywallViewModelMock(
					context: .settings,
					displayPrice: nil,
					isProductLoaded: false,
					isLoadingProducts: false
				)
			)
		)
	}

	func testPaywall_error_dark() {
		assertSnapshot(
			PaywallView(
				viewModel: PaywallViewModelMock(
					context: .favoritesLimit,
					purchaseError: "That didn't go through. No charge was made — please try again."
				)
			)
		)
	}

	func testPaywall_unlocked_dark() {
		assertSnapshot(
			PaywallView(viewModel: PaywallViewModelMock(context: .favoritesLimit, didUnlock: true))
		)
	}

	private func assertSnapshot<V: View>(
		_ view: V,
		record: Bool = false,
		file: StaticString = #filePath,
		testName: String = #function,
		line: UInt = #line
	) {
		let host = view.frame(width: Self.size.width, height: Self.size.height)
		SnapshotTesting.assertSnapshot(
			of: host,
			as: .image(
				// `true`: PaywallView leans on Liquid Glass (`glassEffect`, `.glassProminent`) and a
				// blurred mesh-gradient background, which can't sample a backdrop when rendered offscreen
				// — render it in the host app's key window instead (see Feature.swift's test-host note).
				drawHierarchyInKeyWindow: true,
				perceptualPrecision: 0.93,
				layout: .fixed(width: Self.size.width, height: Self.size.height),
				traits: .init(userInterfaceStyle: .dark)
			),
			record: record,
			file: file,
			testName: testName + "_dark",
			line: line
		)
	}
}
