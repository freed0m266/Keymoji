//
//  AboutView.swift
//  About
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import KeymojiCore
import KeymojiResources

public struct AboutView<ViewModel: AboutViewModeling>: View {
	@State private var viewModel: ViewModel

	typealias Texts = L10n.About

	public init(viewModel: ViewModel) {
		_viewModel = State(wrappedValue: viewModel)
	}

	public var body: some View {
		Form {
			headerSection
			privacySection
			legalSection
		}
		.navigationTitle(Texts.title)
		.navigationBarTitleDisplayMode(.inline)
	}

	private var headerSection: some View {
		Section {
			VStack(spacing: 12) {
				Image(systemName: "keyboard")
					.resizable()
					.scaledToFit()
					.frame(width: 64, height: 64)
					.foregroundStyle(.tint)
				Text(L10n.General.title)
					.font(.title2.weight(.bold))
				Text(Texts.versionLabel(viewModel.versionString))
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity)
			.padding(.vertical, 12)
			.listRowBackground(Color.clear)
		}
	}

	private var privacySection: some View {
		Section {
			Text(Texts.Privacy.statement)
				.font(.callout)
				.foregroundStyle(.secondary)
		} header: {
			Text(Texts.Privacy.header)
		}
	}

	private var legalSection: some View {
		Section {
			Button(action: viewModel.openPrivacyPolicy) {
				LabeledChevronRow(title: Texts.Legal.privacyPolicyLink)
			}
			Button(action: viewModel.openSourceCode) {
				LabeledChevronRow(title: Texts.Legal.sourceCodeLink)
			}
		} header: {
			Text(Texts.Legal.header)
		} footer: {
			Text(Texts.Legal.copyright(currentYear))
		}
	}

	private var currentYear: String {
		String(Calendar.current.component(.year, from: Date()))
	}
}

/// Lightweight row used by AboutView for external link items. Lives here for v1.0; if a similar
/// pattern shows up elsewhere we can hoist it into `KeymojiUI`.
private struct LabeledChevronRow: View {
	let title: String

	var body: some View {
		HStack {
			Text(title)
				.foregroundStyle(.primary)
			Spacer()
			Image(systemName: "chevron.right")
				.font(.footnote.weight(.semibold))
				.foregroundStyle(.tertiary)
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
