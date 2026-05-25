import UIKit
import KeyboardCore

/// Real keyboard click sound implementation. `UIDevice.current.playInputClick()` only produces
/// audio when `KeyboardViewController` conforms to `UIInputViewAudioFeedback` (returning
/// `enableInputClicksWhenVisible = true`) *and* the user has "Keyboard Clicks" enabled in
/// Settings → Sounds & Haptics. The system gates audibility; our `isEnabled` closure adds a
/// per-app override read from `AppGroupStore`.
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
