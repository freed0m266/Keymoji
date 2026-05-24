import UIKit
import KeyboardCore

/// Maps Apple's `UIReturnKeyType` into the UIKit-free `ReturnKeyType` enum used by `KeyboardCore`.
enum ReturnKeyTypeMapping {
	static func map(_ type: UIReturnKeyType) -> ReturnKeyType {
		switch type {
		case .default:        return .default
		case .go:             return .go
		case .google:         return .google
		case .join:           return .join
		case .next:           return .next
		case .route:          return .route
		case .search:         return .search
		case .send:           return .send
		case .done:           return .done
		case .emergencyCall:  return .emergencyCall
		case .continue:       return .continue
		case .yahoo:          return .yahoo
		@unknown default:     return .default
		}
	}
}
