import Foundation

/// Keyboard click sound hook fired from `KeyView` on touch-down (parallel to the haptic), so
/// audio + tactile feedback land at the same moment the finger touches the key. Real
/// implementation lives in `KeyboardExtension/UIKitClickSound` and wraps
/// `UIDevice.current.playInputClick()`. iOS only emits the click when the controller's *visible
/// input view* adopts `UIInputViewAudioFeedback` (the controller itself is not inspected) **and**
/// the user has "Keyboard Clicks" enabled in Settings → Sounds & Haptics, **and** the extension
/// has Allow Full Access. The system gates audibility for us, the app-side toggle just decides
/// whether to call `play()` in the first place.
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
