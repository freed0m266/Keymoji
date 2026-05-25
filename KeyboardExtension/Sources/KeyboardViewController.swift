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
	private lazy var clickSound: any KeyClickSounding = UIKitClickSound(isEnabled: { [weak self] in
		self?.store.keyClickSoundEnabled ?? false
	})

	/// Install a `UIInputView` subclass that adopts `UIInputViewAudioFeedback` as the controller's
	/// root view. iOS routes `UIDevice.current.playInputClick()` through the currently visible
	/// **input view**'s conformance — adopting the protocol on `UIInputViewController` itself does
	/// not work, the controller is never inspected. `inputViewStyle: .keyboard` matches the default
	/// `UIInputViewController.view` style so the SwiftUI host on top renders identically.
	override func loadView() {
		view = KeyboInputView(frame: .zero, inputViewStyle: .keyboard)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		installHostingController()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		refreshFromStore()
		refreshAppearance()
		refreshReturnKeyType()
	}

	override func viewDidLayoutSubviews() {
		let signpostState = perfSignposter.beginInterval(
			"viewDidLayoutSubviews",
			"bounds=\(self.view.bounds.width)x\(self.view.bounds.height)"
		)
		super.viewDidLayoutSubviews()
		// `view.bounds.width` is the authoritative visible width of the keyboard host. We propagate
		// it into state so SwiftUI's `KeyboardView` can size itself exactly, avoiding the right-edge
		// clipping caused by `GeometryReader` under-reporting inside `UIInputView` on real devices.
		let width = view.bounds.width
		if state.keyboardWidth != width, width > 0 {
			perfSignposter.emitEvent("widthChanged", "from=\(self.state.keyboardWidth) to=\(width)")
			state.keyboardWidth = width
			rebuild()
		}
		updateHostRasterization()
		perfSignposter.endInterval("viewDidLayoutSubviews", signpostState)
	}

	/// Task 29 experiment — swipe-down dismiss jank.
	/// Profiling showed that during the iOS-driven dismiss animation our `rebuild()` guard works
	/// (rebuild fires 1–2× across the gesture, not per-frame), but SwiftUI still does a ~4 ms
	/// `UnaryChildGeometry<_FrameLayout>` *Creation* on each `KeyboInputView.layoutSubviews`
	/// pass — five of those in the dismiss window stack up to a measured 33 ms hitch.
	///
	/// Fix: while CoreAnimation is position-animating our input view (swipe-down dismiss, also
	/// the initial slide-up), tell it to render the SwiftUI host to a bitmap once and reuse the
	/// cache for every frame of the motion. The animation only moves `origin.y` — content is
	/// invariant for the duration, so the cached bitmap is correct. We unflip the switch as soon
	/// as the animation ends so interactive renders (key flashes, popovers, trackpad fade) stay
	/// direct and don't pay re-rasterization cost.
	private func updateHostRasterization() {
		guard let hostLayer = hostingController?.view.layer else { return }
		let isAnimating = view.layer.animationKeys()?.isEmpty == false
		guard hostLayer.shouldRasterize != isAnimating else { return }
		perfSignposter.emitEvent("rasterizeToggle", "on=\(isAnimating)")
		hostLayer.shouldRasterize = isAnimating
		if isAnimating {
			// Cache at native pixel density so the composite stays sharp.
			hostLayer.rasterizationScale = traitCollection.displayScale
		}
	}

	/// Pulls cross-process preferences (number row toggle, etc.) on each appearance.
	/// v1.0 has no live observation — settings changes from the host take effect next time the keyboard appears.
	private func refreshFromStore() {
		var changed = false
		let showRow = store.showNumberRow
		if state.showNumberRow != showRow {
			state.showNumberRow = showRow
			changed = true
		}
		let storedRecents = store.recentEmojis
		if state.recentEmojis != storedRecents {
			state.recentEmojis = storedRecents
			changed = true
		}
		let storedFavorites = store.favoriteEmojis
		if state.favoriteEmojis != storedFavorites {
			state.favoriteEmojis = storedFavorites
			changed = true
		}
		if changed { rebuild() }
	}

	/// Applies the user's `AppearancePreference` by overriding the host controller's trait
	/// collection. `.unspecified` means "inherit from the consuming app" (the v1.0 behavior).
	/// SwiftUI's `.preferredColorScheme` doesn't propagate reliably out of `UIInputViewController`
	/// — it tries to set the scene's interface style, which keyboard extensions don't own —
	/// so we drive it at the UIKit layer instead.
	private func refreshAppearance() {
		let style: UIUserInterfaceStyle = {
			switch store.appearance {
			case .system: return .unspecified
			case .light:  return .light
			case .dark:   return .dark
			}
		}()
		hostingController?.overrideUserInterfaceStyle = style
		hostingController?.view.overrideUserInterfaceStyle = style
	}

	override func textWillChange(_ textInput: UITextInput?) {}

	override func textDidChange(_ textInput: UITextInput?) {
		refreshReturnKeyType()
		refreshAutoCapitalization()
	}

	// MARK: - Hosting

	private func installHostingController() {
		let root = makeRoot()
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
		let signpostState = perfSignposter.beginInterval("rebuild")
		hostingController?.rootView = makeRoot()
		perfSignposter.endInterval("rebuild", signpostState)
	}

	/// Build the SwiftUI root with the current state and the live Slack typeahead suggestions.
	/// Suggestions are derived from `documentContextBeforeInput` here (not stored in `KeyboardState`)
	/// so the view always reflects what the proxy sees right now — including transient cases where
	/// the dispatcher and the proxy disagree by a frame.
	private func makeRoot() -> KeyboardRoot {
		let suggestions = currentSlackSuggestions()
		return KeyboardRoot(
			state: state,
			slackSuggestions: suggestions,
			dispatch: { [weak self] key in self?.handle(key) },
			toggleFavoriteEmoji: { [weak self] emoji in self?.toggleFavorite(emoji) },
			selectSlackSuggestion: { [weak self] suggestion in self?.selectSlackSuggestion(suggestion) },
			onKeyTapHaptic: { [weak self] in self?.haptics.keyTap() },
			onKeyClick: { [weak self] in self?.clickSound.play() },
			onPopoverEntry: { [weak self] in self?.haptics.popoverEntry() },
			onHighlightChanged: { [weak self] in self?.haptics.popoverHighlightChanged() },
			// Word-delete needs visible context. Password fields and other hidden inputs
			// return nil/empty here — falling back keeps char-repeat going at full speed.
			canEscalateBackspace: { [weak self] in
				guard let context = self?.textDocumentProxy.documentContextBeforeInput else { return false }
				return !context.isEmpty
			},
			onTrackpadModeEntered: { [weak self] in self?.haptics.trackpadModeEntered() }
		)
	}

	/// Compute Slack-style shortcode suggestions from the current document context.
	/// Only fires on letter pages — the bar is suppressed on symbol/emoji pages since the user
	/// can't reasonably be authoring a shortcode there.
	private func currentSlackSuggestions() -> [SlackEmojiSuggester.Suggestion] {
		guard case .letters = state.page else { return [] }
		return SlackEmojiSuggester.suggestions(forContext: textDocumentProxy.documentContextBeforeInput)
	}

	/// User tapped a suggestion chip. Delete the in-progress `:prefix` from the document,
	/// insert the emoji, mirror the same recents/shift handling as the closing-colon path.
	private func selectSlackSuggestion(_ suggestion: SlackEmojiSuggester.Suggestion) {
		guard let context = textDocumentProxy.documentContextBeforeInput else { return }
		guard let prefix = SlackEmojiSuggester.activeShortcodePrefix(
			in: context,
			minLength: SlackEmojiSuggester.defaultMinPrefixLength
		) else { return }

		// Delete `:` + prefix from the document, then insert the emoji.
		let charsToDelete = prefix.count + 1
		for _ in 0..<charsToDelete {
			textDocumentProxy.deleteBackward()
		}
		textDocumentProxy.insertText(suggestion.emoji)

		// Mirror dispatcher behavior: bump emoji to head of recents (deduped, capped), persist,
		// and downshift caps lock so the next character isn't accidentally uppercased.
		var updatedRecents = state.recentEmojis
		updatedRecents.removeAll { $0 == suggestion.emoji }
		updatedRecents.insert(suggestion.emoji, at: 0)
		if updatedRecents.count > KeyboardState.recentEmojisCapacity {
			updatedRecents = Array(updatedRecents.prefix(KeyboardState.recentEmojisCapacity))
		}
		state.recentEmojis = updatedRecents
		store.recentEmojis = updatedRecents

		ShiftStateMachine.apply(.characterInserted, to: &state)

		rebuild()
	}

	// MARK: - Input

	private func handle(_ key: Key) {
		// Haptic + click for the key tap itself are fired by `KeyView` on touch-down (matches
		// Apple/SwiftKey feel — feedback when the finger lands, not when it lifts). The dispatcher
		// is concerned with state + text proxy only.
		let pageBefore = state.page
		let recentsBefore = state.recentEmojis
		InputDispatcher.dispatch(
			key: key,
			state: &state,
			proxy: proxyAdapter,
			controller: self
		)
		recordRecentEmojiIfNeeded(key: key)
		// The dispatcher updates `state.recentEmojis` directly when a Slack-style shortcode
		// substitution lands (the emoji is inserted via the proxy, not a synthesized `emoji.` key,
		// so the path above is a no-op for it). Mirror the change to the cross-process store here.
		if state.recentEmojis != recentsBefore, state.recentEmojis != store.recentEmojis {
			store.recentEmojis = state.recentEmojis
		}
		// Re-evaluate auto-cap only after `switchPage` — that's the one action where the document
		// can already carry a pending auto-cap (e.g. user typed `? ` on symbols, then hit ABC) but
		// `textDidChange` won't fire. For text-changing actions, `textDidChange` triggers the
		// re-eval automatically. For `.shift` we must NOT re-evaluate: doing so would immediately
		// override a manual lowercase override at sentence start (Instagram message field, etc.).
		// `.space` on a symbol page implicitly switches to letters *after* `insertText`; any
		// `textDidChange` that fired synchronously during the insert saw the old `.symbols` page
		// and skipped auto-cap, so re-run here for that implicit transition (covers "Yes! How…").
		if case .switchPage = key.action {
			refreshAutoCapitalization()
		} else if case .space = key.action, pageBefore != state.page {
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

	/// Toggles `emoji` in the user's favorites and persists the change cross-process so the
	/// host app's Favorites editor reflects it on next read. Mutates `state` + rebuilds the
	/// view so the panel updates immediately without waiting for the next `viewWillAppear`.
	private func toggleFavorite(_ emoji: String) {
		var updated = state.favoriteEmojis
		if let index = updated.firstIndex(of: emoji) {
			updated.remove(at: index)
		} else {
			updated.append(emoji)
		}
		state.favoriteEmojis = updated
		store.favoriteEmojis = updated
		rebuild()
	}

	/// Moves the just-inserted emoji to the head of `recentEmojis` (deduped) and persists.
	/// Keyed off `key.id` prefix because the synthesized emoji keys carry no other distinguishing
	/// info — `.insertText` with arbitrary content would otherwise match regular character keys.
	private func recordRecentEmojiIfNeeded(key: Key) {
		guard key.id.hasPrefix("emoji.") else { return }
		guard case .insertText(let emoji) = key.action, !emoji.isEmpty else { return }

		var updated = state.recentEmojis
		updated.removeAll { $0 == emoji }
		updated.insert(emoji, at: 0)
		if updated.count > KeyboardState.recentEmojisCapacity {
			updated = Array(updated.prefix(KeyboardState.recentEmojisCapacity))
		}
		state.recentEmojis = updated
		store.recentEmojis = updated
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

// MARK: - Click-sound input view
// `UIDevice.current.playInputClick()` only produces audio when the *visible input view* — not the
// controller — conforms to `UIInputViewAudioFeedback` and returns `true` from
// `enableInputClicksWhenVisible`. iOS additionally gates audibility on the user's Settings →
// Sounds & Haptics → Keyboard Clicks preference, and (per Apple's custom keyboard guide)
// `playInputClick` requires Allow Full Access to be enabled for the extension.
private final class KeyboInputView: UIInputView, UIInputViewAudioFeedback {
	var enableInputClicksWhenVisible: Bool { true }

	override func layoutSubviews() {
		let signpostState = perfSignposter.beginInterval(
			"KeyboInputView.layoutSubviews",
			"frame=\(self.frame.origin.y)/\(self.frame.size.height)"
		)
		super.layoutSubviews()
		perfSignposter.endInterval("KeyboInputView.layoutSubviews", signpostState)
	}
}
