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
	let onPopoverEntry: () -> Void
	let onHighlightChanged: () -> Void

	@State private var isPressed = false
	@State private var isShowingPopover = false
	@State private var highlightedAlternateIndex = 0
	@State private var didCommitAlternate = false
	@State private var longPressTask: Task<Void, Never>?

	/// 450ms — slightly more generous than Apple's ~350ms, kinder to slow thumbs.
	private static let longPressDelay: Duration = .milliseconds(450)

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
		onPopoverEntry: @escaping () -> Void = {},
		onHighlightChanged: @escaping () -> Void = {}
	) {
		self.key = key
		self.style = style
		self.returnKeyType = returnKeyType
		self.keyWidth = keyWidth
		self.popoverAlignment = popoverAlignment
		self.onTap = onTap
		self.onPopoverEntry = onPopoverEntry
		self.onHighlightChanged = onHighlightChanged
	}

	var body: some View {
		ZStack {
			RoundedRectangle(cornerRadius: style.cornerRadius)
				.fill(isPressed ? style.pressedBackgroundColor : style.backgroundColor)
			content
				.foregroundStyle(style.foregroundColor)
				.font(style.font)
				.minimumScaleFactor(0.6)
				.lineLimit(1)
				.padding(.horizontal, 4)
		}
		.frame(minHeight: 44)
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
					handleTouchDown()
				}
				if isShowingPopover {
					updateHighlight(from: value.location)
				}
			}
			.onEnded { _ in
				handleTouchUp()
			}
	}

	// MARK: - Gesture lifecycle

	private func handleTouchDown() {
		isPressed = true
		didCommitAlternate = false
		guard hasTextAlternates else { return }
		startLongPressTimer()
	}

	private func handleTouchUp() {
		isPressed = false
		longPressTask?.cancel()
		longPressTask = nil

		if isShowingPopover {
			commitAlternate(at: highlightedAlternateIndex)
			isShowingPopover = false
		} else if !didCommitAlternate {
			onTap(key)
		}
		didCommitAlternate = false
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
		case .symbol(let symbol):
			Image(systemName: symbol.systemName)
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
		case .shift:                  return "Shift"
		case .space:                  return "Space"
		case .return:                 return "Return"
		case .nextKeyboard:           return "Next keyboard"
		case .dismissKeyboard:        return "Dismiss keyboard"
		case .switchPage:             return "Switch keyboard layout"
		}
	}
}
