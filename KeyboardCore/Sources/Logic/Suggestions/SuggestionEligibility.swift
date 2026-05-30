import Foundation

/// Where the keyboard may *learn* from typing. The display gate is separate (`allowDisplay`);
/// a field can show suggestions while contributing nothing to the personal pool, but never the
/// reverse — anything we learn from, we also suggest in.
public enum TextContextType: Sendable, Equatable {
	/// Regular prose: `.default` / `.asciiCapable` / unspecified keyboard with no sensitive
	/// content type. Learns word-by-word.
	case prose
	/// An email field (`emailAddress` keyboard or content type). Learns the whole field as one
	/// token (see `PersonalRecentsStore` + the controller's whole-field harvest).
	case emailAddress
	/// Never learn: passwords, OTP, card numbers, number/phone/URL fields, name fields, secure
	/// entry, and anything else not explicitly whitelisted above.
	case denied
}

/// UIKit-free mirror of the `UIKeyboardType` cases the eligibility rules care about. The extension
/// maps `UIKeyboardType` → this (see `SuggestionFieldTraitsMapping`), keeping `KeyboardCore`
/// UIKit-free and the eligibility matrix unit-testable — same pattern as `ReturnKeyType`.
public enum KeyboardInputKind: Sendable, Equatable {
	case `default`
	case asciiCapable
	case numbersAndPunctuation
	case url
	case numberPad
	case phonePad
	case namePhonePad
	case emailAddress
	case decimalPad
	case twitter
	case webSearch
	case asciiCapableNumberPad
}

/// UIKit-free mirror of the `UITextContentType` values that gate suggestions/learning. `.other`
/// covers every content type we don't special-case (addresses, URLs, etc.) — those fall back to
/// keyboard-type rules. `.name` covers the name family (`.name`, `.givenName`, `.familyName`,
/// `.nickname`, …), which the privacy deny-list excludes from learning.
public enum TextContentKind: Sendable, Equatable {
	case password
	case newPassword
	case oneTimeCode
	case creditCardNumber
	case emailAddress
	case name
	case other
}

/// Decides whether the suggestion bar may show in a field and, if learning is allowed, in which
/// mode. Pure function of the field's traits so the full matrix is unit-testable.
public struct SuggestionEligibility: Sendable, Equatable {
	/// May the bar render at all in this field?
	public let allowDisplay: Bool
	/// How (if at all) typing in this field feeds the personal recents pool.
	public let learningContext: TextContextType

	public init(allowDisplay: Bool, learningContext: TextContextType) {
		self.allowDisplay = allowDisplay
		self.learningContext = learningContext
	}

	/// Deny everything — the safe default before a field's traits are known and the value used for
	/// every secure/sensitive field.
	public static let denied = SuggestionEligibility(allowDisplay: false, learningContext: .denied)

	/// Evaluate the E1 display deny-list + L2 learning whitelist.
	///
	/// Order matters: secure entry and sensitive content types win over everything, then the email
	/// exception (display on, email-mode learning), then per-keyboard-type deny, then the prose
	/// default.
	public static func evaluate(
		isSecureTextEntry: Bool,
		keyboardType: KeyboardInputKind,
		textContentType: TextContentKind?
	) -> SuggestionEligibility {
		// Secure entry and sensitive content types: no display, no learning.
		if isSecureTextEntry { return .denied }
		switch textContentType {
		case .password, .newPassword, .oneTimeCode, .creditCardNumber, .name:
			// Name fields are on the privacy deny-list — never display or learn there.
			return .denied
		case .emailAddress:
			// Email content type forces the email exception regardless of keyboard type.
			return SuggestionEligibility(allowDisplay: true, learningContext: .emailAddress)
		case .other, .none:
			break
		}

		switch keyboardType {
		case .emailAddress:
			return SuggestionEligibility(allowDisplay: true, learningContext: .emailAddress)
		case .numberPad, .decimalPad, .phonePad, .asciiCapableNumberPad,
		     .url, .webSearch, .twitter, .namePhonePad:
			return .denied
		case .default, .asciiCapable, .numbersAndPunctuation:
			return SuggestionEligibility(allowDisplay: true, learningContext: .prose)
		}
	}
}
