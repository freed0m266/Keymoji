import Foundation

/// Keyboard click sound hook fired from `KeyView` on touch-down (parallel to the haptic), so
/// audio + tactile feedback land at the same moment the finger touches the key. Real
/// implementation lives in `KeyboardExtension/UIKitClickSound` and wraps
/// `UIDevice.current.playInputClick()`. iOS only emits the click when the controller's *visible
/// input view* adopts `UIInputViewAudioFeedback` (the controller itself is not inspected) **and**
/// the user has "Keyboard Clicks" enabled in Settings → Sounds & Haptics. The system gates
/// audibility for us, the app-side toggle just decides whether to call `play()` in the first place.
///
/// `@MainActor` matches `UIDevice` isolation.
///
/// The kind lets the implementation mirror the native keyboard's distinct sounds: characters keep
/// the standard input click, while space and delete play their own deeper / dedicated clicks. We
/// pass a small `ClickSoundKind` rather than leaking `KeyAction` into the UI/sound layer.
@MainActor
public protocol KeyClickSounding {
	func play(for kind: ClickSoundKind)
}

/// Which native click flavor a key press should sound like. Deliberately tiny — the view maps a
/// key's `KeyAction` onto one of these, and the sound implementation maps each onto a system sound.
public enum ClickSoundKind: Sendable, Equatable {
	/// Letters, digits, punctuation, symbols, emoji, suggestion chips — the standard input click.
	case character
	/// Space bar (and other modifiers, if added later) — the deeper, "hollower" native click.
	case space
	/// Delete / backspace, including word-delete repeat — the native delete click.
	case delete
}

public struct NoopClickSound: KeyClickSounding {
	public init() {}
	public func play(for kind: ClickSoundKind) {}
}
