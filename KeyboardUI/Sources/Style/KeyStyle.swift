import SwiftUI
import KeyboardCore

/// Visual style for a single key. Three darkness tiers mirror Apple's stock keyboard:
/// **character** (a-z, digits, symbols) is the lightest in dark mode, **system** (shift,
/// delete) sits in the middle, and **function** (space, return, page switches, dismiss)
/// is the darkest — close to the keyboard surface itself.
struct KeyStyle: Sendable {
	let backgroundColor: Color
	let pressedBackgroundColor: Color
	/// Background while trackpad-on-space mode is active (task 75) — a subtle tint shift from
	/// `backgroundColor`. Defaults to the shared `trackpadBackground` token, so every tier picks up
	/// the same "keyboard is now a trackpad" cue regardless of its normal colour.
	let trackpadBackgroundColor: Color
	let foregroundColor: Color
	let font: Font?
	let cornerRadius: CGFloat

	init(
		backgroundColor: Color = Color(uiColor: KeyboardSurfaceColors.characterBackground),
		pressedBackgroundColor: Color = Color(uiColor: KeyboardSurfaceColors.characterPressed),
		trackpadBackgroundColor: Color = Color(uiColor: KeyboardSurfaceColors.trackpadBackground),
		foregroundColor: Color = Color(.label),
		font: Font? = nil,
		cornerRadius: CGFloat = 8
	) {
		self.backgroundColor = backgroundColor
		self.pressedBackgroundColor = pressedBackgroundColor
		self.trackpadBackgroundColor = trackpadBackgroundColor
		self.foregroundColor = foregroundColor
		self.font = font
		self.cornerRadius = cornerRadius
	}
}

extension KeyStyle {
	/// Pick a style for a given key, with shift-state awareness for the shift key itself.
	/// Dispatch is action-driven (not role-driven) because `KeyRole` only distinguishes
	/// two tiers — character vs. system — while the visual design needs three.
	static func style(for key: Key, page: KeyboardPage) -> KeyStyle {
		if case .shift = key.action, case .letters(let shift) = page {
			switch shift {
			case .lower:               return characterKey()
			case .upper, .capsLock:    return shiftActive()
			}
		}

		switch key.action {
		case .space, .return, .switchPage, .dismissKeyboard:
			return functionKey(for: key.action)
		case .backspace, .deleteWord, .shift, .insertText, .insertRawText, .cursorOffset, .cursorLineOffset, .suggestionAccept:
			// `.suggestionAccept` is synthesized for the suggestion bar and never rendered as a
			// physical key, but the switch must stay exhaustive.
			return characterKey()
		}
	}
}

private extension KeyStyle {
	static func characterKey() -> KeyStyle {
		KeyStyle(font: .system(size: 24, weight: .regular))
	}

	static func functionKey(for action: KeyAction) -> KeyStyle {
		KeyStyle(font: .system(size: 17, weight: .semibold))
	}

	static func shiftActive() -> KeyStyle {
		// Inverted contrast signals active shift / caps lock. The icon (shift.fill vs capslock.fill)
		// distinguishes the two visually.
		KeyStyle(
			backgroundColor: Color(.label),
			pressedBackgroundColor: Color(.secondaryLabel),
			foregroundColor: Color(.systemBackground)
		)
	}
}
