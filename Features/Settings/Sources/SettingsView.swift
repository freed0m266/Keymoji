//
//  SettingsView.swift
//  Settings
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import About
import KeyboCore
import KeyboResources
import Onboarding

public struct SettingsView<ViewModel: SettingsViewModeling>: View {
	@Bindable private var viewModel: ViewModel
	@State private var sheet: SheetKind?

	typealias Texts = L10n.Settings

	public init(viewModel: ViewModel) {
		_viewModel = Bindable(wrappedValue: viewModel)
	}

	public var body: some View {
		NavigationStack {
			Form {
				keyboardSection
				supportSection
				aboutSection
			}
			.navigationTitle(Texts.title)
			.sheet(item: $sheet) { kind in
				NavigationStack {
					switch kind {
					case .onboarding: OnboardingView(viewModel: onboardingVM(), onFinish: { sheet = nil })
					case .about:      AboutView(viewModel: aboutVM())
					}
				}
				.preferredColorScheme(.dark)
			}
		}
	}

	private var keyboardSection: some View {
		Section {
			Toggle(Texts.Keyboard.showNumberRow, isOn: $viewModel.showNumberRow)
			Toggle(Texts.Keyboard.hapticFeedback, isOn: $viewModel.hapticFeedbackEnabled)
		} header: {
			Text(Texts.Keyboard.header)
		} footer: {
			Text(Texts.Keyboard.hapticFooter)
		}
	}

	private var supportSection: some View {
		Section {
			Button(Texts.setupInstructions) { sheet = .onboarding }
		}
	}

	private var aboutSection: some View {
		Section {
			Button(Texts.about) { sheet = .about }
			HStack {
				Text(Texts.version)
					.foregroundStyle(.secondary)
				Spacer()
				Text(viewModel.versionString)
					.foregroundStyle(.tertiary)
			}
			.font(.footnote)
		}
	}

	private enum SheetKind: Identifiable {
		case onboarding, about
		var id: String { String(describing: self) }
	}
}

#if DEBUG
#Preview {
	SettingsView(viewModel: SettingsViewModelMock())
		.preferredColorScheme(.dark)
}
#endif
