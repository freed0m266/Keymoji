import AVFoundation
import UIKit
import SwiftUI
import KeymojiCore
import KeyboardCore
import KeyboardUI
import KeymojiResources

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
	/// Observable render model bound once to the hosting controller (task 73, Phase B). State changes
	/// mutate this in place instead of reassigning `hostingController.rootView`.
	private var viewModel: KeyboardViewModel?
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
				// Lexicon is a suggestion provider input that changed without the document context moving —
				// drop the memo so the next compute picks up the new completions (task 73, Phase C).
				self?.invalidateSuggestionMemo()
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
		// Baseline reload of the learned-words pool: pick up any host-app edits made while we weren't
		// running to receive the `learnedWordsChanged` Darwin ping (task 73). The pool feeds suggestions,
		// so drop the memo too — the document context may be unchanged from last appearance.
		recentsStore.reload()
		invalidateSuggestionMemo()
		refreshFromStore()
		refreshAppearance()
		// Seed the page for the first appearance into a field (numpad vs. text) before any keystroke.
		refreshKeyboardPageForInputType()
		refreshReturnKeyType()
		refreshEligibility()
		refreshLanguage()
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		// Last chance to learn a freshly-typed email before the field goes away.
		commitPendingEmail()
		// Persist any debounced learns before the keyboard goes away, so words typed in the last
		// fraction of a second aren't lost if the extension is torn down (task 73).
		recentsStore.flush()
		// Drop any pending suggestion compute — the bar is going away (task 73, Phase C).
		suggestionTask?.cancel()
		suggestionTask = nil
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
			// After a purchase/restore in the host app, the running keyboard unlocks live (unlimited
			// favorites + the chosen sort mode) without a restart.
			settingsNotifier.addObserver(for: .isPlus) { [weak self] in
				self?.refreshFromStore()
			},
			// A Welcome grant (host app or this keyboard) lands the promo expiry — unlock live.
			settingsNotifier.addObserver(for: .promoPlusExpiresAt) { [weak self] in
				self?.refreshFromStore()
			},
			settingsNotifier.addObserver(for: .appearance) { [weak self] in
				self?.refreshAppearance()
			},
			settingsNotifier.addObserver(for: .suggestionsEnabled) { [weak self] in
				self?.refreshFromStore()
			},
			settingsNotifier.addObserver(for: .autoCapitalizationEnabled) { [weak self] in
				self?.refreshFromStore()
			},
			// The host app edited the learned-words pool (removed/cleared entries) — reload the
			// in-memory index from disk so the running keyboard reflects the change live (task 73).
			// Drop the suggestion memo (the pool changed under a possibly-identical context) and rebuild
			// so a visible bar refreshes immediately rather than on the next keystroke.
			settingsNotifier.addObserver(for: .learnedWordsChanged) { [weak self] in
				self?.recentsStore.reload()
				self?.invalidateSuggestionMemo()
				self?.rebuild()
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
		let autoCapOn = store.autoCapitalizationEnabled
		if state.autoCapitalizationEnabled != autoCapOn {
			state.autoCapitalizationEnabled = autoCapOn
			// Reflect the flip immediately on a visible keyboard: turning it off should drop a pending
			// auto-promotion, turning it on should re-evaluate the current context.
			refreshAutoCapitalization()
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
		let plus = store.isPlus
		if state.isPlus != plus {
			state.isPlus = plus
			changed = true
		}
		let promoExpiry = store.promoPlusExpiresAt
		if state.promoPlusExpiresAt != promoExpiry {
			state.promoPlusExpiresAt = promoExpiry
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
		// First, so a numeric field forces the numpad before `refreshAutoCapitalization` runs —
		// it must never see a numeric page it could try to promote to `letters(.upper)`.
		refreshKeyboardPageForInputType()
		refreshReturnKeyType()
		refreshAutoCapitalization()
		refreshEligibility()
		refreshLanguage()
		updatePendingEmailIfNeeded()
	}

	// MARK: - Suggestion eligibility & language

	/// Re-evaluates whether the focused field may show the bar / be learned from. `allowDisplay` drives the
	/// bar's visibility (forwarded as `fieldAllowsBar`) and gates suggestion computation (`suggestionsActive`);
	/// the learning context drives what the dispatcher may learn from.
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

	/// Forces the numpad when the focused field requests a numeric keyboard, and snaps back to
	/// letters when leaving one (task 59). Deliberately *non-sticky* and self-contained: it only
	/// ever moves the page between "numpad" and "not numpad", so regular `letters`/`symbols`/`emoji`
	/// navigation (driven by `switchPage` in the dispatcher) is never disturbed — the numpad just
	/// slides in over a numeric field and slides back out to `letters(.lower)` on exit.
	private func refreshKeyboardPageForInputType() {
		let kind = SuggestionFieldTraitsMapping.keyboardKind(textDocumentProxy.keyboardType ?? .default)
		let desired: KeyboardPage
		if let numeric = NumericPageResolver.numericPage(for: kind) {
			desired = numeric                  // numeric field → always the numpad
		} else if state.page.isNumeric {
			desired = .letters(.lower)         // left a numeric field → back to letters (non-sticky)
		} else {
			return                             // non-numeric field, not on the numpad → leave typing page alone
		}
		guard state.page != desired else { return }
		state.page = desired
		rebuild()
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
		let model = makeViewModel()
		self.viewModel = model
		let host = UIHostingController(rootView: KeyboardRoot(model: model))
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

	/// Push the current state into the observable model and refresh the host height. Despite the name
	/// (kept so every call site reads the same), this no longer rebuilds the SwiftUI tree — it mutates
	/// the bound `KeyboardViewModel` in place (task 73, Phase B), letting Observation invalidate only
	/// the subviews whose inputs actually changed.
	private func rebuild() {
		Perf.measure("rebuild") {
			syncModel()
			updateKeyboardHeightConstraint()
		}
	}

	/// Reconcile the observable model with the current `KeyboardState`. Each property is guarded by an
	/// equality check so untouched slices don't notify observers — e.g. a plain letter changes only
	/// `suggestions`, leaving `layout` (and therefore the key grid) untouched.
	///
	/// The synchronous, layout-affecting slice (layout/width/recents/searchQuery/fieldAllowsBar) is
	/// applied inline for instant press-feel. The expensive suggestion pipeline is *not* run here —
	/// `scheduleSuggestions()` debounces it off the keystroke path (task 73, Phase C). `refreshFavorites`
	/// reconciles the favorites baseline against whatever the model currently shows.
	private func syncModel() {
		guard let model = viewModel else { return }
		let layout = currentLayout()
		if model.layout != layout { model.layout = layout }
		if model.width != state.keyboardWidth { model.width = state.keyboardWidth }
		if model.recentEmojis != state.recentEmojis { model.recentEmojis = state.recentEmojis }
		if model.searchQuery != state.searchQuery { model.searchQuery = state.searchQuery }
		let allowsBar = state.currentEligibility.allowDisplay
		if model.fieldAllowsBar != allowsBar { model.fieldAllowsBar = allowsBar }
		// Re-derive on every sync so an entitlement change picked up mid-session (promo trial expiring,
		// or the entitlement resolving after a reinstall) flips the bar's alignment to match.
		let centersFavorites = !state.effectiveIsPlus
		if model.centersFavorites != centersFavorites { model.centersFavorites = centersFavorites }
		scheduleSuggestions()
		refreshFavorites()
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

	/// Device decimal separator used by the `.numeric(.decimal)` numpad (task 59). Read from
	/// `Locale.current` at the UIKit boundary so `KeyboardCore`/`LayoutBuilder` stay pure and the
	/// page enum stays locale-agnostic. Re-read per access so a region change is picked up on the
	/// next rebuild. Falls back to `.` for the rare locale with no decimal separator.
	private static var currentDecimalSeparator: String {
		Locale.current.decimalSeparator ?? "."
	}

	private func desiredKeyboardHeight() -> CGFloat {
		// Share the one memoized layout `syncModel` renders, then ask `KeyboardMetrics` for its height.
		// The host UIInputView constraint and the SwiftUI frame therefore come from one formula and one
		// build per keystroke (task 73, Phase B — previously `makeLayout` ran twice, here and in the
		// view body). The height no longer depends on `showsSuggestionBar` (task 61): the top region is
		// reserved on every page regardless of the suggestions toggle / field eligibility, so the
		// keyboard never changes height when the bar appears or disappears.
		KeyboardMetrics.keyboardHeight(for: currentLayout())
	}

	// MARK: - Memoized layout

	/// Inputs that fully determine `KeyboardCore.makeLayout`. When unchanged across rebuilds, the cached
	/// layout is reused, so a keystroke that doesn't alter the layout pays no `makeLayout` cost at all
	/// (and the view body + height share the same instance — one build, not two).
	private struct LayoutInputs: Equatable {
		let page: KeyboardPage
		let showsNumberRow: Bool
		let returnKeyType: ReturnKeyType
		let letterLayout: LetterLayout
		let alternateSet: LetterAlternateSet
		let decimalSeparator: String
	}
	private var lastLayoutInputs: LayoutInputs?
	private var memoizedLayout: KeyboardLayout?

	private func currentLayout() -> KeyboardLayout {
		let inputs = LayoutInputs(
			page: state.page,
			showsNumberRow: state.effectiveShowsNumberRow,
			returnKeyType: state.returnKeyType,
			letterLayout: state.letterLayout,
			alternateSet: state.letterAlternateSet,
			decimalSeparator: Self.currentDecimalSeparator
		)
		if let memoizedLayout, inputs == lastLayoutInputs { return memoizedLayout }
		let layout = KeyboardCore.makeLayout(
			page: inputs.page,
			showNumberRow: inputs.showsNumberRow,
			returnKeyType: inputs.returnKeyType,
			letterLayout: inputs.letterLayout,
			alternateSet: inputs.alternateSet,
			decimalSeparator: inputs.decimalSeparator
		)
		lastLayoutInputs = inputs
		memoizedLayout = layout
		return layout
	}

	/// Build the observable render model once, seeded with the current state and the stable callbacks
	/// (task 73, Phase B). The callbacks capture `self` weakly and forward to the controller, so they
	/// never reference stale state and never need reallocating on a state change.
	private func makeViewModel() -> KeyboardViewModel {
		// Seed the bar empty: at install time no field is focused (eligibility starts `.denied`), so there
		// are no suggestions yet. The favorites baseline is computed for the empty-suggestions state; the
		// async pipeline fills suggestions on the first eligible keystroke (task 73, Phase C).
		let onTextPage = state.page != .emojis && !state.page.isEmojiSearch
		let favoritesVisible = (state.currentEligibility.allowDisplay && onTextPage) || state.page == .emojis
		refreshFavoritesDisplayOrder(favoritesVisible: favoritesVisible)
		return KeyboardViewModel(
			layout: currentLayout(),
			width: state.keyboardWidth,
			recentEmojis: state.recentEmojis,
			favoriteEmojis: favoritesDisplayOrder,
			// Free users see a single page of ≤6 favorites — center the cluster so it doesn't look
			// stranded at the left. Plus is multi-page/paged and wants its last partial page flush-left,
			// so it stays left-aligned. The view only learns "center or not", never the entitlement.
			centersFavorites: !state.effectiveIsPlus,
			searchQuery: state.searchQuery,
			suggestions: [],
			fieldAllowsBar: state.currentEligibility.allowDisplay,
			dispatch: { [weak self] key in self?.handle(key) },
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

	/// Reconcile the favorites baseline shown in the bar against the model's *current* suggestions.
	///
	/// The favorites bar is on screen whenever the field allows the bar (not a secure field), we're on a
	/// letter/symbol page, and word/Slack suggestions aren't occupying it — or the emoji panel is open.
	/// Freeze the order while visible so it never reshuffles mid-use. This is decoupled from the
	/// suggestions master toggle: with suggestions off, suggestions stay empty but the favorites baseline
	/// still shows, so it must still be frozen — otherwise `.frequency` would reshuffle live as usage
	/// counts change. (In a secure field the bar is hidden, so favorites aren't visible there.)
	///
	/// Called both synchronously from `syncModel` and when the async pipeline delivers suggestions, so the
	/// visible/frozen decision always reflects what the bar is actually showing (task 73, Phase C).
	private func refreshFavorites() {
		guard let model = viewModel else { return }
		let onTextPage = state.page != .emojis && !state.page.isEmojiSearch
		let favoritesVisible = (state.currentEligibility.allowDisplay && onTextPage && model.suggestions.isEmpty)
			|| state.page == .emojis
		refreshFavoritesDisplayOrder(favoritesVisible: favoritesVisible)
		if model.favoriteEmojis != favoritesDisplayOrder { model.favoriteEmojis = favoritesDisplayOrder }
	}

	// MARK: - Suggestion pipeline (debounced / cancellable / memoized)

	/// In-flight suggestion computation. Cancelled and replaced on every state change, so rapid typing
	/// only ever pays for one compute per pause (coalescing) and intermediate keystrokes skip it entirely.
	private var suggestionTask: Task<Void, Never>?
	/// Memoization: the inputs and output of the last computed suggestion list. Identical inputs (e.g. a
	/// `rebuild` triggered by something that didn't move the caret) reuse the cached result.
	private var lastSuggestionContext: SuggestionContext?
	private var lastSuggestions: [Suggestion] = []
	/// Debounce window. Coalesces a burst of keystrokes into a single compute; short enough that the bar
	/// still feels responsive after a pause.
	private static let suggestionDebounce: Duration = .milliseconds(12)

	/// Schedule a suggestion refresh off the synchronous keystroke path.
	///
	/// `UITextChecker` is `@MainActor`-isolated in the SDK (`NS_SWIFT_UI_ACTOR`), so the compute can't run
	/// on a true background thread; instead it runs in a debounced, cancellable main-actor `Task` *after*
	/// the keystroke's text insertion and state update have already happened. The keystroke therefore
	/// returns instantly, and a fast typist's intermediate keystrokes cancel the pending compute before
	/// the expensive pipeline (including `UITextChecker`) ever runs (task 73, Phase C). The personal
	/// recents lookup is now thread-safe (Phase A) and could move off-main if a background spell-checker
	/// is ever adopted, but `UITextChecker` pins the merged pipeline to the main actor today.
	private func scheduleSuggestions() {
		guard let model = viewModel else { return }
		guard suggestionsActive else {
			// Not eligible / master toggle off → clear synchronously and drop any pending compute.
			suggestionTask?.cancel()
			suggestionTask = nil
			if !model.suggestions.isEmpty {
				model.suggestions = []
				refreshFavorites()
			}
			return
		}
		suggestionTask?.cancel()
		suggestionTask = Task { @MainActor [weak self] in
			try? await Task.sleep(for: Self.suggestionDebounce)
			guard let self, !Task.isCancelled else { return }
			self.computeAndApplySuggestions()
		}
	}

	/// Compute (or reuse memoized) suggestions for the current caret and push them into the model. Runs on
	/// the main actor (after the debounce) so it reads live proxy/state and `UITextChecker` stays isolated.
	private func computeAndApplySuggestions() {
		guard let model = viewModel, suggestionsActive else { return }
		let context = makeSuggestionContext()
		let suggestions: [Suggestion]
		if context == lastSuggestionContext {
			suggestions = lastSuggestions   // identical inputs → identical output, skip the pipeline
		} else {
			suggestions = Perf.measure("currentSuggestions") { runSuggestionPipeline(context: context) }
			lastSuggestionContext = context
			lastSuggestions = suggestions
		}
		guard suggestionsActive else { return }   // re-check: state may have changed during compute
		if model.suggestions != suggestions {
			model.suggestions = suggestions
			refreshFavorites()
		}
	}

	/// Drop the memoized suggestions. The memo keys only on `SuggestionContext` (document text, page,
	/// languages, eligibility), but the pipeline's *output* also depends on provider data that can change
	/// without the context moving — the recents pool (host removed/cleared a word, picked up by
	/// `reload()`) and the supplementary lexicon (delivered asynchronously). Call this whenever that
	/// provider data changes so the next compute recomputes instead of returning a stale list (task 73).
	private func invalidateSuggestionMemo() {
		lastSuggestionContext = nil
		lastSuggestions = []
	}

	/// Updates `favoritesDisplayOrder` — the order shown in the bar/panel — without ever reshuffling
	/// what the user is currently looking at:
	/// - When the favorites are **hidden** (or on the first seed), re-apply the full ordering, so
	///   `.frequency` picks up the latest usage counts the next time the favorites appear.
	/// - When they're **visible**, keep the frozen order and only reconcile membership: drop emojis
	///   that were just un-favorited and append newly-favorited ones at the end (a long-press toggle
	///   must still take effect, but existing items stay put).
	private func refreshFavoritesDisplayOrder(favoritesVisible: Bool) {
		// Reconcile against the entitlement-clamped list (`orderedFavorites()`), never the raw stored
		// favorites — otherwise the frozen-while-visible path could show more than the free limit: a
		// mid-session favorite toggle, or an entitlement downgrade that arrives while the bar/panel is
		// on screen, would otherwise append past the cap until the favorites were hidden and reseeded.
		let entitled = orderedFavorites()
		guard favoritesVisible, !favoritesDisplayOrder.isEmpty else {
			favoritesDisplayOrder = entitled
			return
		}
		let allowed = Set(entitled)
		var reconciled = favoritesDisplayOrder.filter { allowed.contains($0) }
		let present = Set(reconciled)
		for emoji in entitled where !present.contains(emoji) {
			reconciled.append(emoji)
		}
		favoritesDisplayOrder = reconciled
	}

	/// The favorites the bar should show, in display order, clamped to the user's entitlement. Free
	/// users see at most `FavoritesEntitlement.freeFavoritesLimit` favorites in `.manual` order (which
	/// also keeps the bar to a single page — frequency auto-sort and paging are Plus-only); Plus users
	/// get the full set in their chosen sort mode. The stored `favoriteEmojis` is never mutated here, so
	/// a Plus → free transition (e.g. entitlement still loading after reinstall) hides extras without
	/// losing them — they reappear once `isPlus` refreshes.
	private func orderedFavorites() -> [String] {
		FavoritesEntitlement.visibleFavorites(
			state.favoriteEmojis,
			counts: state.emojiUsageCounts,
			mode: state.favoritesSortMode,
			isPlus: state.effectiveIsPlus
		)
	}

	/// Whether word/Slack *suggestions* should be computed right now: master toggle on, the field allows
	/// display, and we're not on the emoji panel or an emoji-search page (so it applies on letters *and*
	/// symbols). This gates only suggestion *computation*, not whether the bar is shown. On an eligible
	/// field the bar always renders the favorites quick-access baseline regardless of the master toggle
	/// (see `KeyboardView.showsBarContent`), so when this is false the user still gets their favorites, just
	/// no word/Slack chips. (Secure fields hide the bar — but via `allowDisplay` / `fieldAllowsBar`, not
	/// this.) Content-only (task 61) — never drives height, so no host/view drift.
	private var suggestionsActive: Bool {
		guard state.suggestionsEnabled, state.currentEligibility.allowDisplay else { return false }
		return state.page != .emojis && !state.page.isEmojiSearch
	}

	/// Snapshot the document + state into a `SuggestionContext`. Reads the live proxy/state, so it must
	/// run on the main actor — the debounced suggestion task is main-isolated, so this stays accurate to
	/// the current caret (task 73, Phase C).
	private func makeSuggestionContext() -> SuggestionContext {
		// Single completion language, resolved by the accent set's chain: its own language → the
		// device language → English (task 78, ADR 0002). iOS never reveals the field's or device's
		// language to a custom keyboard, so the static "mul" `PrimaryLanguage` (`state.currentLanguage`)
		// no longer feeds completions — it would only ever resolve to English and crowd out an accent
		// user's bar. Kept as a single-element `[String]` because `WordCompletionProvider` still merges
		// a multi-language list (retained for future flexibility).
		let completionLanguages = [state.letterAlternateSet.completionLanguage()]
		return SuggestionContext(
			documentContextBeforeInput: textDocumentProxy.documentContextBeforeInput,
			documentContextAfterInput: textDocumentProxy.documentContextAfterInput,
			page: state.page,
			completionLanguages: completionLanguages,
			eligibility: state.currentEligibility
		)
	}

	/// Run the coordinator over `context`. Slack shortcodes win wholesale when present (pill chips);
	/// otherwise word completions are merged from recents + `UITextChecker` + `UILexicon`. Providers are
	/// cheap value types, rebuilt per call so they always see fresh state.
	private func runSuggestionPipeline(context: SuggestionContext) -> [Suggestion] {
		let coordinator = SuggestionCoordinator(providers: [
			SlackSuggestionProvider(),
			WordCompletionProvider(
				textChecker: UITextCheckerAdapter(textChecker),
				systemLexicon: UILexiconAdapter(entries: lexiconEntries),
				recents: recentsStore
			),
			// After word completion: the quick-pick stays silent whenever a prefix is active, so the
			// two never compete — order only fixes a deterministic tie that can't occur in practice.
			EmailQuickPickProvider(recents: recentsStore)
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
		Perf.measure("handle") {
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
			// Re-evaluate auto-cap after the actions that can leave a fresh sentence trigger in the
			// document. `textDidChange` is *not* reliable for this: it fires synchronously *during*
			// `insertText`, so it can read a `documentContextBeforeInput` that doesn't yet include the
			// space/character just inserted (e.g. it sees `Hello.` not `Hello. `) and skip the promotion.
			// So we re-run here, after dispatch returns, when the proxy context is settled (task 85, Part A):
			//   • `.switchPage` — the document may already carry a pending auto-cap (e.g. `? ` typed on
			//     symbols, then ABC) that `textDidChange` won't surface.
			//   • `.space` / `.insertText` / `.insertRawText` — re-run **regardless of any page change**.
			//     A sentence terminator typed via a key that doesn't switch pages — the dedicated `.` dot
			//     key on the letter page, or the `". "` double-tap substitution — leaves the page on
			//     letters, so the old page-change guard never fired and the period never capitalized while
			//     `?`/`!` (which hop symbols → letters) did. Idempotent, so safe on every text action.
			//   • `.suggestionAccept` — does the same implicit symbols → letters hop (task 74, Fáze B).
			// `.shift` is deliberately excluded: re-running would immediately override a manual lowercase
			// override at sentence start (Instagram message field, etc.).
			switch key.action {
			case .switchPage, .space, .insertText, .insertRawText:
				refreshAutoCapitalization()
			case .suggestionAccept where pageBefore != state.page:
				refreshAutoCapitalization()
			default:
				break
			}
			rebuild()
		}
	}

	private func refreshReturnKeyType() {
		let rawType = textDocumentProxy.returnKeyType ?? .default
		let newType = ReturnKeyTypeMapping.map(rawType)
		if state.returnKeyType != newType {
			state.returnKeyType = newType
			rebuild()
		}
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
		// The page flip (and the numeric-page guard) lives in `AutoCapitalizer.applyAutoCapitalization`
		// so it's testable without a real text proxy; here we just feed it the live proxy reads and the
		// master toggle (`state.autoCapitalizationEnabled`, task 85) and rebuild when the page changed.
		let rawType = textDocumentProxy.autocapitalizationType ?? .sentences
		let autoCapType = AutocapitalizationTypeMapping.map(rawType)
		let changed = AutoCapitalizer.applyAutoCapitalization(
			to: &state,
			documentContextBeforeInput: textDocumentProxy.documentContextBeforeInput,
			autocapitalizationType: autoCapType,
			enabled: state.autoCapitalizationEnabled
		)
		if changed { rebuild() }
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
