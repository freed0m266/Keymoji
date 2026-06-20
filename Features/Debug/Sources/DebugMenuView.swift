//
//  DebugMenuView.swift
//  Debug
//
//  Created by Martin Svoboda on 19.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

#if DEBUG
import SwiftUI

/// DEBUG-only developer menu to simulate fresh / free-user states for QA of the promo-trial surfaces
/// (task 67). Strings are hardcoded English on purpose — it never ships, so it isn't localized. No
/// generic `ViewModeling` protocol either: the concrete `DebugMenuViewModel` is the whole contract.
public struct DebugMenuView: View {
	@State private var viewModel: DebugMenuViewModel

	public init(viewModel: DebugMenuViewModel) {
		_viewModel = State(wrappedValue: viewModel)
	}

	public var body: some View {
		Form {
			readoutSection
			overrideSection
			resetSection
			expireSection
		}
		.navigationTitle("🛠 Debug")
		.navigationBarTitleDisplayMode(.inline)
	}

	// MARK: - Live readout

	private var readoutSection: some View {
		Section {
			row("Effective Plus", bool: viewModel.effectivePlus)
			row("Paid mirror (isPlus)", bool: viewModel.paidMirror)
			row("Force free tier", bool: viewModel.forceFreeTier)
			row("Onboarding complete", bool: viewModel.onboardingComplete)
			row("Welcome consumed", bool: viewModel.welcomeConsumed)
			row("Promo expiry", value: expiryText)
		} header: {
			Text("Current state")
		} footer: {
			Text("“Paid mirror” reflects the force-free mask while it’s on, not the real StoreKit purchase.")
		}
	}

	// MARK: - Override (Plus)

	private var overrideSection: some View {
		Section {
			Toggle("Simulate free user", isOn: Binding(
				get: { viewModel.forceFreeTier },
				set: { _ in viewModel.toggleForceFreeTier() }
			))
		} header: {
			Text("Plus override")
		} footer: {
			Text(
				"Masks a real (paid) Plus entitlement down to free, live across the app and keyboard. "
				+ "Your real purchase is untouched — turn off to restore it."
			)
		}
	}

	// MARK: - Reset (replay flows)

	private var resetSection: some View {
		Section {
			Button("Reset onboarding") { viewModel.resetOnboarding() }
			Button("Reset gift (Welcome)", role: .destructive) { viewModel.resetGift() }
		} header: {
			Text("Reset flows")
		} footer: {
			Text(
				"Reset onboarding takes effect after the next app launch. Resetting the gift clears the "
				+ "Plus-trial clock. Favorites and learned words are never touched."
			)
		}
	}

	// MARK: - Expire trial

	private var expireSection: some View {
		Section {
			Button("Expire trial now", role: .destructive) { viewModel.expireTrialNow() }
		} footer: {
			Text(
				"Marks Welcome consumed and pushes the expiry into the past to reach the “trial ended” surfaces "
				+ "(Settings S4, loss-aversion banner, after-trial paywall). "
				+ "Combine with “Simulate free user” on and 7+ favorites."
			)
		}
	}

	// MARK: - Helpers

	private var expiryText: String {
		guard let expiry = viewModel.promoExpiresAt else { return "—" }
		return expiry.formatted(date: .abbreviated, time: .shortened)
	}

	private func row(_ title: String, bool value: Bool) -> some View {
		row(title, value: value ? "✅" : "❌")
	}

	private func row(_ title: String, value: String) -> some View {
		HStack {
			Text(title)
			Spacer()
			Text(value)
				.foregroundStyle(.secondary)
				.monospacedDigit()
		}
	}
}

#Preview {
	NavigationStack {
		DebugMenuView(viewModel: DebugMenuViewModel())
	}
}
#endif
