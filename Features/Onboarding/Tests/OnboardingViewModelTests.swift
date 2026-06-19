//
//  OnboardingViewModelTests.swift
//  Onboarding_Tests
//
//  Created by Martin Svoboda on 13.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import XCTest
import KeyboardCore
import KeymojiCore
@testable import Onboarding

@MainActor
final class OnboardingViewModelTests: XCTestCase {

	// MARK: - Finish: selection vs. fallback

	func testFinish_emptySelection_freeUser_persistsCappedDefaultFavorites() {
		let spy = FavoritesPreferencesSpy(currentFavorites: [])   // free by default
		let viewModel = makeViewModel(spy)

		viewModel.didFinishOnboarding()

		// Skip / Continue without picking → the curated fallback, capped to the free limit (never the
		// full 12, which the keyboard would clamp), in order. Never empty, never random.
		XCTAssertEqual(
			spy.persistedFavorites,
			Array(EmojiCatalog.defaultFavorites.prefix(FavoritesEntitlement.freeFavoritesLimit))
		)
	}

	func testFinish_emptySelection_plusUser_persistsAllDefaultFavorites() {
		let spy = FavoritesPreferencesSpy(currentFavorites: [], isPlus: true)
		let viewModel = makeViewModel(spy)

		viewModel.didFinishOnboarding()

		XCTAssertEqual(spy.persistedFavorites, EmojiCatalog.defaultFavorites)
	}

	// MARK: - Free favorites cap

	func testToggleFavorite_freeUser_stopsAtLimit() {
		let spy = FavoritesPreferencesSpy(currentFavorites: [])
		let viewModel = makeViewModel(spy)

		let glyphs = ["❤️", "😂", "👍", "🙏", "😍", "🔥", "🎉", "🥰"]
		glyphs.forEach { viewModel.toggleFavorite($0) }

		XCTAssertEqual(viewModel.selectedFavorites.count, FavoritesEntitlement.freeFavoritesLimit)
		XCTAssertFalse(viewModel.canSelectMoreFavorites)
		XCTAssertEqual(viewModel.selectedFavorites, Array(glyphs.prefix(FavoritesEntitlement.freeFavoritesLimit)))
	}

	func testToggleFavorite_plusUser_hasNoCap() {
		let spy = FavoritesPreferencesSpy(currentFavorites: [], isPlus: true)
		let viewModel = makeViewModel(spy)

		let glyphs = ["❤️", "😂", "👍", "🙏", "😍", "🔥", "🎉", "🥰"]
		glyphs.forEach { viewModel.toggleFavorite($0) }

		XCTAssertEqual(viewModel.selectedFavorites, glyphs)
		XCTAssertTrue(viewModel.canSelectMoreFavorites)
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

	// MARK: - Welcome trial

	func testActivateWelcomeTrial_relaxesCap_andShowsActiveBanner() {
		let spy = FavoritesPreferencesSpy(currentFavorites: [], canShowWelcomeOffer: true)
		let viewModel = makeViewModel(spy)

		// Before: free user, offer visible, capped.
		XCTAssertTrue(viewModel.canShowWelcomeOffer)
		XCTAssertNil(viewModel.welcomeTrialActiveUntil)
		XCTAssertEqual(viewModel.favoritesLimit, FavoritesEntitlement.freeFavoritesLimit)

		viewModel.activateWelcomeTrial()

		// After: gift consumed → success banner, cap relaxed so the grid un-dims in place.
		XCTAssertEqual(spy.activateWelcomeCount, 1)
		XCTAssertFalse(viewModel.canShowWelcomeOffer)
		XCTAssertNotNil(viewModel.welcomeTrialActiveUntil)
		XCTAssertEqual(viewModel.favoritesLimit, .max)
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
	private var _paid: Bool
	private var _canShowWelcomeOffer: Bool
	private var _welcomeTrialActiveUntil: Date?
	private var _activateWelcomeCount = 0

	init(
		currentFavorites: [String],
		isPlus: Bool = false,
		canShowWelcomeOffer: Bool = false,
		welcomeTrialActiveUntil: Date? = nil
	) {
		self.currentFavorites = currentFavorites
		self._paid = isPlus
		self._canShowWelcomeOffer = canShowWelcomeOffer
		self._welcomeTrialActiveUntil = welcomeTrialActiveUntil
	}

	var persistedFavorites: [String]? { lock.withLock { _persistedFavorites } }
	var markCompleteCount: Int { lock.withLock { _markCompleteCount } }
	var activateWelcomeCount: Int { lock.withLock { _activateWelcomeCount } }

	/// *Effective* Plus, mirroring the real provider: paid OR an active trial. Lets the activation test
	/// observe the cap relaxing after `activateWelcomeTrial()` sets a future expiry.
	var isPlus: Bool {
		lock.withLock { _paid || (_welcomeTrialActiveUntil.map { Date() < $0 } ?? false) }
	}

	var canShowWelcomeOffer: Bool { lock.withLock { _canShowWelcomeOffer } }
	var welcomeTrialActiveUntil: Date? { lock.withLock { _welcomeTrialActiveUntil } }

	func markOnboardingComplete() {
		lock.withLock { _markCompleteCount += 1 }
	}

	func persistOnboardingFavorites(_ favorites: [String]) {
		lock.withLock { _persistedFavorites = favorites }
	}

	func activateWelcomeTrial() {
		lock.withLock {
			_activateWelcomeCount += 1
			_welcomeTrialActiveUntil = Date(timeIntervalSinceNow: 30 * 24 * 60 * 60)
			_canShowWelcomeOffer = false
		}
	}
}
