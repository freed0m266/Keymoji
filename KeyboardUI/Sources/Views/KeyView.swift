import SwiftUI
import KeyboardCore

/// Renders a single keyboard key. Handles pressed-state visual feedback, tap dispatch,
/// and the long-press popover that exposes diacritic / shifted-symbol alternates.
struct KeyView: View {
	let key: Key
	let style: KeyStyle
	let returnKeyType: ReturnKeyType
	let keyWidth: CGFloat
	/// Fixed visible cap height (the coloured rectangle). The total row slot is `capHeight + rowGap`;
	/// the gap is added as `rowGap/2` vertical padding *inside* the hit area below.
	let capHeight: CGFloat
	/// Extra tappable / filled space owned by this key on its leading / trailing side, in points.
	/// The visible cap stays `keyWidth` wide and is pushed away from the gap; the gap area still
	/// carries this key's background and hit-testing (e.g. the symbols toggle / delete edge gaps).
	let leadingGapWidth: CGFloat
	let trailingGapWidth: CGFloat
	let popoverAlignment: HorizontalAlignment
	let onTap: (Key) -> Void
	let onKeyTapHaptic: () -> Void
	let onKeyClick: (ClickSoundKind) -> Void
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
	/// Last drag location (in KeyView coords) at which we emitted a horizontal cursor offset. Each
	/// character of horizontal motion past this anchor emits a one-character offset and advances it.
	@State private var trackpadAnchorX: CGFloat = 0
	/// Vertical counterpart of `trackpadAnchorX` (task 69): each `trackpadPointsPerLine` of vertical
	/// motion past this anchor emits a one-line cursor offset and advances the anchor.
	@State private var trackpadAnchorY: CGFloat = 0
	/// True once the user has slid a finger far enough below the open popover to cancel it (task 69).
	/// Sticky until release: the popover stays hidden and touch-up commits nothing.
	@State private var isCancelArmed = false
	/// Finger Y (in KeyView coords) captured the first frame the popover is on screen — the reference
	/// the downward cancel drag is measured against. Anchoring here (not at touch-down, ~350ms earlier)
	/// means downward drift *during* the long-press hold doesn't pre-spend the cancel budget, and "drag
	/// down from where the accents appeared" is literally true. `nil` until captured; reset each press.
	@State private var popoverDragAnchorY: CGFloat?

	/// 350ms — parity with Apple's long-press delay, so alternates pop as fast as the stock keyboard.
	private static let longPressDelay: Duration = .milliseconds(350)
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
	/// Minimum drag radius (in points, either axis) once armed before trackpad mode engages. Keeps a
	/// stationary long-press from accidentally swallowing a regular `.space` tap.
	private static let trackpadActivationDistance: CGFloat = 6
	/// How many points of horizontal drag equal one character of cursor movement. Lowered from 10 to
	/// 6 (task 69 beta feedback — 10 pt/char felt sluggish, needing big strokes for small moves).
	private static let trackpadPointsPerCharacter: CGFloat = 6
	/// How many points of vertical drag equal one line of cursor movement (task 69). Coarser than the
	/// horizontal step — a line jump is a bigger, more deliberate motion than nudging by a character.
	private static let trackpadPointsPerLine: CGFloat = 22

	private static let popoverCellSize = CGSize(width: 40, height: 44)
	private static let popoverCellSpacing: CGFloat = 2
	private static let popoverHorizontalPadding: CGFloat = 4
	/// How far *down* (from where the finger was when the popover appeared) the user must drag to
	/// cancel the popover (task 69). Only a deliberate downward slide off the key arms the cancel —
	/// moving sideways to pick an accent or up onto the popover never trips it. Generous on purpose:
	/// the cap is only 42 pt tall, so a smaller value would fire while the finger is still picking an
	/// accent near the key. ~1.3 key heights down — below the cap but short of the next row's letters.
	private static let popoverCancelDistance: CGFloat = 56

	init(
		key: Key,
		style: KeyStyle,
		returnKeyType: ReturnKeyType,
		keyWidth: CGFloat = 0,
		capHeight: CGFloat = KeyboardMetrics.keyCapHeight,
		leadingGapWidth: CGFloat = 0,
		trailingGapWidth: CGFloat = 0,
		popoverAlignment: HorizontalAlignment = .center,
		onTap: @escaping (Key) -> Void,
		onKeyTapHaptic: @escaping () -> Void = {},
		onKeyClick: @escaping (ClickSoundKind) -> Void = { _ in },
		onPopoverEntry: @escaping () -> Void = {},
		onHighlightChanged: @escaping () -> Void = {},
		canEscalateBackspace: (() -> Bool)? = nil,
		onTrackpadModeChanged: @escaping (Bool) -> Void = { _ in }
	) {
		self.key = key
		self.style = style
		self.returnKeyType = returnKeyType
		self.keyWidth = keyWidth
		self.capHeight = capHeight
		self.leadingGapWidth = leadingGapWidth
		self.trailingGapWidth = trailingGapWidth
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
		// Fixed visible cap height — keys no longer float to fill leftover space, so letters and
		// symbols stay the same height regardless of the suggestion bar (task 52).
		.frame(height: capHeight)
		.padding(.horizontal, 3)
		// Half the row gap on each side: the inter-row gap lives *inside* this key's hit area, so a
		// tap landing between two rows still dispatches the nearer key (task 42 — must not break).
		.padding(.vertical, KeyboardMetrics.rowGap / 2)
		// Edge gaps are padded in here — *before* the background and hit shape — so the cap stays
		// `keyWidth` wide and pushed away from the gap, while the gap area inherits this key's
		// background fill and tap target. A tap in the gap therefore dispatches this key's action.
		.padding(.leading, leadingGapWidth)
		.padding(.trailing, trailingGapWidth)
		.background {
			Color.black.opacity(0.001)
		}
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
					handlePopoverDrag(at: value.location)
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
		didRepeatBackspace = false
		isWordDeleting = false
		isCancelArmed = false
		// Normalize popover state at the start of every press so a fresh touch is authoritative,
		// regardless of how the previous gesture ended (defense-in-depth — today only the commit path
		// clears `isShowingPopover`).
		isShowingPopover = false
		popoverDragAnchorY = nil
		isTrackpadArmed = false
		isTrackpadActive = false
		trackpadAnchorX = location.x
		trackpadAnchorY = location.y

		// Fire the "key tap" haptic + click at touch-down (matches Apple/SwiftKey feel — feedback
		// when the finger lands, not when it lifts). Fires on every key except continuous trackpad
		// scrubbing, which emits cursor-offset events 60×/s and would drown the user in vibration.
		if firesKeyTapFeedback {
			onKeyTapHaptic()
			onKeyClick(clickSoundKind)
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
		case .cursorOffset, .cursorLineOffset:
			return false
		}
	}

	/// Maps this key's action onto the native click flavor to play (task 46): space gets the deeper
	/// modifier click, delete (incl. word-delete repeat, which keeps this key's `.backspace` action)
	/// gets the delete click, everything else keeps the standard character click.
	private var clickSoundKind: ClickSoundKind {
		switch key.action {
		case .space:                  return .space
		case .backspace, .deleteWord: return .delete
		default:                      return .character
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

		if isCancelArmed {
			// The user slid down out of the popover to bail out (task 69). Silently consume the
			// gesture — no alternate, no base letter, nothing typed.
		} else if isShowingPopover {
			commitAlternate(at: highlightedAlternateIndex)
			isShowingPopover = false
		} else if didRepeatBackspace || wasTrackpadActive {
			// First action already fired during the hold — don't double-fire here. For trackpad,
			// suppressing the trailing `.space` tap matches Apple stock behavior.
		} else {
			onTap(key)
		}
		didRepeatBackspace = false
		isWordDeleting = false
		isCancelArmed = false
		popoverDragAnchorY = nil
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
			// silently swallowing the upcoming `.space` tap. Either axis counts now (task 69 made
			// scrubbing 2D), so the dead zone is a radius, not an x-only threshold.
			let dx = location.x - trackpadAnchorX
			let dy = location.y - trackpadAnchorY
			guard hypot(dx, dy) >= Self.trackpadActivationDistance else { return }
			isTrackpadActive = true
			// Treat the activation distance as a dead zone on the dominant axis: anchor at the
			// crossing point, not at the current location, so any drag past the threshold
			// immediately counts toward the first offset. Quick fling-and-release would otherwise
			// move nothing because the first `onChanged` after arming often jumps several dozen
			// points past the threshold in a single frame.
			if abs(dx) >= abs(dy) {
				trackpadAnchorX += (dx > 0 ? 1 : -1) * Self.trackpadActivationDistance
			} else {
				trackpadAnchorY += (dy > 0 ? 1 : -1) * Self.trackpadActivationDistance
			}
			onTrackpadModeChanged(true)
			// Fall through to emit any remaining offset from this same frame.
		}

		// Per-frame dominant axis (task 69): whichever of |dx| / |dy| is larger decides what this
		// frame emits. Each axis anchors independently and carries its remainder across frames, so a
		// long slow drag stays accurate (no rounding drift) and a diagonal resolves cleanly.
		let dx = location.x - trackpadAnchorX
		let dy = location.y - trackpadAnchorY

		if abs(dx) >= abs(dy) {
			// Horizontal: one cursor-offset per `trackpadPointsPerCharacter` crossed since the anchor.
			let charsRaw = (dx / Self.trackpadPointsPerCharacter).rounded(.towardZero)
			guard charsRaw != 0 else { return }
			let chars = Int(charsRaw)
			emitCursorOffset(chars)
			trackpadAnchorX += CGFloat(chars) * Self.trackpadPointsPerCharacter
		} else {
			// Vertical: one line-offset per `trackpadPointsPerLine` crossed since the anchor.
			let linesRaw = (dy / Self.trackpadPointsPerLine).rounded(.towardZero)
			guard linesRaw != 0 else { return }
			let lines = Int(linesRaw)
			emitCursorLineOffset(lines)
			trackpadAnchorY += CGFloat(lines) * Self.trackpadPointsPerLine
		}
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

	private func emitCursorLineOffset(_ lines: Int) {
		let synthesized = Key(
			id: "\(key.id).trackpadLine",
			primary: key.primary,
			alternates: [],
			action: .cursorLineOffset(lines),
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
		onKeyClick(.delete)
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
		onKeyClick(.delete)
	}

	private func startLongPressTimer() {
		longPressTask?.cancel()
		longPressTask = Task { @MainActor in
			try? await Task.sleep(for: Self.longPressDelay)
			guard !Task.isCancelled, isPressed else { return }

			// Every key with ≥1 alternate now shows the popover, even a single-alternate one (task 69
			// dropped the auto-commit shortcut). The first alt is highlighted from frame 0, so a
			// hold + release with no slide commits it.
			highlightedAlternateIndex = 0
			isShowingPopover = true
			onPopoverEntry()
		}
	}

	// MARK: - Highlight tracking

	/// Drives the popover while a finger is held down on it. A deliberate *downward* drag off the key
	/// cancels the long-press (task 69) — matching iOS native, which lets you bail out by sliding down.
	/// Otherwise the horizontal position just retargets the highlighted alternate.
	///
	/// Cancel keys off how far the finger has moved *down* from where it was when the popover appeared
	/// (`popoverDragAnchorY`), not the finger's absolute Y. That's what fixes the original bug: the cap
	/// is only 42 pt tall, so an absolute threshold sat *inside* the key and fired the moment the finger
	/// drifted into its lower half while reaching sideways for an accent. Sideways / upward motion keeps
	/// the downward delta at / below zero, so it can never cancel now.
	private func handlePopoverDrag(at location: CGPoint) {
		guard let anchorY = popoverDragAnchorY else {
			// First frame the popover is on screen: anchor here, just retarget — never cancel yet.
			popoverDragAnchorY = location.y
			updateHighlight(from: location)
			return
		}
		if Self.shouldArmPopoverCancel(draggedDown: location.y - anchorY) {
			isCancelArmed = true
			isShowingPopover = false
			return
		}
		updateHighlight(from: location)
	}

	/// Whether a downward drag of `draggedDown` points (positive = down) from the popover anchor is a
	/// deliberate-enough slide to cancel the long-press. Pure + `static` so it's unit-testable without
	/// a live gesture — the threshold/coordinate math is exactly what silently re-breaks otherwise.
	static func shouldArmPopoverCancel(draggedDown: CGFloat) -> Bool {
		draggedDown > popoverCancelDistance
	}

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
		case .search, .google, .yahoo:       return .symbol(.search)
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
		case .cursorLineOffset:       return "Move cursor by line"
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
		.frame(width: keyWidth, height: KeyboardMetrics.keyCapHeight + KeyboardMetrics.rowGap)
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
