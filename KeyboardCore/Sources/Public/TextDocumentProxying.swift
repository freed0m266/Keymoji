import Foundation

/// Abstraction over `UITextDocumentProxy` so `KeyboardCore` stays UIKit-free and the
/// dispatcher is unit-testable with a mock. The extension target supplies a real adapter
/// by wrapping `UITextDocumentProxy`.
///
/// `@MainActor` matches UIKit's actor isolation — the keyboard runs on the main thread
/// and so does this protocol's conforming types.
@MainActor
public protocol TextDocumentProxying: AnyObject {
	var documentContextBeforeInput: String? { get }
	var documentContextAfterInput: String? { get }
	func insertText(_ text: String)
	func deleteBackward()
	/// Move the insertion point by `offset` characters (negative = left, positive = right).
	/// Backs the trackpad-on-space cursor scrubbing. Maps directly to
	/// `UITextDocumentProxy.adjustTextPosition(byCharacterOffset:)`.
	func adjustTextPosition(byCharacterOffset offset: Int)
}
