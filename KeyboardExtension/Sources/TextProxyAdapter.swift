import UIKit
import KeyboardCore

/// Adapts `UITextDocumentProxy` (a UIKit protocol without `AnyObject` constraint)
/// to `KeyboardCore.TextDocumentProxying`. Lives in the extension target because it
/// imports UIKit.
final class TextProxyAdapter: TextDocumentProxying {
	private let proxy: UITextDocumentProxy

	init(_ proxy: UITextDocumentProxy) {
		self.proxy = proxy
	}

	var documentContextBeforeInput: String? {
		proxy.documentContextBeforeInput
	}

	var documentContextAfterInput: String? {
		proxy.documentContextAfterInput
	}

	func insertText(_ text: String) {
		proxy.insertText(text)
	}

	func deleteBackward() {
		proxy.deleteBackward()
	}
}
