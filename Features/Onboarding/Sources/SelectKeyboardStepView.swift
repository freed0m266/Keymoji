//
//  SelectKeyboardStepView.swift
//  Onboarding
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import KeyboResources

struct SelectKeyboardStepView<ViewModel: OnboardingViewModeling>: View {
	@Bindable var viewModel: ViewModel
	let onFinish: () -> Void

	typealias Texts = L10n.Onboarding

	var body: some View {
		VStack(spacing: 24) {
			Image(systemName: "globe")
				.resizable()
				.scaledToFit()
				.frame(width: 90, height: 90)
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

			Button {
				viewModel.didFinishOnboarding()
				onFinish()
			} label: {
				Text(Texts.Step3.done)
					.font(.headline)
					.frame(maxWidth: .infinity, minHeight: 48)
			}
			.buttonStyle(.borderedProminent)
			.padding(.horizontal, 24)

			Text(Texts.Step3.footer)
				.font(.footnote)
				.foregroundStyle(.tertiary)
				.multilineTextAlignment(.center)
				.padding(.horizontal, 32)
				.padding(.top, 8)
		}
		.padding(.top, 64)
		.padding(.bottom, 56)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}
