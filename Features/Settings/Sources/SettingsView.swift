//
//  SettingsView.swift
//  Settings
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import KeymojiCore
import KeymojiResources
import KeymojiUI

import About
import EmojiCodes
import FavoriteEmojisEditor
import LearnedWordsEditor
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
				suggestionsSection
				favoritesSection
				emojiCodesSection
				supportSection
				aboutSection
			}
			.mainBackground()
			.onAppear { viewModel.refreshLearnedWordCount() }
			.navigationTitle(Texts.title)
			.sheet(item: $sheet) { kind in
				NavigationStack {
					switch kind {
					case .onboarding:
						OnboardingView(viewModel: onboardingVM(), onFinish: { sheet = nil })
					case .featureTour:
						OnboardingView(
							viewModel: onboardingVM(),
							initialStep: .featureTour,
							onFinish: { sheet = nil }
						)
					case .about:
						AboutView(viewModel: aboutVM())
					}
				}
				.preferredColorScheme(.dark)
			}
		}
	}

	@ViewBuilder
	private var keyboardSection: some View {
		Section {
			Toggle(Texts.Keyboard.showNumberRow, isOn: $viewModel.showNumberRow)
			Toggle(Texts.Keyboard.hapticFeedback, isOn: $viewModel.hapticFeedbackEnabled)
			Toggle(Texts.Keyboard.keyClickSound, isOn: $viewModel.keyClickSoundEnabled)
		} header: {
			Text(Texts.Keyboard.header)
		} footer: {
			Text(Texts.Keyboard.hapticFooter)
		}

		Section {
			Picker(Texts.Keyboard.appearance, selection: $viewModel.appearance) {
				ForEach(AppearancePreference.allCases, id: \.self) { pref in
					Text(label(for: pref)).tag(pref)
				}
			}
			.pickerStyle(.segmented)
		} footer: {
			Text(Texts.Keyboard.appearanceFooter)
		}

		Section {
			Picker(Texts.Keyboard.letterLayout, selection: $viewModel.letterLayout) {
				ForEach(LetterLayout.allCases, id: \.self) { layout in
					Text(label(for: layout)).tag(layout)
				}
			}
			.pickerStyle(.segmented)
		} footer: {
			Text(Texts.Keyboard.letterLayoutFooter)
		}

		Section {
			Picker(Texts.Keyboard.spaceDoubleTapAction, selection: $viewModel.spaceDoubleTapAction) {
				ForEach(SpaceDoubleTapAction.allCases, id: \.self) { action in
					Text(label(for: action)).tag(action)
				}
			}
			.pickerStyle(.menu)
		} footer: {
			Text(Texts.Keyboard.spaceDoubleTapFooter)
		}
	}

	@ViewBuilder
	private var suggestionsSection: some View {
		Section {
			Toggle(Texts.Suggestions.toggleTitle, isOn: $viewModel.suggestionsEnabled)

			if viewModel.suggestionsEnabled {
				Section {
					NavigationLink {
						LearnedWordsEditorView(viewModel: learnedWordsEditorVM())
					} label: {
						HStack {
							Text(Texts.Suggestions.learnedWordsLabel)
							Spacer()
							Text("\(viewModel.learnedWordCount)")
								.foregroundStyle(.secondary)
						}
					}
				}
			}
		} header: {
			Text(Texts.Suggestions.sectionHeader)
		} footer: {
			Text(Texts.Suggestions.toggleFooter)
		}
	}

	private func label(for preference: AppearancePreference) -> String {
		switch preference {
		case .system: return Texts.Keyboard.Appearance.system
		case .light:  return Texts.Keyboard.Appearance.light
		case .dark:   return Texts.Keyboard.Appearance.dark
		}
	}

	private func label(for action: SpaceDoubleTapAction) -> String {
		switch action {
		case .insertPeriod:    return Texts.Keyboard.SpaceDoubleTap.insertPeriod
		case .dismissKeyboard: return Texts.Keyboard.SpaceDoubleTap.dismissKeyboard
		case .none:            return Texts.Keyboard.SpaceDoubleTap.none
		}
	}

	private func label(for layout: LetterLayout) -> String {
		switch layout {
		case .qwerty: return Texts.Keyboard.LetterLayout.qwerty
		case .qwertz: return Texts.Keyboard.LetterLayout.qwertz
		}
	}

	private var favoritesSection: some View {
		Section {
			NavigationLink {
				FavoriteEmojisEditorView(viewModel: favoriteEmojisEditorVM())
			} label: {
				Text(Texts.Favorites.row)
			}
		} footer: {
			Text(Texts.Favorites.footer)
		}
	}

	private var emojiCodesSection: some View {
		Section {
			NavigationLink {
				EmojiCodesView(viewModel: emojiCodesVM())
			} label: {
				Text(Texts.EmojiCodes.row)
			}
		} footer: {
			Text(Texts.EmojiCodes.footer)
		}
	}

	private var supportSection: some View {
		Section {
			Button(Texts.setupInstructions) { sheet = .onboarding }
			Button(Texts.featureTour) { sheet = .featureTour }
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
		case onboarding, featureTour, about
		var id: String { String(describing: self) }
	}
}

#if DEBUG
#Preview {
	SettingsView(viewModel: SettingsViewModelMock())
		.preferredColorScheme(.dark)
}
#endif
