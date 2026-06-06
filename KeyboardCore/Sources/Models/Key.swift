import Foundation

/// A single key in the keyboard layout — the primary character/symbol shown on the cap,
/// optional alternates revealed via long-press, the action it dispatches, and how wide it should render.
public struct Key: Identifiable, Sendable, Equatable {
	public let id: String
	public let primary: KeyContent
	public let alternates: [KeyContent]
	public let action: KeyAction
	public let visualWeight: KeyWeight
	public let role: KeyRole
	/// Empty space rendered immediately before / after this key, in the same weight units as
	/// `visualWeight`. Lets a key sit flush against a row edge while keeping breathing room from
	/// its neighbor (e.g. the symbols row's toggle / delete). `0` for ordinary keys.
	public let leadingGapWeight: Double
	public let trailingGapWeight: Double

	public init(
		id: String,
		primary: KeyContent,
		alternates: [KeyContent],
		action: KeyAction,
		visualWeight: KeyWeight,
		role: KeyRole,
		leadingGapWeight: Double = 0,
		trailingGapWeight: Double = 0
	) {
		self.id = id
		self.primary = primary
		self.alternates = alternates
		self.action = action
		self.visualWeight = visualWeight
		self.role = role
		self.leadingGapWeight = leadingGapWeight
		self.trailingGapWeight = trailingGapWeight
	}

	/// Returns a copy with adjacent gap weights set — lets the layout builder add edge breathing
	/// room to an already-constructed key without rebuilding it from scratch.
	public func addingGaps(leading: Double = 0, trailing: Double = 0) -> Key {
		Key(
			id: id,
			primary: primary,
			alternates: alternates,
			action: action,
			visualWeight: visualWeight,
			role: role,
			leadingGapWeight: leading,
			trailingGapWeight: trailing
		)
	}
}

public enum KeyContent: Sendable, Equatable {
	case text(String)
	case symbol(SystemSymbol)
}

/// Reference to an SF Symbol used to render a system key (shift, delete, return).
/// `KeyboardCore` is pure Swift, so this enum stores only the symbol identifier;
/// view-layer (`KeyboardUI`) maps it to an actual `Image(systemName:)`.
public enum SystemSymbol: String, Sendable, Equatable {
	case shift
	case shiftFill
	case capsLockFill
	case delete
	case search
	case `return`
	case smiley

	public var systemName: String {
		switch self {
		case .shift:        return "shift"
		case .shiftFill:    return "shift.fill"
		case .capsLockFill: return "capslock.fill"
		case .delete:       return "delete.left"
		case .search:       return "magnifyingglass"
		case .return:       return "return"
		case .smiley:       return "face.smiling"
		}
	}
}

public enum KeyAction: Sendable, Equatable {
	case insertText(String)
	/// Used by long-press popover commits to bypass shift-apply (alternate is already in the right case).
	case insertRawText(String)
	case backspace
	/// Backspace through one trailing "word" — emitted by `KeyView` after a long delete-on-hold.
	case deleteWord
	case shift
	case space
	case `return`
	case dismissKeyboard
	case switchPage(KeyboardPage)
	/// Move the cursor by `offset` characters (negative = left). Emitted by `KeyView` while
	/// the user drags inside trackpad-mode (long-press on space). Does not insert/delete text.
	case cursorOffset(Int)
	/// Accept a word-completion chip: delete the in-progress word prefix and insert
	/// `replacementText` followed by a space. `displayText` is carried for parity/analytics; the
	/// committed text is `replacementText` (they're equal for plain word chips).
	case suggestionAccept(displayText: String, replacementText: String)
}

public enum KeyRole: Sendable, Equatable {
	/// Inserts character into the document (letters, digits, punctuation).
	case character
	/// Controls keyboard behavior (shift, delete, return, space, page toggle).
	case system
}

/// Relative width hint for layout. View layer normalizes weights across a row to fill available width.
public struct KeyWeight: Sendable, Equatable {
	public let value: Double

	public init(_ value: Double) {
		self.value = value
	}

	public static let standard = KeyWeight(1.0)
	public static let wide = KeyWeight(1.5)
	public static let space = KeyWeight(4.25)
	public static let small = KeyWeight(1.25)
	public static let dotKey = KeyWeight(1.0)
	public static let returnKey = KeyWeight(1.5)
}
