import AVFoundation
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
	/// Constraint that drives the keyboard's vertical footprint. Most pages keep it at the
	/// regular iOS keyboard height (~260 pt); `.emojiSearch` mode bumps it taller so the
	/// search bar and horizontal results bar above the QWERTY rows aren't clipped by the
	/// host UIInputView. iOS reads non-required height constraints on the input view as
	/// the keyboard's desired height.
	private var keyboardHeightConstraint: NSLayoutConstraint?
	private lazy var proxyAdapter = TextProxyAdapter(textDocumentProxy)
	private let store = AppGroupStore.shared
	private let settingsNotifier = SettingsChangeNotifier.shared
	private var settingsObservers: [SettingsObservationToken] = []
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
		configureAudioSession()
		installHostingController()
		installSettingsObservers()
		installKeyboardHeightConstraint()
	}

	/// Task 41 root cause (hypothesis 1): without an explicit category the extension's audio
	/// session starts on the system default, and the first few `UIDevice.current.playInputClick()`
	/// calls after the keyboard appears get routed through a media-level output — audibly loud,
	/// roughly at the volume of whatever the foreground app (Spotify, YouTube, …) is playing —
	/// before iOS settles the route down to the quiet system keyboard-click level for the rest of
	/// the session. Pinning the session to `.ambient` here, before any click can fire, routes the
	/// very first click through the quiet UI-sound path so we match the native keyboard from the
	/// first keystroke. `.ambient` is correct for UI sound effects: silenced by the Ring/Silent
	/// switch and — by category definition — non-interrupting, so it mixes with the host app's
	/// audio without pausing or ducking it (the `.mixWithOthers` *option* is only valid with the
	/// playback categories and would make `setCategory` throw here, so it's deliberately omitted).
	/// A failed set is non-fatal (it only risks the original loud intro, never a crash) and the
	/// extension has no logging destination, so we swallow it.
	private func configureAudioSession() {
		try? AVAudioSession.sharedInstance().setCategory(.ambient)
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		refreshFromStore()
		refreshAppearance()
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

	/// Subscribes to Darwin notifications for the host-mutable settings that affect rendering.
	/// `hapticFeedbackEnabled` / `keyClickSoundEnabled` aren't observed because their callsites
	/// re-read `AppGroupStore` on every tap — the next keystroke already picks up the new value.
	/// Tokens live in `settingsObservers`; they remove themselves on `deinit` when the controller
	/// is torn down (extension reload), so no explicit cleanup is needed.
	private func installSettingsObservers() {
		settingsObservers = [
			settingsNotifier.addObserver(for: .showNumberRow) { [weak self] in
				self?.refreshFromStore()
			},
			settingsNotifier.addObserver(for: .favoriteEmojis) { [weak self] in
				self?.refreshFromStore()
			},
			settingsNotifier.addObserver(for: .appearance) { [weak self] in
				self?.refreshAppearance()
			}
		]
	}

	/// Pulls cross-process preferences (number row toggle, etc.) on each appearance and on every
	/// Darwin notification fired by the host app. The `viewWillAppear` path is the fallback for
	/// state we may have missed while the controller wasn't around to receive notifications.
	private func refreshFromStore() {
		var changed = false
		let showRow = store.showNumberRow
		if state.showNumberRow != showRow {
			state.showNumberRow = showRow
			changed = true
		}
		let doubleTap = store.spaceDoubleTapAction
		if state.spaceDoubleTapAction != doubleTap {
			state.spaceDoubleTapAction = doubleTap
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

		// Task 29 — swipe-down dismiss jank. The standard `additionalSafeAreaInsets = .zero`
		// above only zeros the *additional* layer; system safe-area still propagates through
		// UIHostingController into SwiftUI. During the swipe-down dismiss iOS continuously
		// recomputes the keyboard's safe-area as it moves past the home-indicator zone, which
		// cascades into a SwiftUI layout pass per frame (~4 ms `UnaryChildGeometry<_FrameLayout>`
		// Creation, measured 5× per dismiss = ~20 ms of the 33 ms hitch). This kills the cascade
		// at the source by subclassing the hosting view at runtime to permanently return zero
		// safe-area. Keyboards never need safe-area awareness inside their own bounds anyway.
		Self.disableSafeAreaInsets(on: host.view)

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

	/// Subclasses `view`'s class at runtime to override `safeAreaInsets` to always return zero.
	/// Used on the hosting controller's root view to stop UIHostingController from propagating
	/// per-frame safe-area changes into SwiftUI during system-driven keyboard animations.
	///
	/// Implementation: allocates a one-off `<OriginalClass>_DisableSafeArea` subclass that
	/// overrides the safeAreaInsets getter, then swaps the instance's class via `object_setClass`.
	/// Cached by suffix so repeated installs (e.g., after extension reload) reuse the same
	/// subclass instead of leaking a new one each time. Pure Obj-C runtime — no private API.
	private static func disableSafeAreaInsets(on view: UIView) {
		guard let viewClass = object_getClass(view) else { return }
		let subclassName = String(cString: class_getName(viewClass)).appending("_DisableSafeArea")
		if let existing = NSClassFromString(subclassName) {
			object_setClass(view, existing)
			return
		}
		guard let utf8Name = (subclassName as NSString).utf8String,
		      let subclass = objc_allocateClassPair(viewClass, utf8Name, 0) else {
			return
		}
		if let method = class_getInstanceMethod(UIView.self, #selector(getter: UIView.safeAreaInsets)) {
			let zeroInsets: @convention(block) (AnyObject) -> UIEdgeInsets = { _ in .zero }
			class_addMethod(
				subclass,
				#selector(getter: UIView.safeAreaInsets),
				imp_implementationWithBlock(zeroInsets),
				method_getTypeEncoding(method)
			)
		}
		objc_registerClassPair(subclass)
		object_setClass(view, subclass)
	}

	private func rebuild() {
		hostingController?.rootView = makeRoot()
		updateKeyboardHeightConstraint()
	}

	// MARK: - Keyboard height

	/// Resting heights for the SwiftUI keyboard. Mirror `KeyboardView.keyboardHeight` so the
	/// host UIInputView and the SwiftUI content agree on size — if the SwiftUI frame is
	/// taller than the host, the overflow gets clipped (visible as a missing search bar at
	/// the top of `.emojiSearch` mode, reported on real device).
	private static let regularHeightWithNumberRow: CGFloat = 260
	private static let regularHeightWithoutNumberRow: CGFloat = 216
	/// Extra footprint for the search bar + horizontal results bar stacked above the QWERTY
	/// rows in `.emojiSearch`. Matches `KeyboardView.emojiSearchChromeHeight`.
	private static let emojiSearchChromeFootprint: CGFloat = 97

	private func installKeyboardHeightConstraint() {
		let constraint = view.heightAnchor.constraint(equalToConstant: desiredKeyboardHeight())
		// `.required - 1`: high enough for iOS to honour as the keyboard's desired height,
		// low enough that the system can still override during keyboard-frame animations
		// (e.g. swipe-down dismiss) without auto-layout exceptions.
		constraint.priority = UILayoutPriority(rawValue: UILayoutPriority.required.rawValue - 1)
		constraint.isActive = true
		keyboardHeightConstraint = constraint
	}

	private func updateKeyboardHeightConstraint() {
		guard let constraint = keyboardHeightConstraint else { return }
		let desired = desiredKeyboardHeight()
		if constraint.constant != desired {
			constraint.constant = desired
			view.setNeedsLayout()
		}
	}

	private func desiredKeyboardHeight() -> CGFloat {
		if state.page.isEmojiSearch {
			return Self.regularHeightWithoutNumberRow + Self.emojiSearchChromeFootprint
		}
		return state.showNumberRow ? Self.regularHeightWithNumberRow : Self.regularHeightWithoutNumberRow
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
// `dismissKeyboard()` is inherited from UIInputViewController, so this conformance is empty —
// just declares the protocol relationship.
extension KeyboardViewController: KeyboardControlling {}

// MARK: - Click-sound input view
// `UIDevice.current.playInputClick()` only produces audio when the *visible input view* — not the
// controller — conforms to `UIInputViewAudioFeedback` and returns `true` from
// `enableInputClicksWhenVisible`. iOS additionally gates audibility on the user's Settings →
// Sounds & Haptics → Keyboard Clicks preference, and (per Apple's custom keyboard guide)
// `playInputClick` requires Allow Full Access to be enabled for the extension.
private final class KeyboInputView: UIInputView, UIInputViewAudioFeedback {
	var enableInputClicksWhenVisible: Bool { true }
}
