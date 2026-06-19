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
	private static let iPhoneSESize = CGSize(width: 320, height: 568) // iPhone SE 1st gen portrait

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

	func testStep_pickFavorites_dark() {
		let view = OnboardingView(
			viewModel: OnboardingViewModelMock(currentStep: .pickFavorites)
		)
		assertOnboardingSnapshot(view)
	}

	func testStep_pickFavorites_someSelected_dark() {
		let view = OnboardingView(
			viewModel: OnboardingViewModelMock(
				currentStep: .pickFavorites,
				selectedFavorites: ["❤️", "🔥", "🎉"]
			)
		)
		assertOnboardingSnapshot(view)
	}

	func testStep_pickFavorites_iPhoneSE() {
		let view = OnboardingView(
			viewModel: OnboardingViewModelMock(currentStep: .pickFavorites)
		)
		assertOnboardingSnapshot(view, size: Self.iPhoneSESize)
	}

	// Welcome trial banner states (task 64 Scope 5). Fixed expiry date keeps the success banner stable.
	private static let fixedTrialExpiry = Date(timeIntervalSince1970: 1_800_000_000)

	func testStep_pickFavorites_welcomeTrialActive_dark() {
		let view = OnboardingView(
			viewModel: OnboardingViewModelMock(
				currentStep: .pickFavorites,
				selectedFavorites: ["❤️", "🔥", "🎉", "😄", "👍", "🙏", "✨", "🎯"],
				favoritesLimit: .max,
				canShowWelcomeOffer: false,
				welcomeTrialActiveUntil: Self.fixedTrialExpiry
			)
		)
		assertOnboardingSnapshot(view)
	}

	func testStep_pickFavorites_welcomeUnavailable_dark() {
		// Paid (or consumed+expired): no offer, no active trial → banner hidden.
		let view = OnboardingView(
			viewModel: OnboardingViewModelMock(
				currentStep: .pickFavorites,
				favoritesLimit: .max,
				canShowWelcomeOffer: false,
				welcomeTrialActiveUntil: nil
			)
		)
		assertOnboardingSnapshot(view)
	}

	func testStep4_featureTour_dark() {
		let view = OnboardingView(
			viewModel: OnboardingViewModelMock(currentStep: .featureTour)
		)
		assertOnboardingSnapshot(view)
	}

	func testStep4_featureTour_iPhoneSE() {
		let view = OnboardingView(
			viewModel: OnboardingViewModelMock(currentStep: .featureTour)
		)
		assertOnboardingSnapshot(view, size: Self.iPhoneSESize)
	}

	// MARK: - Helper

	private func assertOnboardingSnapshot<V: View>(
		_ view: V,
		size: CGSize = OnboardingSnapshots.size,
		record: Bool = false,
		file: StaticString = #filePath,
		testName: String = #function,
		line: UInt = #line
	) {
		let host = view.frame(width: size.width, height: size.height)
		assertSnapshot(
			of: host,
			as: .image(
				drawHierarchyInKeyWindow: true,
				perceptualPrecision: 0.93,
				layout: .fixed(width: size.width, height: size.height),
				traits: .init(userInterfaceStyle: .dark)
			),
			record: record,
			file: file,
			testName: testName + "_dark",
			line: line
		)
	}
}
