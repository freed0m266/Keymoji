import AVFoundation
import UIKit
import SwiftUI
import KeymojiCore
import KeyboardCore
import KeyboardUI

/// Principal class for the Keymoji custom keyboard extension.
/// `@objc(KeyboardViewController)` exposes an unmangled Obj-C name so the system
/// extension loader can resolve it via NSExtensionPrincipalClass without relying
/// on Swift name mangling. This is the only place in the project where `@objc` is used.
@objc(KeyboardViewController)
final class KeyboardViewController: UIInputViewController {

	private var state = KeyboardState()
	/// The favorites order actually rendered in the bar/panel. Recomputed from counts only while the
	/// favorites aren't on screen (see `refreshFavoritesDisplayOrder`) so `.frequency` never reshuffles
	/// under the user's finger. Cleared on disappear so each appearance starts from a fresh ordering.
	private var favoritesDisplayOrder: [String] = []
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

	/// Eagerly created in `viewDidLoad` (LX2) so the first `.completions(...)` call doesn't pay the
	/// lazy-init hitch on the user's first keystroke.
	private lazy var textChecker = UITextChecker()
	/// Snapshot of Apple's supplementary lexicon (text-replacement shortcuts, contact names) as
	/// Sendable string pairs. Empty until `requestSupplementaryLexicon` delivers — the word
	/// completion provider degrades gracefully (just skips that source).
	private var lexiconEntries: [(trigger: String, expansion: String)] = []
	/// Personal word-completion recents pool, backed by the same App Group store as everything else.
	private lazy var recentsStore = PersonalRecentsStore(store: store)
	/// Hook the dispatcher calls to learn a word at each word boundary (prose fields only).
	private lazy var learningHook = LearningHook { [weak self] word, context in
		self?.recentsStore.learn(word, fromContextType: context)
	}
	/// Latest complete-looking email staged from the focused email field, learned only when the
	/// field is done (focus moves away, or the keyboard disappears). Staging a single value rather
	/// than learning on every edit means we never persist progressive partials ("foo@x.c", …).
	private var pendingEmail: String?
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
		view = KeymojiInputView(frame: .zero, inputViewStyle: .keyboard)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		configureAudioSession()
		installHostingController()
		installSettingsObservers()
		installKeyboardHeightConstraint()
		// Drop the number row in landscape the moment the height class flips. `traitCollectionDidChange`
		// is deprecated on iOS 17+, so we use the modern trait-registration API; the initial value is
		// also seeded in `viewDidLayoutSubviews`, where the trait collection is finalized.
		registerForTraitChanges([UITraitVerticalSizeClass.self]) { (controller: KeyboardViewController, _: UITraitCollection) in
			controller.refreshOrientation()
		}
		// Eager-touch the text checker so its first real query (the user's first keystroke) doesn't
		// pay the init hitch (LX2), and pull in Apple's supplementary lexicon when it's ready.
		_ = textChecker
		// iOS invokes this completion on a background queue (`com.apple.TextInput.lexicon-request`),
		// NOT the main actor. `requestSupplementaryLexicon` is imported with a non-`@Sendable`
		// `(UILexicon) -> Void` completion, and `UIInputViewController` is `@MainActor`, so a normal
		// closure formed here is *inferred* `@MainActor` (closure isolation inheritance). When UIKit
		// then calls it off-main, the Swift-6 executor check traps (EXC_BREAKPOINT), silently killing
		// the extension. `@Sendable` forbids that inheritance, making the closure nonisolated so no
		// check is inserted. We then hop onto the main actor before touching anything — including
		// reading `UILexicon`, which is itself `@MainActor`. (Do NOT use `MainActor.assumeIsolated`
		// here: we are genuinely off-main, so it would just trap again.)
		requestSupplementaryLexicon { @Sendable [weak self] lexicon in
			Task { @MainActor in
				self?.lexiconEntries = lexicon.entries.map { (trigger: $0.userInput, expansion: $0.documentText) }
				self?.rebuild()
			}
		}
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
		// Pre-warm the Taptic Engine before the user starts typing — it idles after a few seconds,
		// so the first tap after each appearance would otherwise pay the wake-from-idle latency.
		haptics.prepareForInput()
		refreshFromStore()
		refreshAppearance()
		refreshReturnKeyType()
		refreshEligibility()
		refreshLanguage()
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		// Last chance to learn a freshly-typed email before the field goes away.
		commitPendingEmail()
		// Drop the frozen favorites order: the keyboard is going away, so the next appearance can
		// safely re-apply the latest `.frequency` ordering (seeded lazily in `makeRoot`).
		favoritesDisplayOrder = []
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
		// Seed/refresh the landscape flag here too — the trait collection is finalized by layout time,
		// so this catches the very first appearance (before any `registerForTraitChanges` callback fires).
		refreshOrientation()
	}

	/// Mirrors the host's vertical size class into `state.isLandscape`. On iPhone, `.compact` height
	/// means landscape — the most reliable orientation signal for a keyboard extension (it owns no
	/// scene/window orientation API). Drives `effectiveShowsNumberRow`, so a change rebuilds the layout
	/// and re-derives the host height constraint immediately.
	private func refreshOrientation() {
		let isLandscape = traitCollection.verticalSizeClass == .compact
		if state.isLandscape != isLandscape {
			state.isLandscape = isLandscape
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
			settingsNotifier.addObserver(for: .letterLayout) { [weak self] in
				self?.refreshFromStore()
			},
			settingsNotifier.addObserver(for: .letterAlternateSet) { [weak self] in
				self?.refreshFromStore()
			},
			settingsNotifier.addObserver(for: .favoriteEmojis) { [weak self] in
				self?.refreshFromStore()
			},
			settingsNotifier.addObserver(for: .favoritesSortMode) { [weak self] in
				self?.refreshFromStore()
			},
			settingsNotifier.addObserver(for: .appearance) { [weak self] in
				self?.refreshAppearance()
			},
			settingsNotifier.addObserver(for: .suggestionsEnabled) { [weak self] in
				self?.refreshFromStore()
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
		let layout = store.letterLayout
		if state.letterLayout != layout {
			state.letterLayout = layout
			changed = true
		}
		let alternateSet = store.letterAlternateSet
		if state.letterAlternateSet != alternateSet {
			state.letterAlternateSet = alternateSet
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
		let storedSortMode = store.favoritesSortMode
		if state.favoritesSortMode != storedSortMode {
			state.favoritesSortMode = storedSortMode
			changed = true
		}
		let storedUsageCounts = store.emojiUsageCounts
		if state.emojiUsageCounts != storedUsageCounts {
			state.emojiUsageCounts = storedUsageCounts
			changed = true
		}
		let suggestionsOn = store.suggestionsEnabled
		if state.suggestionsEnabled != suggestionsOn {
			state.suggestionsEnabled = suggestionsOn
			// Turning suggestions off drops any staged email so it's never learned later.
			if !suggestionsOn { pendingEmail = nil }
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
		refreshEligibility()
		refreshLanguage()
		updatePendingEmailIfNeeded()
	}

	// MARK: - Suggestion eligibility & language

	/// Re-evaluates whether the focused field may show the bar / be learned from. Drives the bar's
	/// visibility (via `showsSuggestionBar`) and the dispatcher's learning context.
	private func refreshEligibility() {
		let eligibility = SuggestionEligibility.evaluate(
			isSecureTextEntry: textDocumentProxy.isSecureTextEntry == true,
			keyboardType: SuggestionFieldTraitsMapping.keyboardKind(textDocumentProxy.keyboardType ?? .default),
			textContentType: SuggestionFieldTraitsMapping.contentKind(textDocumentProxy.textContentType)
		)
		if state.currentEligibility != eligibility {
			// Focus is leaving the previous field — learn any whole email staged from it before
			// the staged value is overwritten by (or reset for) the new field.
			commitPendingEmail()
			state.currentEligibility = eligibility
			rebuild()
		}
	}

	/// Tracks the focused field's primary language so `UITextChecker` queries the right dictionary.
	private func refreshLanguage() {
		let language = textInputMode?.primaryLanguage
		if state.currentLanguage != language {
			state.currentLanguage = language
			rebuild()
		}
	}

	/// Whole-field email learning (§3/§7d). In an email field, stage the latest complete-looking
	/// address (`@` + a dotted domain, within the sanity cap) on each edit — but don't learn yet.
	/// Overwriting a single pending value means we keep only the *finished* address, never the
	/// progressive partials the user typed on the way ("foo@x.c", "foo@x.co", …).
	private func updatePendingEmailIfNeeded() {
		guard state.suggestionsEnabled, state.currentEligibility.learningContext == .emailAddress else { return }
		let before = textDocumentProxy.documentContextBeforeInput ?? ""
		let after = textDocumentProxy.documentContextAfterInput ?? ""
		let content = (before + after).trimmingCharacters(in: .whitespacesAndNewlines)
		// Stage only a *currently* valid whole address. Clearing the stage otherwise means we never
		// commit an address the user has since deleted or broken (e.g. backspaced past the domain).
		pendingEmail = isLearnableEmail(content) ? content : nil
	}

	/// A complete-looking, in-bounds email worth learning: contains `@` with a dotted domain after it.
	private func isLearnableEmail(_ content: String) -> Bool {
		guard !content.isEmpty, content.count <= PersonalRecentsStore.maxEmailLength else { return false }
		guard let atIndex = content.firstIndex(of: "@") else { return false }
		return content[content.index(after: atIndex)...].contains(".")
	}

	/// Learn the staged whole-field email, if any, when the field is done — focus moving to another
	/// field (detected in `refreshEligibility`) or the keyboard disappearing. Cleared (not learned)
	/// when suggestions are disabled.
	private func commitPendingEmail() {
		guard let email = pendingEmail else { return }
		pendingEmail = nil
		guard state.suggestionsEnabled else { return }
		recentsStore.learn(email, fromContextType: .emailAddress)
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
		// Build the same layout `makeRoot` renders, then ask `KeyboardMetrics` for its height. The host
		// UIInputView constraint and the SwiftUI frame therefore come from one formula and can't drift —
		// drift used to clip the SwiftUI content (missing search bar at the top of `.emojiSearch`). The
		// height no longer depends on `showsSuggestionBar` (task 61): the top region is reserved on every
		// page regardless of the suggestions toggle / field eligibility, so the keyboard never changes
		// height when the bar appears or disappears.
		let layout = KeyboardCore.makeLayout(
			page: state.page,
			showNumberRow: state.effectiveShowsNumberRow,
			returnKeyType: state.returnKeyType,
			letterLayout: state.letterLayout,
			alternateSet: state.letterAlternateSet
		)
		return KeyboardMetrics.keyboardHeight(for: layout)
	}

	/// Build the SwiftUI root with the current state and the live suggestion list. Suggestions are
	/// derived from `documentContextBeforeInput` here (not stored in `KeyboardState`) so the view
	/// always reflects what the proxy sees right now — including transient cases where the
	/// dispatcher and the proxy disagree by a frame.
	private func makeRoot() -> KeyboardRoot {
		let showsBar = showsSuggestionBar
		let suggestions = showsBar ? currentSuggestions() : []
		// Favorites are on screen when the bar is showing them (no word/Slack suggestions occupy it)
		// or the emoji panel is open. Freeze their order while visible so it never reshuffles mid-use.
		let favoritesVisible = (showsBar && suggestions.isEmpty) || state.page == .emojis
		refreshFavoritesDisplayOrder(favoritesVisible: favoritesVisible)
		return KeyboardRoot(
			state: state,
			favoriteEmojis: favoritesDisplayOrder,
			suggestions: suggestions,
			showsSuggestionBar: showsBar,
			dispatch: { [weak self] key in self?.handle(key) },
			toggleFavoriteEmoji: { [weak self] emoji in self?.toggleFavorite(emoji) },
			selectSuggestion: { [weak self] suggestion in self?.selectSuggestion(suggestion) },
			onKeyTapHaptic: { [weak self] in self?.haptics.keyTap() },
			onKeyClick: { [weak self] kind in self?.clickSound.play(for: kind) },
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

	/// Updates `favoritesDisplayOrder` — the order shown in the bar/panel — without ever reshuffling
	/// what the user is currently looking at:
	/// - When the favorites are **hidden** (or on the first seed), re-apply the full ordering, so
	///   `.frequency` picks up the latest usage counts the next time the favorites appear.
	/// - When they're **visible**, keep the frozen order and only reconcile membership: drop emojis
	///   that were just un-favorited and append newly-favorited ones at the end (a long-press toggle
	///   must still take effect, but existing items stay put).
	private func refreshFavoritesDisplayOrder(favoritesVisible: Bool) {
		guard favoritesVisible, !favoritesDisplayOrder.isEmpty else {
			favoritesDisplayOrder = orderedFavorites()
			return
		}
		let favorites = Set(state.favoriteEmojis)
		var reconciled = favoritesDisplayOrder.filter { favorites.contains($0) }
		let present = Set(reconciled)
		for emoji in state.favoriteEmojis where !present.contains(emoji) {
			reconciled.append(emoji)
		}
		favoritesDisplayOrder = reconciled
	}

	/// The favorites ordered per the current sort mode and usage counts. `.manual` returns the
	/// hand-curated order unchanged; `.frequency` sorts by count descending (stable on ties).
	private func orderedFavorites() -> [String] {
		FavoritesOrdering.ordered(
			state.favoriteEmojis,
			counts: state.emojiUsageCounts,
			mode: state.favoritesSortMode
		)
	}

	/// Whether the suggestion bar may occupy the top region right now: master toggle on, the field
	/// allows display, and we're not on the emoji panel or an emoji-search page (so it shows on letters
	/// *and* symbols). This is a pure **content** gate (task 61) — it decides whether suggestions are
	/// computed and the bar is rendered, but no longer drives height (the top region is reserved
	/// unconditionally), so it can't cause host/view drift the way it used to.
	private var showsSuggestionBar: Bool {
		guard state.suggestionsEnabled, state.currentEligibility.allowDisplay else { return false }
		return state.page != .emojis && !state.page.isEmojiSearch
	}

	/// Run the coordinator over the current document context. Slack shortcodes win wholesale when
	/// present (pill chips); otherwise word completions are merged from recents + `UITextChecker` +
	/// `UILexicon`. Providers are cheap value types, rebuilt per call so they always see fresh state.
	private func currentSuggestions() -> [Suggestion] {
		let context = SuggestionContext(
			documentContextBeforeInput: textDocumentProxy.documentContextBeforeInput,
			documentContextAfterInput: textDocumentProxy.documentContextAfterInput,
			page: state.page,
			primaryLanguage: state.currentLanguage,
			eligibility: state.currentEligibility
		)
		let coordinator = SuggestionCoordinator(providers: [
			SlackSuggestionProvider(),
			WordCompletionProvider(
				textChecker: UITextCheckerAdapter(textChecker),
				systemLexicon: UILexiconAdapter(entries: lexiconEntries),
				recents: recentsStore
			)
		])
		return coordinator.suggestions(for: context)
	}

	/// User tapped a chip. Slack pills run the emoji-substitution path; word chips route through
	/// the dispatcher's `.suggestionAccept` (delete prefix → insert + space) like any other key.
	private func selectSuggestion(_ suggestion: Suggestion) {
		switch suggestion.source {
		case .slack:
			applySlackSuggestion(emoji: suggestion.replacementText)
		case .wordCompletion:
			let key = Key(
				id: "suggestion.\(suggestion.id)",
				primary: .text(suggestion.displayText),
				alternates: [],
				action: .suggestionAccept(
					displayText: suggestion.displayText,
					replacementText: suggestion.replacementText
				),
				visualWeight: .standard,
				role: .system
			)
			handle(key)
		}
	}

	/// Delete the in-progress `:prefix` from the document, insert the emoji, and mirror the same
	/// recents/shift handling as the closing-colon substitution path.
	private func applySlackSuggestion(emoji: String) {
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
		textDocumentProxy.insertText(emoji)

		// Mirror dispatcher behavior: bump emoji to head of recents (deduped, capped), persist,
		// and downshift caps lock so the next character isn't accidentally uppercased.
		var updatedRecents = state.recentEmojis
		updatedRecents.removeAll { $0 == emoji }
		updatedRecents.insert(emoji, at: 0)
		if updatedRecents.count > KeyboardState.recentEmojisCapacity {
			updatedRecents = Array(updatedRecents.prefix(KeyboardState.recentEmojisCapacity))
		}
		state.recentEmojis = updatedRecents
		store.recentEmojis = updatedRecents

		// Slack substitution doesn't synthesize an `emoji.` key, so `recordRecentEmojiIfNeeded`
		// never sees it — bump the usage count here too (keep in sync with that path).
		incrementEmojiUsage(emoji)

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
		// Disabling word suggestions stops learning too (not just the bar) — the Settings footer and
		// privacy policy both promise the opt-out halts on-device learning.
		InputDispatcher.dispatch(
			key: key,
			state: &state,
			proxy: proxyAdapter,
			controller: self,
			learning: state.suggestionsEnabled ? learningHook : nil
		)
		// The dispatcher updates `state.recentEmojis` directly when a typed `:shortcode:` auto-
		// substitutes to an emoji (inserted via the proxy, not a synthesized `emoji.` key). That
		// path bypasses `recordRecentEmojiIfNeeded` below, so detect it here by the recents change
		// during dispatch and bump the usage count for the inserted emoji (head of recents).
		if state.recentEmojis != recentsBefore, let inserted = state.recentEmojis.first {
			incrementEmojiUsage(inserted)
		}
		recordRecentEmojiIfNeeded(key: key)
		// Mirror any recents change (synth `emoji.` key or Slack substitution) to the cross-process store.
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

		incrementEmojiUsage(emoji)
	}

	/// Bumps the lifetime usage count for `emoji` (any insertion path) and persists. Drives
	/// `.frequency` favorites ordering. Keep in sync with the three emoji insertion sites:
	/// `recordRecentEmojiIfNeeded` (synth `emoji.` keys — panel/recents/favorites taps & search),
	/// `applySlackSuggestion` (tapping a Slack shortcode suggestion), and the dispatcher's typed
	/// `:shortcode:` auto-substitution (detected in `handle`). Counts update live, but the displayed
	/// favorites order is recomputed only while the favorites are hidden (see
	/// `refreshFavoritesDisplayOrder`), so the bar/panel never reshuffle under the user's finger.
	private func incrementEmojiUsage(_ emoji: String) {
		guard !emoji.isEmpty else { return }
		state.emojiUsageCounts[emoji, default: 0] += 1
		store.emojiUsageCounts = state.emojiUsageCounts
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
private final class KeymojiInputView: UIInputView, UIInputViewAudioFeedback {
	var enableInputClicksWhenVisible: Bool { true }
}
