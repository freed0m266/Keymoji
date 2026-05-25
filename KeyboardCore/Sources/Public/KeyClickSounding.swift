import Foundation

/// Keyboard click sound hook consumed by `InputDispatcher`. Real implementation lives in
/// `KeyboardExtension/UIKitClickSound` and wraps `UIDevice.current.playInputClick()`. iOS only
/// emits the click when the host controller adopts `UIInputViewAudioFeedback` *and* the user
/// has "Keyboard Clicks" enabled in Settings → Sounds & Haptics — the system gates audibility
/// for us, the app-side toggle just decides whether to call `play()` in the first place.
///
/// `@MainActor` matches `UIDevice` isolation.
@MainActor
public protocol KeyClickSounding {
	func play()
}

public struct NoopClickSound: KeyClickSounding {
	public init() {}
	public func play() {}
}
