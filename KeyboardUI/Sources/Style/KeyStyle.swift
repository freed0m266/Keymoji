import SwiftUI
import KeyboardCore

/// Visual style for a single key. Pure system semantic colors — the keyboard inherits
/// the consuming app's color scheme automatically (light or dark).
struct KeyStyle: Sendable {
	let backgroundColor: Color
	let pressedBackgroundColor: Color
	let foregroundColor: Color
	let font: Font
	let cornerRadius: CGFloat
}

extension KeyStyle {

	/// Pick a style for a given key, with shift-state awareness for the shift key itself.
	static func style(for key: Key, page: KeyboardPage) -> KeyStyle {
		if case .shift = key.action, case .letters(let shift) = page {
			switch shift {
			case .lower:    return systemKey()
			case .upper:    return shiftActive()
			case .capsLock: return shiftActive()
			}
		}

		switch key.role {
		case .character: return characterKey()
		case .system:    return systemKey()
		}
	}

	// MARK: - Variants

	private static func characterKey() -> KeyStyle {
		KeyStyle(
			backgroundColor: Color(.systemGray4),
			pressedBackgroundColor: Color(.systemGray3),
			foregroundColor: Color(.label),
			font: .system(size: 22, weight: .regular),
			cornerRadius: 5
		)
	}

	private static func systemKey() -> KeyStyle {
		KeyStyle(
			backgroundColor: Color(.systemGray2),
			pressedBackgroundColor: Color(.systemGray),
			foregroundColor: Color(.label),
			font: .system(size: 16, weight: .semibold),
			cornerRadius: 5
		)
	}

	private static func shiftActive() -> KeyStyle {
		// Inverted contrast signals active shift / caps lock. The icon (shift.fill vs capslock.fill)
		// distinguishes the two visually.
		KeyStyle(
			backgroundColor: Color(.label),
			pressedBackgroundColor: Color(.secondaryLabel),
			foregroundColor: Color(.systemBackground),
			font: .system(size: 16, weight: .semibold),
			cornerRadius: 5
		)
	}
}
