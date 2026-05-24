import Foundation

extension String {
	func toBundleID() -> String {
		components(separatedBy: .alphanumerics.inverted).joined()
	}
}
