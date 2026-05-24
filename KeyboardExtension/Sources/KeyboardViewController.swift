import UIKit
import SwiftUI
import KeyboardCore
import KeyboardUI

/// Principal class for the Keybo custom keyboard extension.
/// `@objc(KeyboardViewController)` exposes an unmangled Obj-C name so the system
/// extension loader can resolve it via NSExtensionPrincipalClass without relying
/// on Swift name mangling. This is the only place in the project where `@objc` is used.
@objc(KeyboardViewController)
final class KeyboardViewController: UIInputViewController {

	private var state = KeyboardState()
	private var hostingController: UIHostingController<KeyboardRoot>?
	private lazy var proxyAdapter = TextProxyAdapter(textDocumentProxy)

	override func viewDidLoad() {
		super.viewDidLoad()
		installHostingController()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		refreshReturnKeyType()
	}

	override func textWillChange(_ textInput: UITextInput?) {}

	override func textDidChange(_ textInput: UITextInput?) {
		refreshReturnKeyType()
	}

	// MARK: - Hosting

	private func installHostingController() {
		let root = KeyboardRoot(state: state, dispatch: { [weak self] key in
			self?.handle(key)
		})
		let host = UIHostingController(rootView: root)
		host.view.translatesAutoresizingMaskIntoConstraints = false
		host.view.backgroundColor = .clear

		addChild(host)
		view.addSubview(host.view)
		NSLayoutConstraint.activate([
			host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			host.view.topAnchor.constraint(equalTo: view.topAnchor),
			host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])
		host.didMove(toParent: self)
		hostingController = host
	}

	private func rebuild() {
		hostingController?.rootView = KeyboardRoot(state: state, dispatch: { [weak self] key in
			self?.handle(key)
		})
	}

	// MARK: - Input

	private func handle(_ key: Key) {
		InputDispatcher.dispatch(
			key: key,
			state: &state,
			proxy: proxyAdapter,
			controller: self
		)
		rebuild()
	}

	private func refreshReturnKeyType() {
		let rawType = textDocumentProxy.returnKeyType ?? .default
		let newType = ReturnKeyTypeMapping.map(rawType)
		if state.returnKeyType != newType {
			state.returnKeyType = newType
			rebuild()
		}
	}
}

// MARK: - KeyboardControlling conformance
// `advanceToNextInputMode()` and `dismissKeyboard()` are inherited from UIInputViewController,
// so this conformance is empty — just declares the protocol relationship.
extension KeyboardViewController: KeyboardControlling {}
