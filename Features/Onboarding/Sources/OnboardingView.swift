//
//  OnboardingView.swift
//  Onboarding
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import KeymojiCore
import KeymojiResources
import KeymojiUI

public struct OnboardingView<ViewModel: OnboardingViewModeling>: View {
	@State private var viewModel: ViewModel
	private let onFinish: () -> Void

	typealias Texts = L10n.Onboarding

	public init(
		viewModel: ViewModel,
		onFinish: @escaping () -> Void = {}
	) {
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
				
				featureTourStep
					.tag(OnboardingStep.featureTour)
			}
			.tabViewStyle(.page(indexDisplayMode: .never))
			.animation(.default, value: viewModel.currentStep)

			indexIndicator
				.padding(.bottom, 16)
		}
		.ignoresSafeArea(edges: .top)
		.mainBackground()
		.preferredColorScheme(.dark)
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
				viewModel.currentStep = .featureTour
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
			.background {
				LinearGradient(
					colors: [.black, .clear],
					startPoint: .bottom,
					endPoint: .top
				)
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

	@ViewBuilder
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

#Preview("Step 4 — Feature tour") {
	OnboardingView(viewModel: OnboardingViewModelMock(currentStep: .featureTour))
}
#endif
