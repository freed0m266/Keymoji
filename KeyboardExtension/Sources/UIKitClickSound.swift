import UIKit
import KeyboardCore

/// Real keyboard click sound implementation. `UIDevice.current.playInputClick()` only produces
/// audio when the controller's *visible input view* conforms to `UIInputViewAudioFeedback`
/// (see `KeyboInputView` in `KeyboardViewController.swift`) and the user has "Keyboard Clicks"
/// enabled in Settings → Sounds & Haptics. Apple additionally requires Allow Full Access for
/// the extension before `playInputClick` produces audio. The system gates audibility; our
/// `isEnabled` closure adds a per-app override read from `AppGroupStore`.
@MainActor
final class UIKitClickSound: KeyClickSounding {
	private let isEnabled: () -> Bool

	init(isEnabled: @escaping () -> Bool) {
		self.isEnabled = isEnabled
	}

	func play() {
		guard isEnabled() else { return }
		UIDevice.current.playInputClick()
	}
}
