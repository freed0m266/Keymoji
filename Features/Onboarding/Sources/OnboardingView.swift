//
//  OnboardingView.swift
//  Onboarding
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import KeyboCore
import KeyboResources
import KeyboUI

public struct OnboardingView<ViewModel: OnboardingViewModeling>: View {
	@State private var viewModel: ViewModel
	private let onFinish: () -> Void

	typealias Texts = L10n.Onboarding

	public init(viewModel: ViewModel, onFinish: @escaping () -> Void = {}) {
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
				SelectKeyboardStepView(viewModel: viewModel, onFinish: onFinish)
					.tag(OnboardingStep.selectKeyboard)
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
#endif
