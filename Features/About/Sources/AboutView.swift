//
//  AboutView.swift
//  About
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import KeymojiCore
import KeymojiUI
import KeymojiResources

public struct AboutView<ViewModel: AboutViewModeling>: View {
	@State private var viewModel: ViewModel

	typealias Texts = L10n.About

	private var currentYear: String {
		String(Calendar.current.component(.year, from: .now))
	}

	public init(viewModel: ViewModel) {
		_viewModel = State(wrappedValue: viewModel)
	}

	public var body: some View {
		Form {
			headerSection
			privacySection
			legalSection
		}
		.aboutBackground()
		.navigationTitle(Texts.title)
		.navigationBarTitleDisplayMode(.inline)
	}

	private var headerSection: some View {
		Section {
			VStack(spacing: 12) {
				Assets.keymojiLogo.swiftUIImage
					.resizable()
					.scaledToFit()
					.frame(width: 80, height: 80)
					.foregroundStyle(.tint)

				Text(L10n.General.title)
					.font(.title2.weight(.bold))

				Text(Texts.versionLabel(viewModel.versionString))
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity)
			.padding(.bottom, 12)
			.listRowBackground(Color.clear)
		}
	}

	private var privacySection: some View {
		Section {
			Text(Texts.privacyStatement)
				.font(.callout)
				.foregroundStyle(.secondary)
		} header: {
			Text(Texts.privacyHeader)
		}
	}

	private var legalSection: some View {
		Section {
			chevronRow(title: Texts.privacyPolicyLink) {
				viewModel.openPrivacyPolicy()
			}
			chevronRow(title: Texts.support) {
				viewModel.openSupportEmail()
			}
		} header: {
			Text(Texts.legalHeader)
		} footer: {
			Text(Texts.copyright(currentYear))
		}
	}

	@ViewBuilder
	private func chevronRow(title: String, action: @escaping () -> Void) -> some View {
		Button(action: action) {
			HStack {
				Text(title)
					.foregroundStyle(.primary)
				
				Spacer()
				
				Icon.chevronRight
					.font(.footnote.weight(.semibold))
					.foregroundStyle(.tertiary)
			}
		}
	}
}

#if DEBUG
#Preview {
	NavigationStack {
		AboutView(viewModel: AboutViewModelMock())
	}
	.preferredColorScheme(.dark)
}
#endif
