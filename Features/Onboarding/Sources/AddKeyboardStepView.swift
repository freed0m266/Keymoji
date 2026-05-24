//
//  AddKeyboardStepView.swift
//  Onboarding
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import KeyboResources

struct AddKeyboardStepView<ViewModel: OnboardingViewModeling>: View {
	@Bindable var viewModel: ViewModel

	typealias Texts = L10n.Onboarding

	var body: some View {
		VStack(spacing: 24) {
			Image(systemName: "keyboard.badge.eye")
				.resizable()
				.scaledToFit()
				.frame(width: 90, height: 90)
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

			Button(action: viewModel.openSettings) {
				Text(Texts.Step1.cta)
					.font(.headline)
					.frame(maxWidth: .infinity, minHeight: 48)
			}
			.buttonStyle(.borderedProminent)
			.padding(.horizontal, 24)
		}
		.padding(.top, 64)
		.padding(.bottom, 56)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}
