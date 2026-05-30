import SwiftUI
import KeyboardCore

/// Renders a single keyboard key. Handles pressed-state visual feedback, tap dispatch,
/// and the long-press popover that exposes diacritic / shifted-symbol alternates.
struct KeyView: View {
	let key: Key
	let style: KeyStyle
	let returnKeyType: ReturnKeyType
	let keyWidth: CGFloat
	let popoverAlignment: HorizontalAlignment
	let onTap: (Key) -> Void
	let onKeyTapHaptic: () -> Void
	let onKeyClick: () -> Void
	let onPopoverEntry: () -> Void
	let onHighlightChanged: () -> Void
	/// Returns true iff the document proxy currently exposes enough context for a
	/// word-by-word delete to compute boundaries. When the closure is absent (previews,
	/// snapshot tests) escalation is allowed unconditionally.
	let canEscalateBackspace: (() -> Bool)?
	/// Fired when a long-press on the space key escalates into trackpad-mode cursor scrubbing.
	/// `true` on entry, `false` on release. Parents drive the keyboard-wide fade overlay
	/// and the entry haptic from this callback.
	let onTrackpadModeChanged: (Bool) -> Void

	@State private var isPressed = false
	@State private var isShowingPopover = false
	@State private var highlightedAlternateIndex = 0
	@State private var didCommitAlternate = false
	@State private var didRepeatBackspace = false
	@State private var isWordDeleting = false
	@State private var longPressTask: Task<Void, Never>?
	@State private var backspaceRepeatTask: Task<Void, Never>?
	@State private var trackpadArmTask: Task<Void, Never>?
	/// True once the press has been held long enough to arm trackpad mode. Drag motion past the
	/// activation threshold from here on will enter trackpad mode. Reset on touch up.
	@State private var isTrackpadArmed = false
	/// True once trackpad mode has actually engaged (armed + crossed activation drag distance).
	/// While true, drags emit `.cursorOffset` keys instead of triggering the normal `.space` tap.
	@State private var isTrackpadActive = false
	/// Last drag location (in KeyView coords) at which we emitted a cursor offset. Each character
	/// of horizontal motion past this anchor emits a one-character offset and advances the anchor.
	@State private var trackpadAnchorX: CGFloat = 0

	/// 450ms — slightly more generous than Apple's ~350ms, kinder to slow thumbs.
	private static let longPressDelay: Duration = .milliseconds(450)
	/// Initial delay before delete-on-hold starts firing.
	private static let backspaceInitialDelay: Duration = .milliseconds(400)
	/// Repeat interval once delete-on-hold is firing.
	private static let backspaceRepeatInterval: Duration = .milliseconds(80)
	/// Elapsed char-repeat time after which delete-on-hold escalates to word-by-word.
	/// Matches Apple's behavior of switching from per-character to per-word delete after ~2 s.
	private static let backspaceWordModeDelay: Duration = .milliseconds(2000)
	/// Repeat interval once word-delete mode is active. Slower than char repeat — each pulse
	/// chews through a whole word, so we want the user to be able to release in time.
	private static let backspaceWordRepeatInterval: Duration = .milliseconds(220)
	/// Hold duration on space before trackpad mode is *armed*. After this elapses the user only
	/// needs to drag a few points to actually engage the trackpad.
	private static let trackpadArmDelay: Duration = .milliseconds(300)
	/// Minimum horizontal drag (in points) once armed before trackpad mode engages. Keeps a
	/// stationary long-press from accidentally swallowing a regular `.space` tap.
	private static let trackpadActivationDistance: CGFloat = 6
	/// How many points of horizontal drag equal one character of cursor movement. Tuned to match
	/// the feel of Apple's stock trackpad — comfortable on iPhone portrait without over-shooting.
	private static let trackpadPointsPerCharacter: CGFloat = 10

	private static let popoverCellSize = CGSize(width: 40, height: 44)
	private static let popoverCellSpacing: CGFloat = 2
	private static let popoverHorizontalPadding: CGFloat = 4

	init(
		key: Key,
		style: KeyStyle,
		returnKeyType: ReturnKeyType,
		keyWidth: CGFloat = 0,
		popoverAlignment: HorizontalAlignment = .center,
		onTap: @escaping (Key) -> Void,
		onKeyTapHaptic: @escaping () -> Void = {},
		onKeyClick: @escaping () -> Void = {},
		onPopoverEntry: @escaping () -> Void = {},
		onHighlightChanged: @escaping () -> Void = {},
		canEscalateBackspace: (() -> Bool)? = nil,
		onTrackpadModeChanged: @escaping (Bool) -> Void = { _ in }
	) {
		self.key = key
		self.style = style
		self.returnKeyType = returnKeyType
		self.keyWidth = keyWidth
		self.popoverAlignment = popoverAlignment
		self.onTap = onTap
		self.onKeyTapHaptic = onKeyTapHaptic
		self.onKeyClick = onKeyClick
		self.onPopoverEntry = onPopoverEntry
		self.onHighlightChanged = onHighlightChanged
		self.canEscalateBackspace = canEscalateBackspace
		self.onTrackpadModeChanged = onTrackpadModeChanged
	}

	var body: some View {
		ZStack {
			RoundedRectangle(cornerRadius: style.cornerRadius)
				.fill(keyBackgroundColor)

			content
				.foregroundStyle(style.foregroundColor)
				.font(contentFont)
				.minimumScaleFactor(0.6)
				.lineLimit(1)
				.padding(.horizontal, 4)
		}
		.frame(minHeight: 36)
		.contentShape(Rectangle())
		.overlay(alignment: popoverOverlayAlignment) {
			if isShowingPopover, hasTextAlternates {
				LongPressPopoverView(
					alternates: key.alternates,
					highlightedIndex: highlightedAlternateIndex,
					cellSize: Self.popoverCellSize
				)
				.offset(y: -Self.popoverCellSize.height - 12)
				.zIndex(1000)
				.allowsHitTesting(false)
			}
		}
		.gesture(combinedGesture)
		.accessibilityElement()
		.accessibilityLabel(accessibilityLabel)
		.accessibilityAddTraits(.isKeyboardKey)
	}

	private var combinedGesture: some Gesture {
		DragGesture(minimumDistance: 0)
			.onChanged { value in
				if !isPressed {
					handleTouchDown(at: value.location)
				}
				if isShowingPopover {
					updateHighlight(from: value.location)
				}
				if isSpaceKey {
					handleSpaceDrag(at: value.location)
				}
			}
			.onEnded { _ in
				handleTouchUp()
			}
	}

	private var isSpaceKey: Bool {
		if case .space = key.action { return true }
		return false
	}

	// MARK: - Gesture lifecycle

	private func handleTouchDown(at location: CGPoint) {
		isPressed = true
		didCommitAlternate = false
		didRepeatBackspace = false
		isWordDeleting = false
		isTrackpadArmed = false
		isTrackpadActive = false
		trackpadAnchorX = location.x

		// Fire the "key tap" haptic + click at touch-down (matches Apple/SwiftKey feel — feedback
		// when the finger lands, not when it lifts). Fires on every key except continuous trackpad
		// scrubbing, which emits cursor-offset events 60×/s and would drown the user in vibration.
		if firesKeyTapFeedback {
			onKeyTapHaptic()
			onKeyClick()
		}

		if case .backspace = key.action {
			startBackspaceRepeat()
		} else if isSpaceKey {
			startTrackpadArmTimer()
		} else if hasTextAlternates {
			startLongPressTimer()
		}
	}

	/// True for every key action except continuous trackpad scrubbing. Each `.cursorOffset` is
	/// emitted per-character of finger drag — firing haptics there would buzz dozens of times per
	/// second. The trackpad-mode entry itself has its own dedicated "thunk" haptic upstream.
	private var firesKeyTapFeedback: Bool {
		switch key.action {
		case .insertText, .insertRawText, .backspace, .deleteWord, .space, .return,
		     .shift, .switchPage, .dismissKeyboard, .suggestionAccept:
			return true
		case .cursorOffset:
			return false
		}
	}

	/// Background tint for the key. Word-delete mode replaces the normal pressed grey with a
	/// muted orange — the visual cue that mode escalated, matching stock iOS.
	private var keyBackgroundColor: Color {
		if isWordDeleting { return Color.orange.opacity(0.6) }
		return isPressed ? style.pressedBackgroundColor : style.backgroundColor
	}

	private func handleTouchUp() {
		isPressed = false
		longPressTask?.cancel()
		longPressTask = nil
		backspaceRepeatTask?.cancel()
		backspaceRepeatTask = nil
		trackpadArmTask?.cancel()
		trackpadArmTask = nil

		let wasTrackpadActive = isTrackpadActive
		if wasTrackpadActive {
			onTrackpadModeChanged(false)
		}
		isTrackpadArmed = false
		isTrackpadActive = false

		if isShowingPopover {
			commitAlternate(at: highlightedAlternateIndex)
			isShowingPopover = false
		} else if didCommitAlternate || didRepeatBackspace || wasTrackpadActive {
			// First action already fired during the hold — don't double-fire here. For trackpad,
			// suppressing the trailing `.space` tap matches Apple stock behavior.
		} else {
			onTap(key)
		}
		didCommitAlternate = false
		didRepeatBackspace = false
		isWordDeleting = false
	}

	// MARK: - Trackpad mode (long-press space)

	/// After `trackpadArmDelay` of pressing space, mark trackpad as armed. From there the next
	/// horizontal drag past `trackpadActivationDistance` will engage it. Mirrors stock iOS: a
	/// stationary hold doesn't yet swallow the space tap — the drag is what commits to trackpad.
	private func startTrackpadArmTimer() {
		trackpadArmTask?.cancel()
		trackpadArmTask = Task { @MainActor in
			try? await Task.sleep(for: Self.trackpadArmDelay)
			guard !Task.isCancelled, isPressed else { return }
			isTrackpadArmed = true
		}
	}

	private func handleSpaceDrag(at location: CGPoint) {
		guard isTrackpadArmed else { return }

		if !isTrackpadActive {
			// Wait for the activation drag before engaging — keeps stationary long-press from
			// silently swallowing the upcoming `.space` tap.
			let drag = location.x - trackpadAnchorX
			guard abs(drag) >= Self.trackpadActivationDistance else { return }
			isTrackpadActive = true
			// Treat the activation distance as a dead zone: anchor at the activation crossing
			// point, not at the current location, so any drag past the threshold immediately
			// counts toward the first cursor offset. Quick fling-and-release would otherwise
			// move nothing because the first `onChanged` after arming often jumps several
			// dozen points past the threshold in a single frame.
			let direction: CGFloat = drag > 0 ? 1 : -1
			trackpadAnchorX += direction * Self.trackpadActivationDistance
			onTrackpadModeChanged(true)
			// Fall through to emit any remaining offset from this same frame.
		}

		// Stage 1: horizontal only. Emit one cursor-offset key per `trackpadPointsPerCharacter`
		// crossed since the last anchor, then advance the anchor by that many points. Carrying the
		// remainder across frames keeps long slow drags accurate (no rounding drift).
		let dx = location.x - trackpadAnchorX
		let charsRaw = (dx / Self.trackpadPointsPerCharacter).rounded(.towardZero)
		guard charsRaw != 0 else { return }
		let chars = Int(charsRaw)
		emitCursorOffset(chars)
		trackpadAnchorX += CGFloat(chars) * Self.trackpadPointsPerCharacter
	}

	private func emitCursorOffset(_ offset: Int) {
		let synthesized = Key(
			id: "\(key.id).trackpad",
			primary: key.primary,
			alternates: [],
			action: .cursorOffset(offset),
			visualWeight: key.visualWeight,
			role: key.role
		)
		onTap(synthesized)
	}

	/// Delete-on-hold: after the initial delay, fire the first repeat backspace, then keep
	/// firing on the repeat interval until touch up. `Task.isCancelled` checks after each sleep
	/// guarantee we don't fire one extra backspace past the user releasing the key.
	/// A haptic + click accompanies each repeat fire — the initial touch-down already fired one.
	///
	/// After ~2 s of char-by-char repeat, escalates to word-by-word delete at a slower cadence
	/// (matches Apple). Each word pulse synthesizes a `.deleteWord` key so the dispatcher can
	/// consume one trailing word in a single round-trip.
	private func startBackspaceRepeat() {
		backspaceRepeatTask?.cancel()
		backspaceRepeatTask = Task { @MainActor in
			try? await Task.sleep(for: Self.backspaceInitialDelay)
			guard !Task.isCancelled, isPressed else { return }

			didRepeatBackspace = true
			fireBackspaceRepeat()

			let repeatStart = ContinuousClock.now
			while !Task.isCancelled, isPressed {
				try? await Task.sleep(for: Self.backspaceRepeatInterval)
				guard !Task.isCancelled, isPressed else { return }
				if repeatStart.duration(to: .now) >= Self.backspaceWordModeDelay { break }
				fireBackspaceRepeat()
			}

			guard !Task.isCancelled, isPressed else { return }

			// Hidden contexts (password fields, etc.) hide `documentContextBeforeInput`, so
			// the dispatcher can't compute word boundaries. Escalating there would slow the
			// delete cadence from 80 ms to 220 ms with zero boundary benefit — stay in char
			// repeat instead. If the callback isn't wired, default to escalating.
			let canEscalate = canEscalateBackspace?() ?? true
			if !canEscalate {
				while !Task.isCancelled, isPressed {
					fireBackspaceRepeat()
					try? await Task.sleep(for: Self.backspaceRepeatInterval)
					guard !Task.isCancelled, isPressed else { return }
				}
				return
			}

			isWordDeleting = true
			while !Task.isCancelled, isPressed {
				fireWordDeleteRepeat()
				try? await Task.sleep(for: Self.backspaceWordRepeatInterval)
				guard !Task.isCancelled, isPressed else { return }
			}
		}
	}

	private func fireBackspaceRepeat() {
		onTap(key)
		onKeyTapHaptic()
		onKeyClick()
	}

	private func fireWordDeleteRepeat() {
		let synthesized = Key(
			id: "\(key.id).word",
			primary: key.primary,
			alternates: [],
			action: .deleteWord,
			visualWeight: key.visualWeight,
			role: key.role
		)
		onTap(synthesized)
		onKeyTapHaptic()
		onKeyClick()
	}

	private func startLongPressTimer() {
		longPressTask?.cancel()
		longPressTask = Task { @MainActor in
			try? await Task.sleep(for: Self.longPressDelay)
			guard !Task.isCancelled, isPressed else { return }

			if key.alternates.count == 1 {
				// Single-alternate shortcut: commit immediately, no popover.
				commitAlternate(at: 0)
				didCommitAlternate = true
				onPopoverEntry()
			} else {
				highlightedAlternateIndex = 0
				isShowingPopover = true
				onPopoverEntry()
			}
		}
	}

	// MARK: - Highlight tracking

	private func updateHighlight(from location: CGPoint) {
		// `location` is in KeyView coords. The popover sits above the key — its leading-edge X
		// (relative to the KeyView's origin at 0) depends on the alignment and the actual rendered key width.
		let alternateCount = key.alternates.count
		guard alternateCount > 1 else { return }

		let cellPitch = Self.popoverCellSize.width + Self.popoverCellSpacing
		let popoverWidth = CGFloat(alternateCount) * cellPitch - Self.popoverCellSpacing + Self.popoverHorizontalPadding * 2
		let originX = popoverOriginX(popoverWidth: popoverWidth)
		let relativeX = location.x - originX - Self.popoverHorizontalPadding

		let rawIndex = Int(relativeX / cellPitch)
		let clamped = max(0, min(alternateCount - 1, rawIndex))
		if clamped != highlightedAlternateIndex {
			highlightedAlternateIndex = clamped
			onHighlightChanged()
		}
	}

	/// X coordinate of the popover's leading edge, relative to this KeyView's origin (x = 0 at leading edge).
	/// Mirrors the SwiftUI `.overlay(alignment:)` math we use to position the popover overlay.
	private func popoverOriginX(popoverWidth: CGFloat) -> CGFloat {
		switch popoverAlignment {
		case .leading:  return 0
		case .trailing: return -(popoverWidth - keyWidth)
		default:        return -(popoverWidth - keyWidth) / 2
		}
	}

	private var popoverOverlayAlignment: Alignment {
		switch popoverAlignment {
		case .leading:  return .topLeading
		case .trailing: return .topTrailing
		default:        return .top
		}
	}

	// MARK: - Commit

	private func commitAlternate(at index: Int) {
		guard index < key.alternates.count else { return }
		let altContent = key.alternates[index]
		guard case .text(let altText) = altContent else { return }

		let synthesized = Key(
			id: "\(key.id).alt.\(index)",
			primary: altContent,
			alternates: [],
			action: .insertRawText(altText),
			visualWeight: key.visualWeight,
			role: key.role
		)
		onTap(synthesized)
	}

	// MARK: - Content / accessibility

	private var hasTextAlternates: Bool {
		!key.alternates.isEmpty && key.alternates.contains { if case .text = $0 { return true } else { return false } }
	}

	@ViewBuilder
	private var content: some View {
		switch effectiveContent {
		case .text(let text):
			Text(text)
				.offset(y: isLowercaseLetter(text) ? -2 : 0)
		case .symbol(let symbol):
			Image(systemName: symbol.systemName)
		}
	}

	/// Symbol glyphs (shift / delete / smiley / return) render at a fixed visual size that
	/// matches Apple's stock keyboard — bigger than the small semibold text labels (123 / ABC /
	/// Search) the function and system tiers use for their text. Without this override the
	/// glyphs would inherit `style.font` and shrink to 17pt alongside the labels.
	private var contentFont: Font? {
		switch effectiveContent {
		case .symbol: return .system(size: 20, weight: .regular)
		case .text:   return style.font
		}
	}

	/// The label shown on the key cap. For the return key, the layout's `returnKeyType` overrides
	/// the model's symbol to give an adaptive label (`Go`, `Search`, `Send`, …).
	private var effectiveContent: KeyContent {
		if case .return = key.action {
			return returnKeyLabel(for: returnKeyType)
		}
		return key.primary
	}

	private func returnKeyLabel(for type: ReturnKeyType) -> KeyContent {
		switch type {
		case .default:                       return .symbol(.return)
		case .go:                             return .text("Go")
		case .search, .google, .yahoo:       return .text("Search")
		case .send:                           return .text("Send")
		case .done:                           return .text("Done")
		case .next:                           return .text("Next")
		case .join:                           return .text("Join")
		case .continue:                       return .text("Continue")
		case .route:                          return .text("Route")
		case .emergencyCall:                  return .text("Call")
		}
	}

	private var accessibilityLabel: String {
		switch key.action {
		case .insertText(let s):     return s
		case .insertRawText(let s):  return s
		case .backspace:              return "Delete"
		case .deleteWord:             return "Delete word"
		case .shift:                  return "Shift"
		case .space:                  return "Space"
		case .return:                 return "Return"
		case .dismissKeyboard:        return "Dismiss keyboard"
		case .switchPage:             return "Switch keyboard layout"
		case .cursorOffset:           return "Move cursor"
		case .suggestionAccept(let displayText, _): return displayText
		}
	}

	private func isLowercaseLetter(_ string: String) -> Bool {
		string.count == 1 && string.first?.isLowercase == true
	}
}

#if DEBUG
private struct KeyViewPreview: View {
	let key: Key
	let page: KeyboardPage
	let returnKeyType: ReturnKeyType
	let keyWidth: CGFloat

	var body: some View {
		KeyView(
			key: key,
			style: KeyStyle.style(for: key, page: page),
			returnKeyType: returnKeyType,
			keyWidth: keyWidth,
			onTap: { _ in }
		)
		.frame(width: keyWidth, height: 44)
		.padding(40)
		.background(Color(.systemBackground))
	}
}

#Preview("Letter with alternates / Dark") {
	KeyViewPreview(
		key: Key(
			id: "preview.e",
			primary: .text("e"),
			alternates: [.text("é"), .text("ě"), .text("è"), .text("ê"), .text("ë"), .text("ē"), .text("ė"), .text("ę")],
			action: .insertText("e"),
			visualWeight: .standard,
			role: .character
		),
		page: .letters(.lower),
		returnKeyType: .default,
		keyWidth: 36
	)
	.preferredColorScheme(.dark)
}

#Preview("Shift (active) / Dark") {
	KeyViewPreview(
		key: Key(
			id: "shift",
			primary: .symbol(.shiftFill),
			alternates: [],
			action: .shift,
			visualWeight: .wide,
			role: .system
		),
		page: .letters(.upper),
		returnKeyType: .default,
		keyWidth: 54
	)
	.preferredColorScheme(.dark)
}

#Preview("Delete / Dark") {
	KeyViewPreview(
		key: Key(
			id: "delete",
			primary: .symbol(.delete),
			alternates: [],
			action: .backspace,
			visualWeight: .wide,
			role: .system
		),
		page: .letters(.lower),
		returnKeyType: .default,
		keyWidth: 54
	)
	.preferredColorScheme(.dark)
}

#Preview("Return = Search / Light") {
	KeyViewPreview(
		key: Key(
			id: "return",
			primary: .symbol(.return),
			alternates: [],
			action: .return,
			visualWeight: .returnKey,
			role: .system
		),
		page: .letters(.lower),
		returnKeyType: .search,
		keyWidth: 84
	)
	.preferredColorScheme(.light)
}
#endif
