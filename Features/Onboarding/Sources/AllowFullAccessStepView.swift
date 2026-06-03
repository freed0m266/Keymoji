//
//  AllowFullAccessStepView.swift
//  Onboarding
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import KeymojiResources

struct AllowFullAccessStepView<ViewModel: OnboardingViewModeling>: View {
	@Bindable var viewModel: ViewModel

	typealias Texts = L10n.Onboarding

	var body: some View {
		VStack(spacing: 24) {
			Image(systemName: "lock.shield")
				.resizable()
				.scaledToFit()
				.frame(width: 90, height: 90)
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

			VStack(spacing: 12) {
				Button(action: viewModel.openSettings) {
					Text(Texts.Step2.cta)
						.font(.headline)
						.frame(maxWidth: .infinity, minHeight: 48)
				}
				.buttonStyle(.borderedProminent)

				Button(action: viewModel.didConfirmFullAccess) {
					Text(Texts.Step2.confirm)
						.font(.subheadline.weight(.medium))
						.frame(maxWidth: .infinity, minHeight: 44)
				}
				.buttonStyle(.bordered)
			}
			.padding(.horizontal, 24)
		}
		.padding(.top, 64)
		.padding(.bottom, 56)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}
