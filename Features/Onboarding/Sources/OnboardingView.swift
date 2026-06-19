//
//  OnboardingView.swift
//  Onboarding
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import KeymojiCore
import KeyboardCore
import KeymojiResources
import KeymojiUI
import EmojiCatalogPicker

public struct OnboardingView<ViewModel: OnboardingViewModeling>: View {
	@State private var viewModel: ViewModel
	@State private var showBrowseAll = false
	private let onFinish: () -> Void

	typealias Texts = L10n.Onboarding
	typealias WelcomeTexts = L10n.Welcome.Onboarding

	public init(viewModel: ViewModel, onFinish: @escaping () -> Void = {}) {
		_viewModel = State(wrappedValue: viewModel)
		self.onFinish = onFinish
	}

	public var body: some View {
		VStack(spacing: 32) {
			TabView(selection: $viewModel.currentStep) {
				addKeyboardStep
					.tag(OnboardingStep.addKeyboard)

				allowFullAccessStep
					.tag(OnboardingStep.allowFullAccess)

				selectKeyboardStep
					.tag(OnboardingStep.selectKeyboard)

				pickFavoritesStep
					.tag(OnboardingStep.pickFavorites)

				featureTourStep
					.tag(OnboardingStep.featureTour)
			}
			.tabViewStyle(.page(indexDisplayMode: .never))
			.animation(.default, value: viewModel.currentStep)

			indexIndicator
				.padding(.bottom, 16)
		}
		.ignoresSafeArea(edges: .top)
		.onForeground {
			viewModel.refreshKeyboardStatus()
		}
	}

	private var addKeyboardStep: some View {
		VStack(spacing: 24) {
			Icon.keyboardBadgeEye
				.size(90)
				.foregroundStyle(.tint)

			Text(Texts.Step1.title)
				.font(.title2.weight(.bold))
				.multilineTextAlignment(.center)

			Text(Texts.Step1.description)
				.font(.callout)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.padding(.horizontal, 24)

			if viewModel.isKeyboardActivated {
				Label(Texts.Step1.detected, systemImage: "checkmark.circle.fill")
					.font(.callout.weight(.semibold))
					.foregroundStyle(.green)
					.padding(.top, 8)
			}

			Spacer()

			PrimaryButton(Texts.Step1.cta, action: viewModel.openSettings)
				.padding(.horizontal, 32)
		}
		.padding(.top, 64)
	}

	private var allowFullAccessStep: some View {
		VStack(spacing: 24) {
			Icon.lockShield
				.size(90)
				.foregroundStyle(.tint)

			Text(Texts.Step2.title)
				.font(.title2.weight(.bold))
				.multilineTextAlignment(.center)

			Text(Texts.Step2.description)
				.font(.callout)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.padding(.horizontal, 24)

			Text(Texts.Step2.privacy)
				.font(.footnote)
				.foregroundStyle(.tertiary)
				.multilineTextAlignment(.center)
				.padding(.horizontal, 32)
				.padding(.top, 8)

			Spacer()

			VStack(spacing: 24) {
				PrimaryButton(Texts.Step2.cta, action: viewModel.openSettings)

				SecondaryButton(Texts.Step2.confirm, action: viewModel.didConfirmFullAccess)
			}
			.padding(.horizontal, 32)
		}
		.padding(.top, 64)
	}

	private var selectKeyboardStep: some View {
		VStack(spacing: 24) {
			Icon.globe
				.size(90)
				.foregroundStyle(.tint)

			Text(Texts.Step3.title)
				.font(.title2.weight(.bold))
				.multilineTextAlignment(.center)

			Text(Texts.Step3.description)
				.font(.callout)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.padding(.horizontal, 24)

			Spacer()

			PrimaryButton(Texts.Step3.done) {
				viewModel.currentStep = .pickFavorites
			}
			.padding(.horizontal, 32)

			Text(Texts.Step3.footer)
				.font(.footnote)
				.foregroundStyle(.tertiary)
				.multilineTextAlignment(.center)
				.padding(.horizontal, 32)
				.padding(.bottom, 8)
		}
		.padding(.top, 64)
	}

	private var pickFavoritesStep: some View {
		// Denser than the other steps (grid + two buttons + footer). The Spacer pins the buttons to
		// the bottom and centres the block on tall screens; `minHeight` + ScrollView let the content
		// scroll instead of clipping when it can't fit (e.g. iPhone SE), so nothing is ever cut off.
		GeometryReader { proxy in
			ScrollView {
				VStack(spacing: 20) {
					Text("⭐️")
						.font(.system(size: 48))
						.frame(width: 94, height: 94)
						.glassEffect()

					Text(Texts.Favorites.title)
						.font(.title2.weight(.bold))
						.multilineTextAlignment(.center)

					Text(Texts.Favorites.description)
						.font(.callout)
						.foregroundStyle(.secondary)
						.multilineTextAlignment(.center)
						.padding(.horizontal, 24)

					welcomeBanner

					LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
						ForEach(EmojiCatalog.defaultFavorites, id: \.self) { glyph in
							favoriteCell(glyph, isSelected: viewModel.selectedFavorites.contains(glyph))
						}
					}
					.padding(.horizontal, 24)

					Button(Texts.Favorites.browseAll) { showBrowseAll = true }
						.font(.subheadline.weight(.medium))
						.tint(.accentColor)

					Spacer(minLength: 24)

					VStack(spacing: 12) {
						PrimaryButton(Texts.Favorites.cta) {
							viewModel.currentStep = .featureTour
						}

						SecondaryButton(Texts.Favorites.skip) {
							viewModel.currentStep = .featureTour
						}

						Text(Texts.Favorites.footer)
							.font(.footnote)
							.foregroundStyle(.tertiary)
							.multilineTextAlignment(.center)
					}
					.padding(.horizontal, 32)
				}
				.padding(.top, 56)
				.padding(.bottom, 16)
				.frame(minHeight: proxy.size.height, alignment: .top)
			}
			.scrollIndicators(.hidden)
		}
		.sheet(isPresented: $showBrowseAll) {
			NavigationStack {
				EmojiCatalogPickerView(
					selectedEmojis: Set(viewModel.selectedFavorites),
					onToggle: { viewModel.toggleFavorite($0) },
					onDone: { showBrowseAll = false },
					// Same cap as the inline grid — dims past the limit (6 free, ∞ after Welcome/paid).
					selectionLimit: viewModel.favoritesLimit
				)
				.mainBackground()
			}
		}
	}

	/// The opt-in Welcome gift, shown above the grid in the pick-favorites step (task 64 Scope 5).
	/// Hidden for paid users and once a consumed trial has lapsed; a button while available, then a
	/// read-only success card while a trial (Welcome or cheat code) is running.
	@ViewBuilder
	private var welcomeBanner: some View {
		if let until = viewModel.welcomeTrialActiveUntil {
			bannerCard(filled: true) {
				Text(WelcomeTexts.activeUntil(until.formatted(date: .abbreviated, time: .omitted)))
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(.primary)
			}
			.padding(.horizontal, 24)
		} else if viewModel.canShowWelcomeOffer {
			Button {
				// Animate so the grid un-dims and the banner morphs to its success state in place.
				withAnimation { viewModel.activateWelcomeTrial() }
			} label: {
				bannerCard(filled: false) {
					Text(WelcomeTexts.cta)
						.font(.subheadline.weight(.semibold))
						.foregroundStyle(.primary)
						.multilineTextAlignment(.leading)
				}
			}
			.buttonStyle(.plain)
			.padding(.horizontal, 24)
		}
	}

	private func bannerCard<Content: View>(filled: Bool, @ViewBuilder content: () -> Content) -> some View {
		HStack(spacing: 10) {
			Text("🎁").font(.title3)
			content()
			Spacer(minLength: 0)
		}
		.padding(14)
		.frame(maxWidth: .infinity)
		.background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor.opacity(filled ? 0.15 : 0.18)))
		.overlay(
			RoundedRectangle(cornerRadius: 14)
				.strokeBorder(Color.accentColor.opacity(filled ? 0 : 0.5), lineWidth: 1)
		)
		.contentShape(.rect)
	}

	private func favoriteCell(_ glyph: String, isSelected: Bool) -> some View {
		// Free users cap out at the free favorites limit — dim the remaining cells (no mid-onboarding
		// upsell) so a tap that wouldn't register reads as "full", not broken.
		let isDimmed = !isSelected && !viewModel.canSelectMoreFavorites
		return Button {
			viewModel.toggleFavorite(glyph)
		} label: {
			ZStack(alignment: .topTrailing) {
				Text(glyph)
					.font(.system(size: 30))
					.frame(maxWidth: .infinity)
					.frame(height: 52)
					.background(
						RoundedRectangle(cornerRadius: 8)
							.fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
					)

				if isSelected {
					Icon.checkmarkCircleFill
						.font(.system(size: 14))
						.foregroundStyle(Color.accentColor, Color(.systemBackground))
						.padding(2)
				}
			}
			.contentShape(.rect)
			.opacity(isDimmed ? 0.35 : 1)
		}
		.buttonStyle(.plain)
		.disabled(isDimmed)
		.accessibilityLabel(glyph)
		.accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
	}

	private var featureTourStep: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 18) {
				ForEach(FeatureHighlight.all) { highlight in
					highlightRow(highlight)
				}
			}
			.padding(.horizontal, 24)
			.padding(.vertical, 8)
			.padding(.top, 56)
		}
		.scrollIndicators(.hidden)
		.mask(
			LinearGradient(
				colors: [ .black, .black, .black, .black, .clear ],
				startPoint: .top,
				endPoint: .bottom
			)
		)
		.overlay(alignment: .bottom) {
			VStack(spacing: 12) {
				PrimaryButton(Texts.Tour.cta) {
					viewModel.didFinishOnboarding()
					onFinish()
				}
				.padding(.horizontal, 32)

				Text(Texts.Tour.footer)
					.font(.footnote)
					.foregroundStyle(.tertiary)
					.multilineTextAlignment(.center)
					.padding(.horizontal, 32)
			}
		}
	}

	private var indexIndicator: some View {
		HStack(spacing: 8) {
			ForEach(OnboardingStep.allCases) { item in
				RoundedRectangle(cornerRadius: 4)
					.fill(.secondary)
					.animation(.default, value: viewModel.currentStep)
					.frame(width: viewModel.currentStep == item ? 24 : 8, height: 8)
			}
		}
		.padding(8)
		.background(Color.gray.opacity(0.2))
		.cornerRadius(12)
	}

	private func highlightRow(_ highlight: FeatureHighlight) -> some View {
		HStack(alignment: .top, spacing: 14) {
			Image(systemName: highlight.symbol)
				.font(.system(size: 24, weight: .regular))
				.foregroundStyle(.tint)
				.frame(width: 32, alignment: .center)

			VStack(alignment: .leading, spacing: 2) {
				Text(highlight.title)
					.font(.subheadline.weight(.semibold))
				Text(highlight.description)
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}

#if DEBUG
#Preview("Step 1 — Add keyboard") {
	OnboardingView(viewModel: OnboardingViewModelMock(currentStep: .addKeyboard))
}

#Preview("Step 1 — Detected") {
	OnboardingView(viewModel: OnboardingViewModelMock(currentStep: .addKeyboard, isKeyboardActivated: true))
}

#Preview("Step 2 — Full Access") {
	OnboardingView(viewModel: OnboardingViewModelMock(currentStep: .allowFullAccess))
}

#Preview("Step 3 — Select keyboard") {
	OnboardingView(viewModel: OnboardingViewModelMock(currentStep: .selectKeyboard))
}

#Preview("Step 4 — Pick favorites") {
	OnboardingView(viewModel: OnboardingViewModelMock(currentStep: .pickFavorites))
}

#Preview("Step 4 — Pick favorites (some selected)") {
	OnboardingView(
		viewModel: OnboardingViewModelMock(
			currentStep: .pickFavorites,
			selectedFavorites: ["❤️", "🔥", "🎉"]
		)
	)
}

#Preview("Step 5 — Feature tour") {
	OnboardingView(viewModel: OnboardingViewModelMock(currentStep: .featureTour))
}
#endif
