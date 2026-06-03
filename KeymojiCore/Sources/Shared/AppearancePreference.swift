import Foundation

/// User preference for the keyboard's color scheme. `.system` follows the host app's trait
/// collection (the v1.0 behavior); `.light` and `.dark` force a specific style regardless of
/// what the consuming app shows.
public enum AppearancePreference: String, Sendable, CaseIterable {
	case system
	case light
	case dark
}
