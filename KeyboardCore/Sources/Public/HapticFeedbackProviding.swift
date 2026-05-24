import Foundation

/// Haptic feedback hooks consumed by `InputDispatcher` and `KeyView` (via popover callbacks).
/// Real implementation lives in `KeyboardExtension/UIKitHaptics`. `NoopHaptics` is a safe fallback
/// for unit tests and previews.
///
/// `@MainActor` matches UIKit's `UIImpactFeedbackGenerator` isolation.
@MainActor
public protocol HapticFeedbackProviding {
	func keyTap()
	func popoverEntry()
	func popoverHighlightChanged()
}

public struct NoopHaptics: HapticFeedbackProviding {
	public init() {}
	public func keyTap() {}
	public func popoverEntry() {}
	public func popoverHighlightChanged() {}
}
