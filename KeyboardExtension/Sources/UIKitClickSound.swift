import UIKit
import AudioToolbox
import KeyboardCore

/// Real keyboard click sound implementation. Two distinct paths, matching the native keyboard's
/// per-key sounds (task 46):
///
/// - **Character keys** use `UIDevice.current.playInputClick()`. It only produces audio when the
///   controller's *visible input view* conforms to `UIInputViewAudioFeedback` (see `KeymojiInputView`
///   in `KeyboardViewController.swift`) and the user has "Keyboard Clicks" enabled in Settings →
///   Sounds & Haptics. This is the idiomatic Apple path
///   and routes through the quiet UI-sound level — the volume profile validated in task 41.
///
/// - **Space and delete** use `AudioServicesPlaySystemSound(_:)` with specific keyboard sound IDs,
///   because `playInputClick()` cannot select which sound to play. **Conscious trade-off:**
///   `AudioServicesPlaySystemSound` does *not* honor the system "Keyboard Clicks" toggle (that
///   state can't be read by an extension), so space/delete will click even if the user disabled
///   system keyboard clicks — while still being gated by our app-side `isEnabled` toggle
///   (`AppGroupStore.keyClickSoundEnabled`). The character path above keeps honoring the system toggle,
///   so only space/delete diverge. We accept this small loss of native parity to gain the distinct
///   space/delete sounds the native keyboard has.
///
/// In all cases the `.ambient` audio-session category pinned in `KeyboardViewController`
/// (`configureAudioSession`) keeps playback non-interrupting and silenced by the Ring/Silent switch,
/// so host-app music isn't ducked or paused.
///
/// NOTE (on-device verification still required — task 46 spike): the sound IDs below are not
/// publicly documented by Apple and the volume/toggle behavior of `AudioServicesPlaySystemSound`
/// for these IDs must be confirmed by ear against the stock keyboard on a real device, including a
/// re-check of the task-41 volume scenario (Spotify playing → open Keymoji → type).
@MainActor
final class UIKitClickSound: KeyClickSounding {
	private let isEnabled: () -> Bool

	/// Modifier / space — the deeper, "hollower" native click.
	private static let spaceSoundID: SystemSoundID = 1156
	/// Delete / backspace.
	private static let deleteSoundID: SystemSoundID = 1155

	init(isEnabled: @escaping () -> Bool) {
		self.isEnabled = isEnabled
	}

	func play(for kind: ClickSoundKind) {
		guard isEnabled() else { return }
		switch kind {
		case .character:
			UIDevice.current.playInputClick()
		case .space:
			AudioServicesPlaySystemSound(Self.spaceSoundID)
		case .delete:
			AudioServicesPlaySystemSound(Self.deleteSoundID)
		}
	}
}
