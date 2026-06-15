//
//  PaywallView.swift
//  Paywall
//
//  Created by Martin Svoboda on 15.06.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import KeymojiCore
import KeymojiResources
import KeymojiUI

/// The single Keymoji Plus paywall, presented as a sheet from the favorites limit, the locked
/// frequency sort, or the Settings row. One SKU, one price — only the headline changes by context.
/// Copy leans Reciprocity-first (generous, honest, no subscription, no tracking) to convert a user
/// who already loves the free keyboard without any resentment.
public struct PaywallView<ViewModel: PaywallViewModeling>: View {
	@State private var viewModel: ViewModel
	private let onFinish: () -> Void

	typealias Texts = L10n.Paywall

	private var headline: String {
		switch viewModel.context {
		case .favoritesLimit:
			Texts.headlineLimit(FavoritesEntitlement.freeFavoritesLimit)
		case .frequencySort:
			Texts.headlineFrequency
		case .settings:
			Texts.headlineSettings
		}
	}

	public init(viewModel: ViewModel, onFinish: @escaping () -> Void = {}) {
		_viewModel = State(wrappedValue: viewModel)
		self.onFinish = onFinish
	}

	public var body: some View {
		Group {
			if viewModel.didUnlock {
				successState
			} else {
				offer
			}
		}
		.mainBackground()
		.task {
			await viewModel.onAppear()
		}
		.onChange(of: viewModel.isPlus) { _, isPlus in
			// Entitlement flipped from outside this paywall — an Ask-to-Buy approval, Family Sharing,
			// or a purchase on another device. Close silently; the paywall is never meant to linger for
			// someone who already has Plus. Our own buy/restore drives `didUnlock` and shows the success
			// state instead, so that path is excluded here.
			if isPlus, !viewModel.didUnlock { onFinish() }
		}
	}

	// MARK: - Offer

	private var offer: some View {
		VStack(spacing: 16) {
			ScrollView {
				VStack(spacing: 32) {
					header
					benefits
					reassurance
				}
			}
			.scrollIndicators(.hidden)

			actions
		}
		.padding(.top, 48)
		.padding(.bottom, 16)
		.padding(.horizontal, 32)
	}

	private var header: some View {
		VStack(spacing: 16) {
			Text("✨")
				.font(.system(size: 52))
				.frame(width: 96, height: 96)
				.glassEffect()

			Text(headline)
				.font(.title2.weight(.bold))
				.multilineTextAlignment(.center)

			Text(Texts.subtitle)
				.font(.callout)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
		}
	}

	private var benefits: some View {
		VStack(alignment: .leading, spacing: 14) {
			benefitRow(.starFill, Texts.benefitUnlimited)
			benefitRow(.squareStack, Texts.benefitPages)
			benefitRow(.chartBarFill, Texts.benefitAutoSort)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private func benefitRow(_ icon: Icon, _ text: String) -> some View {
		HStack(alignment: .center, spacing: 14) {
			icon
				.font(.system(size: 20, weight: .semibold))
				.foregroundStyle(.tint)
				.frame(width: 28)
			Text(text)
				.font(.body)
				.fixedSize(horizontal: false, vertical: true)
			Spacer(minLength: 0)
		}
	}

	private var reassurance: some View {
		VStack(spacing: 8) {
			Text(Texts.noSubscription)
				.font(.footnote.weight(.medium))
				.foregroundStyle(.secondary)
			Text(Texts.indie)
				.font(.footnote)
				.foregroundStyle(.tertiary)
		}
		.multilineTextAlignment(.center)
		.padding(.top, 4)
	}

	// MARK: - Actions

	private var actions: some View {
		VStack(spacing: 24) {
			if let message = viewModel.purchaseError {
				Text(message)
					.font(.footnote)
					.foregroundStyle(.red)
					.multilineTextAlignment(.center)
					.transition(.opacity)
			}

			purchaseControl
			footerLinks
		}
	}

	/// The price CTA once the product loads; a spinner while it's loading; a graceful retry if the App
	/// Store couldn't return the product (offline, sandbox hiccup, product not yet live) — never a dead
	/// perpetual spinner.
	@ViewBuilder
	private var purchaseControl: some View {
		if viewModel.isProductLoaded {
			PrimaryButton(Texts.cta(viewModel.displayPrice ?? ""), isLoading: viewModel.isWorking) {
				Task { await viewModel.purchase() }
			}
		} else if viewModel.isLoadingProducts {
			ProgressView()
				.controlSize(.large)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 8)
		} else {
			VStack(spacing: 12) {
				Text(Texts.productsUnavailable)
					.font(.callout)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
				SecondaryButton(Texts.retry) {
					Task { await viewModel.onAppear() }
				}
			}
		}
	}

	private var footerLinks: some View {
		VStack(spacing: 16) {
			Button(Texts.restore) {
				Task { await viewModel.restore() }
			}
			.font(.callout)
			.tint(.accentColor)
			.disabled(viewModel.isWorking)

			if let url = URL(string: KeymojiURLs.privacyPolicy) {
				Link(Texts.privacyPolicy, destination: url)
					.font(.footnote)
					.tint(.secondary)
			}
		}
	}

	// MARK: - Success

	private var successState: some View {
		VStack(spacing: 20) {
			Spacer()
			Text("🎉")
				.font(.system(size: 72))
			Text(Texts.successTitle)
				.font(.title.weight(.bold))
				.multilineTextAlignment(.center)
			Text(Texts.successBody)
				.font(.callout)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
			Spacer()
			PrimaryButton(Texts.successCta, action: onFinish)
				.padding(.bottom, 32)
		}
		.padding(.horizontal, 32)
	}
}

#if DEBUG
#Preview("Limit · purchasable") {
	PaywallView(viewModel: PaywallViewModelMock(context: .favoritesLimit))
		.preferredColorScheme(.dark)
}

#Preview("Loading price") {
	PaywallView(viewModel: PaywallViewModelMock(context: .settings, isProductLoaded: false, isLoadingProducts: true))
		.preferredColorScheme(.dark)
}

#Preview("Products unavailable") {
	PaywallView(viewModel: PaywallViewModelMock(context: .settings, isProductLoaded: false, isLoadingProducts: false))
		.preferredColorScheme(.dark)
}

#Preview("Unlocked") {
	PaywallView(viewModel: PaywallViewModelMock(context: .favoritesLimit, didUnlock: true))
		.preferredColorScheme(.dark)
}
#endif
