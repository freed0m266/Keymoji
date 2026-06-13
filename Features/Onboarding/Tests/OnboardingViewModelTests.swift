//
//  OnboardingViewModelTests.swift
//  Onboarding_Tests
//
//  Created by Martin Svoboda on 13.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import XCTest
import KeyboardCore
@testable import Onboarding

@MainActor
final class OnboardingViewModelTests: XCTestCase {

	// MARK: - Finish: selection vs. fallback

	func testFinish_emptySelection_persistsDefaultFavorites() {
		let spy = FavoritesPreferencesSpy(currentFavorites: [])
		let viewModel = makeViewModel(spy)

		viewModel.didFinishOnboarding()

		// Skip / Continue without picking → the curated 12, in order. Never empty, never random.
		XCTAssertEqual(spy.persistedFavorites, EmojiCatalog.defaultFavorites)
	}

	func testFinish_nonEmptySelection_persistsSelectedInTapOrder() {
		let spy = FavoritesPreferencesSpy(currentFavorites: [])
		let viewModel = makeViewModel(spy)

		viewModel.toggleFavorite("❤️")
		viewModel.toggleFavorite("🔥")
		viewModel.toggleFavorite("🎉")

		viewModel.didFinishOnboarding()

		XCTAssertEqual(spy.persistedFavorites, ["❤️", "🔥", "🎉"], "persisted set should be the picks in tap order")
	}

	func testFinish_alsoMarksOnboardingComplete() {
		let spy = FavoritesPreferencesSpy(currentFavorites: [])
		let viewModel = makeViewModel(spy)

		viewModel.didFinishOnboarding()

		// Both writes must happen on finish — order doesn't matter, but completion must be set.
		XCTAssertEqual(spy.markCompleteCount, 1)
		XCTAssertNotNil(spy.persistedFavorites)
	}

	func testFinish_featureTourOnlyEntry_doesNotTouchFavorites() {
		// The Settings "What Keymoji can do" shortcut re-enters at `.featureTour`, skipping the
		// picker. Closing it must not repopulate favorites the user may have intentionally cleared —
		// only mark onboarding complete.
		let spy = FavoritesPreferencesSpy(currentFavorites: [])
		let viewModel = OnboardingViewModel(
			dependencies: OnboardingDependencies(preferences: spy),
			initialStep: .featureTour
		)

		viewModel.didFinishOnboarding()

		XCTAssertNil(spy.persistedFavorites, "tour-only finish must not write favorites")
		XCTAssertEqual(spy.markCompleteCount, 1)
	}

	// MARK: - Toggle behaviour

	func testToggleFavorite_appendsThenRemoves_preservingOrder() {
		let spy = FavoritesPreferencesSpy(currentFavorites: [])
		let viewModel = makeViewModel(spy)

		viewModel.toggleFavorite("🚀")
		viewModel.toggleFavorite("🐶")
		viewModel.toggleFavorite("🎈")
		XCTAssertEqual(viewModel.selectedFavorites, ["🚀", "🐶", "🎈"], "new picks append in tap order")

		viewModel.toggleFavorite("🐶")
		XCTAssertEqual(viewModel.selectedFavorites, ["🚀", "🎈"], "re-toggling removes and keeps the rest in order")
	}

	// MARK: - Re-run pre-fill

	func testInit_preFillsSelectionFromStoredFavorites() {
		let spy = FavoritesPreferencesSpy(currentFavorites: ["🚀", "🐶"])
		let viewModel = makeViewModel(spy)

		// Returning user re-running onboarding sees their existing favorites pre-checked.
		XCTAssertEqual(viewModel.selectedFavorites, ["🚀", "🐶"])
	}

	// MARK: - Helpers

	private func makeViewModel(_ preferences: FavoritesPreferencesSpy) -> OnboardingViewModel {
		OnboardingViewModel(
			dependencies: OnboardingDependencies(preferences: preferences),
			initialStep: .pickFavorites
		)
	}
}

/// Records what the view model writes through `OnboardingPreferencesProviding` so tests can assert
/// the finish-time selection/fallback decision and the completion write. `NSLock`-guarded so it
/// satisfies the protocol's `Sendable` requirement without `nonisolated(unsafe)`.
private final class FavoritesPreferencesSpy: OnboardingPreferencesProviding, @unchecked Sendable {
	let isOnboardingComplete = false
	let currentFavorites: [String]

	private let lock = NSLock()
	private var _persistedFavorites: [String]?
	private var _markCompleteCount = 0

	init(currentFavorites: [String]) {
		self.currentFavorites = currentFavorites
	}

	var persistedFavorites: [String]? { lock.withLock { _persistedFavorites } }
	var markCompleteCount: Int { lock.withLock { _markCompleteCount } }

	func markOnboardingComplete() {
		lock.withLock { _markCompleteCount += 1 }
	}

	func persistOnboardingFavorites(_ favorites: [String]) {
		lock.withLock { _persistedFavorites = favorites }
	}
}
