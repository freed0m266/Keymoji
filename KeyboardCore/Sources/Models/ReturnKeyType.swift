import Foundation

/// Sendable mirror of `UIReturnKeyType`. Lives in `KeyboardCore` so the framework stays UIKit-free.
/// Adapter in the extension target maps `UIReturnKeyType` → `ReturnKeyType`.
public enum ReturnKeyType: Sendable, Equatable {
	case `default`
	case go
	case google
	case join
	case next
	case route
	case search
	case send
	case done
	case emergencyCall
	case `continue`
	case yahoo
}
