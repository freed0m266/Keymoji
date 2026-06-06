import UIKit
import QuartzCore
import KeyboardCore

/// Real haptic implementation. Generators are prepared once at init and **re-prepared after every
/// impact**, because the Taptic Engine only stays "warm" for a few seconds or until the next
/// feedback — a single `prepare()` at init leaves later taps paying the wake-from-idle latency
/// (the cause of the occasional "haptic feels late" during typing).
///
/// `UIImpactFeedbackGenerator` only generates vibrations from a keyboard extension when the user
/// has enabled "Allow Full Access" in Settings → General → Keyboards → Keymoji. Without it, all
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

	/// Timestamp (mach time) of the last key-tap impact, used to throttle rapid typing.
	private var lastKeyTapTime: CFTimeInterval = 0
	/// Minimum spacing between key-tap haptics. Below this the Taptic Engine can't cleanly
	/// retrigger, so a back-to-back impact would arrive late — the "second haptic waits for the
	/// first" feeling. We **skip** the extra tap rather than queue it: a dropped haptic in a fast
	/// burst feels better than a delayed one, and ~50 ms (≈20 taps/s) is faster than human typing.
	/// (Apple's own haptics patent describes skipping tactile output under a comparable interval.)
	private static let minimumKeyTapInterval: CFTimeInterval = 0.05

	init(isEnabled: @escaping () -> Bool) {
		self.isEnabled = isEnabled
		self.lightImpact = UIImpactFeedbackGenerator(style: .light)
		self.softImpact = UIImpactFeedbackGenerator(style: .soft)
		self.selectionGen = UISelectionFeedbackGenerator()
		prepareForInput()
	}

	/// Pre-warm all generators. Called at init and on each keyboard appearance so the first tap
	/// doesn't pay the Taptic Engine's wake-from-idle latency.
	func prepareForInput() {
		lightImpact.prepare()
		softImpact.prepare()
		selectionGen.prepare()
	}

	func keyTap() {
		guard isEnabled() else { return }
		let now = CACurrentMediaTime()
		guard now - lastKeyTapTime >= Self.minimumKeyTapInterval else { return }
		lastKeyTapTime = now
		lightImpact.impactOccurred()
		// Re-prepare immediately for the *next* key. (Re-preparing helps the next impact, not this
		// one — the engine needs lead time — so we prepare right after firing.)
		lightImpact.prepare()
	}

	func popoverEntry() {
		guard isEnabled() else { return }
		softImpact.impactOccurred(intensity: 0.7)
		softImpact.prepare()
	}

	func popoverHighlightChanged() {
		guard isEnabled() else { return }
		selectionGen.selectionChanged()
		selectionGen.prepare()
	}

	func trackpadModeEntered() {
		guard isEnabled() else { return }
		// Heavier than `keyTap` (soft 1.0 intensity vs. light) so the entry feels distinct from
		// the normal touch-down feedback. Apple's stock keyboard plays a similar "thunk" on entry.
		softImpact.impactOccurred(intensity: 1.0)
		softImpact.prepare()
	}
}
