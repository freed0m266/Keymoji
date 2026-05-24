import UIKit
import SwiftUI
import KeyboCore
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
	private let store = AppGroupStore.shared
	private lazy var haptics: any HapticFeedbackProviding = UIKitHaptics(isEnabled: { [weak self] in
		self?.store.hapticFeedbackEnabled ?? true
	})

	override func viewDidLoad() {
		super.viewDidLoad()
		installHostingController()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		refreshFromStore()
		refreshReturnKeyType()
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		// `view.bounds.width` is the authoritative visible width of the keyboard host. We propagate
		// it into state so SwiftUI's `KeyboardView` can size itself exactly, avoiding the right-edge
		// clipping caused by `GeometryReader` under-reporting inside `UIInputView` on real devices.
		let width = view.bounds.width
		if state.keyboardWidth != width, width > 0 {
			state.keyboardWidth = width
			rebuild()
		}
	}

	/// Pulls cross-process preferences (number row toggle, etc.) on each appearance.
	/// v1.0 has no live observation — settings changes from the host take effect next time the keyboard appears.
	private func refreshFromStore() {
		let showRow = store.showNumberRow
		if state.showNumberRow != showRow {
			state.showNumberRow = showRow
			rebuild()
		}
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
			onKeyTapHaptic: { [weak self] in self?.haptics.keyTap() },
			onPopoverEntry: { [weak self] in self?.haptics.popoverEntry() },
			onHighlightChanged: { [weak self] in self?.haptics.popoverHighlightChanged() }
		)
		let host = UIHostingController(rootView: root)
		host.view.translatesAutoresizingMaskIntoConstraints = false
		host.view.backgroundColor = .clear

		// `UIInputViewController` exposes its content via `inputView`. Letting SwiftUI's hosting
		// controller respect safe areas inside the keyboard view causes a right-shift on devices
		// with horizontal safe areas (notch/island in some orientations) — we want edge-to-edge.
		host.additionalSafeAreaInsets = .zero
		host.view.insetsLayoutMarginsFromSafeArea = false
		host.view.preservesSuperviewLayoutMargins = false
		host.view.layoutMargins = .zero

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
			onKeyTapHaptic: { [weak self] in self?.haptics.keyTap() },
			onPopoverEntry: { [weak self] in self?.haptics.popoverEntry() },
			onHighlightChanged: { [weak self] in self?.haptics.popoverHighlightChanged() }
		)
	}

	// MARK: - Input

	private func handle(_ key: Key) {
		// Haptic for the key tap itself is fired by `KeyView` on touch-down (matches Apple/SwiftKey
		// feel). The dispatcher is concerned with state + text proxy only.
		InputDispatcher.dispatch(
			key: key,
			state: &state,
			proxy: proxyAdapter,
			controller: self
		)
		// Re-evaluate auto-cap only after `switchPage` — that's the one action where the document
		// can already carry a pending auto-cap (e.g. user typed `? ` on symbols, then hit ABC) but
		// `textDidChange` won't fire. For text-changing actions, `textDidChange` triggers the
		// re-eval automatically. For `.shift` we must NOT re-evaluate: doing so would immediately
		// override a manual lowercase override at sentence start (Instagram message field, etc.).
		if case .switchPage = key.action {
			refreshAutoCapitalization()
		}
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
