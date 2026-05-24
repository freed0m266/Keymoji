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
	private lazy var haptics: any HapticFeedbackProviding = UIKitHaptics(isEnabled: { [weak self] in
		// Task 10 wires this to AppGroupStore.hapticFeedbackEnabled. For now: always on.
		self?.isHapticEnabled() ?? true
	})

	private func isHapticEnabled() -> Bool {
		// Placeholder — task 10 reads from AppGroupStore.
		true
	}

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
		refreshAutoCapitalization()
	}

	// MARK: - Hosting

	private func installHostingController() {
		let root = KeyboardRoot(
			state: state,
			dispatch: { [weak self] key in self?.handle(key) },
			onPopoverEntry: { [weak self] in self?.haptics.popoverEntry() },
			onHighlightChanged: { [weak self] in self?.haptics.popoverHighlightChanged() }
		)
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
		hostingController?.rootView = KeyboardRoot(
			state: state,
			dispatch: { [weak self] key in self?.handle(key) },
			onPopoverEntry: { [weak self] in self?.haptics.popoverEntry() },
			onHighlightChanged: { [weak self] in self?.haptics.popoverHighlightChanged() }
		)
	}

	// MARK: - Input

	private func handle(_ key: Key) {
		InputDispatcher.dispatch(
			key: key,
			state: &state,
			proxy: proxyAdapter,
			controller: self,
			haptics: haptics
		)
		// `textDidChange` covers character/space/return/backspace, but page-switches
		// don't trigger it — re-evaluate here so an auto-cap pending from `? ` on the
		// symbols page promotes the letters page after ABC toggle.
		refreshAutoCapitalization()
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

	private func refreshAutoCapitalization() {
		let rawType = textDocumentProxy.autocapitalizationType ?? .sentences
		let autoCapType = AutocapitalizationTypeMapping.map(rawType)
		let shouldCap = AutoCapitalizer.shouldCapitalize(
			documentContextBeforeInput: textDocumentProxy.documentContextBeforeInput,
			autocapitalizationType: autoCapType
		)

		if shouldCap {
			if case .letters(.lower) = state.page {
				state.page = .letters(.upper)
				state.autoCapitalized = true
				rebuild()
			}
		} else if state.autoCapitalized {
			state.autoCapitalized = false
			if case .letters(.upper) = state.page {
				state.page = .letters(.lower)
				rebuild()
			}
		}
	}
}

// MARK: - KeyboardControlling conformance
// `advanceToNextInputMode()` and `dismissKeyboard()` are inherited from UIInputViewController,
// so this conformance is empty — just declares the protocol relationship.
extension KeyboardViewController: KeyboardControlling {}
