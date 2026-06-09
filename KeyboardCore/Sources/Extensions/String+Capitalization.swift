import Foundation

public extension String {
	/// Uppercases only the first character, leaving the remainder untouched (so "iPhone"-style
	/// internal capitals in a learned word survive). Distinct from `.capitalized`, which lowercases
	/// the tail.
	func capitalizedFirstLetter() -> String {
		guard let first else { return self }
		return first.uppercased() + dropFirst()
	}
}
