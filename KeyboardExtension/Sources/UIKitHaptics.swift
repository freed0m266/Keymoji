import UIKit
import KeyboardCore

/// Real haptic implementation. Generators are prepared once at init; each tap triggers a single impact.
///
/// `UIImpactFeedbackGenerator` only generates vibrations from a keyboard extension when the user
/// has enabled "Allow Full Access" in Settings → General → Keyboards → Keybo. Without it, all
/// methods silently no-op (matches iOS sandbox behavior — there is no public API to query for it).
///
/// The `isEnabled` closure lets `KeyboardViewController` short-circuit when the host-app toggle
/// for haptic feedback is off (read from `AppGroupStore` in task 10).
@MainActor
final class UIKitHaptics: HapticFeedbackProviding {
	private let lightImpact: UIImpactFeedbackGenerator
	private let softImpact: UIImpactFeedbackGenerator
	private let selectionGen: UISelectionFeedbackGenerator

	private let isEnabled: () -> Bool

	init(isEnabled: @escaping () -> Bool) {
		self.isEnabled = isEnabled
		self.lightImpact = UIImpactFeedbackGenerator(style: .light)
		self.softImpact = UIImpactFeedbackGenerator(style: .soft)
		self.selectionGen = UISelectionFeedbackGenerator()

		// Pre-warming the generators avoids the first-tap latency spike.
		lightImpact.prepare()
		softImpact.prepare()
		selectionGen.prepare()
	}

	func keyTap() {
		guard isEnabled() else { return }
		lightImpact.impactOccurred()
	}

	func popoverEntry() {
		guard isEnabled() else { return }
		softImpact.impactOccurred(intensity: 0.7)
	}

	func popoverHighlightChanged() {
		guard isEnabled() else { return }
		selectionGen.selectionChanged()
	}
}
