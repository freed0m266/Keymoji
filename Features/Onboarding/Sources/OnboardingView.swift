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

	@MainActor
	public init(
		viewModel: ViewModel,
		initialStep: OnboardingStep? = nil,
		onFinish: @escaping () -> Void = {}
	) {
		if let initialStep {
			viewModel.currentStep = initialStep
		}
		_viewModel = State(wrappedValue: viewModel)
		self.onFinish = onFinish
	}

	public var body: some View {
		ZStack {
			Color.black.ignoresSafeArea()

			TabView(selection: Binding(
				get: { viewModel.currentStep },
				set: { viewModel.currentStep = $0 }
			)) {
				AddKeyboardStepView(viewModel: viewModel)
					.tag(OnboardingStep.addKeyboard)
				AllowFullAccessStepView(viewModel: viewModel)
					.tag(OnboardingStep.allowFullAccess)
				SelectKeyboardStepView(viewModel: viewModel)
					.tag(OnboardingStep.selectKeyboard)
				FeatureTourStepView(viewModel: viewModel, onFinish: onFinish)
					.tag(OnboardingStep.featureTour)
			}
			.tabViewStyle(.page(indexDisplayMode: .always))
			.indexViewStyle(.page(backgroundDisplayMode: .always))
		}
		.preferredColorScheme(.dark)
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
