//
//  OnboardingSnapshots.swift
//  Onboarding_Tests
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import XCTest
import SwiftUI
import SnapshotTesting
@testable import Onboarding

@MainActor
final class OnboardingSnapshots: XCTestCase {

	private static let size = CGSize(width: 393, height: 852) // iPhone 17 portrait

	func testStep1_addKeyboard_dark() {
		let view = OnboardingView(
			viewModel: OnboardingViewModelMock(currentStep: .addKeyboard)
		)
		assertOnboardingSnapshot(view)
	}

	func testStep1_addKeyboard_detected_dark() {
		let view = OnboardingView(
			viewModel: OnboardingViewModelMock(currentStep: .addKeyboard, isKeyboardActivated: true)
		)
		assertOnboardingSnapshot(view)
	}

	func testStep2_allowFullAccess_dark() {
		let view = OnboardingView(
			viewModel: OnboardingViewModelMock(currentStep: .allowFullAccess)
		)
		assertOnboardingSnapshot(view)
	}

	func testStep3_selectKeyboard_dark() {
		let view = OnboardingView(
			viewModel: OnboardingViewModelMock(currentStep: .selectKeyboard)
		)
		assertOnboardingSnapshot(view)
	}

	// MARK: - Helper

	private func assertOnboardingSnapshot<V: View>(
		_ view: V,
		record: Bool = false,
		file: StaticString = #filePath,
		testName: String = #function,
		line: UInt = #line
	) {
		let host = view.frame(width: Self.size.width, height: Self.size.height)
		assertSnapshot(
			of: host,
			as: .image(
				drawHierarchyInKeyWindow: false,
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
