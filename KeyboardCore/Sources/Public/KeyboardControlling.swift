import Foundation

/// Abstraction over `UIInputViewController` methods that the dispatcher needs to call
/// (dismiss). Lets `KeyboardCore` stay UIKit-free.
///
/// `@MainActor` matches `UIInputViewController`'s isolation so the conformance in the
/// extension target compiles cleanly under Swift 6 strict concurrency.
@MainActor
public protocol KeyboardControlling: AnyObject {
	func dismissKeyboard()
}
