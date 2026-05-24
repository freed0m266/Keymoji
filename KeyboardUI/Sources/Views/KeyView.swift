import SwiftUI
import KeyboardCore

/// Renders a single keyboard key. Handles pressed-state visual feedback and tap dispatch.
/// Long-press popover (task 07) and delete-repeat (task 09) will hang off this view in later tasks.
struct KeyView: View {
	let key: Key
	let style: KeyStyle
	let returnKeyType: ReturnKeyType
	let onTap: (Key) -> Void

	@State private var isPressed = false

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
		.gesture(pressGesture)
		.accessibilityElement()
		.accessibilityLabel(accessibilityLabel)
		.accessibilityAddTraits(.isKeyboardKey)
	}

	private var pressGesture: some Gesture {
		DragGesture(minimumDistance: 0)
			.onChanged { _ in
				if !isPressed {
					isPressed = true
				}
			}
			.onEnded { _ in
				isPressed = false
				onTap(key)
			}
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
