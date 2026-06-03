//
//  FeatureTourStepView.swift
//  Onboarding
//
//  Created by Martin Svoboda on 28.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import KeymojiResources

struct FeatureTourStepView<ViewModel: OnboardingViewModeling>: View {
	@Bindable var viewModel: ViewModel
	let onFinish: () -> Void

	typealias Texts = L10n.Onboarding.Tour

	var body: some View {
		VStack(spacing: 0) {
			VStack(spacing: 8) {
				Text(Texts.title)
					.font(.title2.weight(.bold))
					.multilineTextAlignment(.center)

				Text(Texts.subtitle)
					.font(.callout)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
			}
			.padding(.horizontal, 24)
			.padding(.bottom, 16)

			ScrollView {
				VStack(alignment: .leading, spacing: 18) {
					ForEach(FeatureHighlight.all) { highlight in
						highlightRow(highlight)
					}
				}
				.padding(.horizontal, 24)
				.padding(.vertical, 8)
			}
			.scrollIndicators(.hidden)

			Button {
				viewModel.didFinishOnboarding()
				onFinish()
			} label: {
				Text(Texts.cta)
					.font(.headline)
					.frame(maxWidth: .infinity, minHeight: 48)
			}
			.buttonStyle(.borderedProminent)
			.padding(.horizontal, 24)
			.padding(.top, 8)

			Text(Texts.footer)
				.font(.footnote)
				.foregroundStyle(.tertiary)
				.multilineTextAlignment(.center)
				.padding(.horizontal, 32)
				.padding(.top, 8)
		}
		.padding(.top, 56)
		.padding(.bottom, 56)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
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
