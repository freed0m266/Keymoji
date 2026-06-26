//
//  SettingsView.swift
//  Settings
//
//  Created by Martin Svoboda on 24.05.2026.
//  Copyright © 2026 Freedom Martin, s.r.o. All rights reserved.
//

import SwiftUI
import BaseKitX
import KeyboardCore
import KeymojiCore
import KeymojiResources
import KeymojiUI

import About
import EmojiCodes
import FavoriteEmojisEditor
import LearnedWordsEditor
import Onboarding
import Paywall

#if DEBUG
import Debug
#endif

public struct SettingsView<ViewModel: SettingsViewModeling>: View {
	@Bindable private var viewModel: ViewModel
	@State private var sheet: SheetKind?
	@State private var paywallContext: PaywallContext?
	/// Welcome-trial confirm alert (S2 tap) and the short post-activation toast.
	@State private var showWelcomeConfirm = false
	@State private var welcomeToast: String?

	typealias Texts = L10n.Settings
	typealias WelcomeTexts = L10n.Welcome.Settings

	public init(viewModel: ViewModel) {
		_viewModel = Bindable(wrappedValue: viewModel)
	}

	public var body: some View {
		NavigationStack {
			Form {
				favoritesSection
				emojiCodesSection
				keyboardSection
				suggestionsSection
				plusSection
				supportSection
				aboutSection
				#if DEBUG
				debugSection
				#endif
			}
			.mainBackground()
			.overlay(alignment: .bottom) { welcomeToastView }
			.onAppear { viewModel.refreshLearnedWordCount() }
			.navigationTitle(Texts.title)
			.sheet(item: $sheet) { kind in
				NavigationStack {
					OnboardingView(
						viewModel: onboardingVM(initialStep: kind.initialStep),
						onFinish: { sheet = nil }
					)
				}
			}
			.sheet(item: $paywallContext) { context in
				PaywallView(
					viewModel: paywallVM(context: context),
					onFinish: { paywallContext = nil }
				)
			}
		}
	}

	private var favoritesSection: some View {
		Section {
			NavigationLink {
				FavoriteEmojisEditorView(viewModel: favoriteEmojisEditorVM())
			} label: {
				Text("⭐️ \(Texts.Favorites.row)")
			}
		} header: {
			Text(Texts.Favorites.header)
		} footer: {
			Text(Texts.Favorites.footer)
		}
	}

	private var emojiCodesSection: some View {
		Section {
			NavigationLink {
				EmojiCodesView(viewModel: emojiCodesVM())
			} label: {
				Text("📖 \(Texts.EmojiCodes.row)")
			}
		} footer: {
			Text(Texts.EmojiCodes.footer)
		}
	}

	@ViewBuilder
	private var keyboardSection: some View {
		Section {
			Toggle(Texts.Keyboard.showNumberRow, isOn: $viewModel.showNumberRow)
		} header: {
			Text(Texts.Keyboard.header)
		} footer: {
			Text(Texts.Keyboard.showNumberRowHint)
		}

		Section {
			Toggle(Texts.Keyboard.hapticFeedback, isOn: $viewModel.hapticFeedbackEnabled)
			Toggle(Texts.Keyboard.keyClickSound, isOn: $viewModel.keyClickSoundEnabled)
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
			Picker(Texts.Keyboard.letterAlternateSet, selection: $viewModel.letterAlternateSet) {
				ForEach(LetterAlternateSet.allCases, id: \.self) { set in
					Text(label(for: set)).tag(set)
				}
			}
			.pickerStyle(.menu)
		} footer: {
			Text(Texts.Keyboard.letterAlternateSetFooter)
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

		Section {
			Toggle(Texts.Keyboard.autoCapitalization, isOn: $viewModel.autoCapitalizationEnabled)
		} footer: {
			Text(Texts.Keyboard.autoCapitalizationFooter)
		}
	}

	/// Consume the gift, then surface a short toast confirming the new expiry. The row itself flips to
	/// the trial-countdown state reactively (the VM updates its observable promo mirrors).
	private func confirmWelcomeActivation() {
		viewModel.activateWelcomeTrial()
		guard let until = viewModel.trialActiveUntil else { return }
		welcomeToast = WelcomeTexts.toast(until.formatted(date: .abbreviated, time: .omitted))
		Task {
			try? await Task.sleep(for: .seconds(3))
			withAnimation { welcomeToast = nil }
		}
	}

	@ViewBuilder
	private var welcomeToastView: some View {
		if let welcomeToast {
			Text(welcomeToast)
				.font(.subheadline.weight(.medium))
				.foregroundStyle(.primary)
				.padding(.horizontal, 16)
				.padding(.vertical, 10)
				.background(.regularMaterial, in: Capsule())
				.padding(.bottom, 24)
				.shadow(radius: 8, y: 2)
				.transition(.move(edge: .bottom).combined(with: .opacity))
		}
	}

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

	private var plusSection: some View {
		Section {
			switch viewModel.plusRowState {
			case .paid:
				Label(Texts.Plus.unlocked, systemImage: "checkmark.seal.fill")
					.foregroundStyle(.primary)

			case .welcomeAvailable:
				// The opt-in gift — explicit consent via a confirm alert (one-shot, so we ask first).
				ListButton(title: "🎁 \(WelcomeTexts.cta)") {
					showWelcomeConfirm = true
				}
				.buttonStyle(.plain)

			case .trialActive(let daysLeft):
				// Info only — no upsell while a trial is running (holds task 63 "don't nag").
				Label(Texts.Plus.trialDaysLeft(daysLeft), systemImage: "gift.fill")
					.foregroundStyle(.primary)

			case .afterTrial:
				// Trial lapsed → loss-aversion paywall ("You loved Plus. Get it back.").
				ListButton(title: "✨ \(Texts.Plus.unlock)") {
					paywallContext = .afterTrial
				}
				.buttonStyle(.plain)
			}
		} header: {
			Text(Texts.Plus.header)
		} footer: {
			Text(Texts.Plus.footer)
		}
		.alert(WelcomeTexts.Confirm.title, isPresented: $showWelcomeConfirm) {
			Button(WelcomeTexts.Confirm.activate) { confirmWelcomeActivation() }
			Button(WelcomeTexts.Confirm.cancel, role: .cancel) {}
		} message: {
			Text(WelcomeTexts.Confirm.message)
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
			NavigationLink {
				AboutView(viewModel: aboutVM())
			} label: {
				Text(Texts.about)
					.font(.body.weight(.semibold))
			}
		} header: {
			Text(Texts.aboutHeader)
		}
	}

	#if DEBUG
	/// Developer-only entry to the simulate-free-user tools (task 67). Compiled out of Release entirely;
	/// the `Debug` framework ships empty. Sits last in the form, below the snapshot fold.
	private var debugSection: some View {
		Section {
			NavigationLink {
				DebugMenuView(viewModel: debugMenuVM())
			} label: {
				Text("🛠 Debug")
			}
		} header: {
			Text("Developer")
		}
	}
	#endif

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

	/// Accent-set name in the app's UI language (today English → "Czech", "Slovak", …). Deliberately
	/// *not* `Locale.current.localizedString`, which on a Czech device would hand back the endonym
	/// "čeština"; the UI app is English-only, so we resolve against `preferredLocalizations`. Only the
	/// catch-all "All" set is a Keymoji concept rather than a language, so it stays on L10n.
	private func label(for set: LetterAlternateSet) -> String {
		if set == .all { return Texts.Keyboard.LetterAlternateSet.all }
		let uiLocale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
		let code = set.accentLanguageCode ?? "en"   // concrete language; `.all` handled above
		return uiLocale.localizedString(forLanguageCode: code)?.capitalizedFirstLetter() ?? code
	}

}

private extension SettingsView {
	enum SheetKind: Int, Identifiable {
		case onboarding
		case featureTour

		var id: Self { self }

		var initialStep: OnboardingStep {
			switch self {
			case .onboarding: .addKeyboard
			case .featureTour: .featureTour
			}
		}
	}
}

#if DEBUG
#Preview {
	SettingsView(viewModel: SettingsViewModelMock())
		.preferredColorScheme(.dark)
}
#endif
