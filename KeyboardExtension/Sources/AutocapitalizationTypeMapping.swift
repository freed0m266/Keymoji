import UIKit
import KeyboardCore

/// Maps `UITextAutocapitalizationType` into the UIKit-free `AutocapitalizationType`.
enum AutocapitalizationTypeMapping {
	static func map(_ type: UITextAutocapitalizationType) -> AutocapitalizationType {
		switch type {
		case .none:          return .none
		case .words:         return .words
		case .sentences:     return .sentences
		case .allCharacters: return .allCharacters
		@unknown default:    return .sentences  // Apple default
		}
	}
}
