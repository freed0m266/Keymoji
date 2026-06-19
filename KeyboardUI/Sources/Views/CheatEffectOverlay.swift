import SwiftUI
import ConfettiSwiftUI

/// Drives the cheat code celebration overlay. A reference type so its trigger/banner survive the
/// keyboard's frequent SwiftUI rebuilds (the root view is replaced on every `makeRoot()`, but this
/// controller is held by `KeyboardViewController` and passed in by reference, so the bound
/// `ConfettiCannon` and the banner keep their state across rebuilds).
@MainActor
@Observable
public final class CheatEffectController {

	/// Incremented to fire one confetti burst (bound into `ConfettiCannon`).
	public var confettiTrigger = 0
	/// Non-nil while the celebration banner is showing; auto-cleared after `bannerDuration`.
	public private(set) var bannerText: String?

	private var dismissTask: Task<Void, Never>?
	private let bannerDuration: Duration

	public init(bannerDuration: Duration = .seconds(3)) {
		self.bannerDuration = bannerDuration
	}

	/// Show `banner`, and optionally pop confetti. `confetti: false` is the "already used 🔒" path — a
	/// quiet toast, no celebration. Re-firing resets the auto-dismiss timer.
	public func fire(banner: String, confetti: Bool = true) {
		bannerText = banner
		if confetti { confettiTrigger += 1 }
		dismissTask?.cancel()
		dismissTask = Task { [weak self] in
			guard let self else { return }
			try? await Task.sleep(for: bannerDuration)
			if !Task.isCancelled { bannerText = nil }
		}
	}
}

/// Transient celebration over the keyboard for the cheat code promo (task 64 Scope 11): a confetti burst
/// plus a short banner. **Visual only** — the chime + haptic are fired by `KeyboardViewController`
/// (which owns the sound service and the `keyClickSoundEnabled` gate). Never intercepts touches, so
/// typing keeps working underneath.
///
/// Choreography (confetti count/size/radius, banner styling) is intentionally modest here; tune it
/// on-device after the first build (task 64 Scope 11) — and keep the burst small to respect the
/// keyboard extension's jetsam ceiling.
public struct CheatEffectOverlay: View {

	@Bindable private var controller: CheatEffectController

	public init(controller: CheatEffectController) {
		self.controller = controller
	}

	public var body: some View {
		ZStack(alignment: .top) {
			if let banner = controller.bannerText {
				Text(banner)
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(.primary)
					.multilineTextAlignment(.center)
					.padding(.horizontal, 16)
					.padding(.vertical, 10)
					.background(.regularMaterial, in: Capsule())
					.shadow(radius: 8, y: 2)
					.padding(.top, 8)
					.transition(.move(edge: .top).combined(with: .opacity))
			}

			// Confetti origin: top-centre, raining down over the keys.
			ConfettiCannon(
				trigger: $controller.confettiTrigger,
				num: 24,
				confettiSize: 8,
				rainHeight: 350,
				radius: 220,
				// Off: the library's built-in haptic ignores the user's `hapticFeedbackEnabled` toggle and
				// would double up with the controller-gated haptic. `KeyboardViewController` owns the haptic.
				hapticFeedback: false
			)
			.frame(maxWidth: .infinity)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
		.allowsHitTesting(false)   // never block typing underneath
		.animation(.spring(duration: 0.3), value: controller.bannerText)
	}
}
