import Foundation
import TelemetryDeck
import KeymojiCore

/// The concrete, host-app-only analytics sink. Wraps the TelemetryDeck SDK and emits the anonymous
/// `AnalyticsEvent`s defined SDK-free in `KeymojiCore`.
///
/// This type lives in the `Analytics` framework, which is linked **only** into the Keymoji host app —
/// never the keyboard extension, never `KeymojiCore`. That keeps boundary 1 (ADR 0004) literally true:
/// the keyboard never imports a network SDK and never calls home. The host installs this at launch via
/// `dependencies.analytics = TelemetryDeckAnalyticsService()`.
///
/// **Opt-out is enforced at the SDK level, not just in `report`.** TelemetryDeck initializes its own
/// session tracking, send timer, and disk-cache drain, and auto-emits a `TelemetryDeck.Session.started`
/// signal on launch and every foreground — none of which `report` can gate. So while the user is opted
/// out (or no real App ID is configured), the SDK is **never initialized** (`start` is not called); on
/// opt-in it is booted lazily, and on opt-out it is fully shut down via `TelemetryDeck.terminate()`.
/// Result: OFF → zero signals, full stop.
///
/// `@MainActor` to satisfy `AnalyticsServicing`; all emission happens on the main thread.
@MainActor
public final class TelemetryDeckAnalyticsService: AnalyticsServicing {

	/// Seam over the underlying SDK so the gating logic is unit-testable without booting TelemetryDeck
	/// or hitting the network.
	struct Provider {
		/// Initialize the SDK with the given App ID (boots session tracking + send timer).
		var start: (String) -> Void
		/// Fully shut the SDK down (stops session tracking, timers, and cache drain).
		var stop: () -> Void
		/// Send one consent-passed signal.
		var send: (String, [String: String]) -> Void
	}

	private let consent: AnalyticsConsentStore
	private let appID = "EBFFDBA1-C077-4ED7-A863-DCC42A635498"
	private let provider: Provider
	private var isRunning = false

	// MARK: Init

	/// Production initializer — routes through the live TelemetryDeck SDK. Call once at host-app launch;
	/// it reflects the current opt-out state immediately (boots the SDK only if opted in).
	public convenience init(consent: AnalyticsConsentStore = .shared) {
		self.init(consent: consent, provider: .telemetryDeck)
	}

	/// Seam initializer — injects the SDK hooks. Internal: used by tests via `@testable import Analytics`.
	/// Reflects launch-time consent right away (boots the provider iff opted in with a valid App ID).
	init(consent: AnalyticsConsentStore = .shared, provider: Provider) {
		self.consent = consent
		self.provider = provider
		applyConsent()
	}

	// MARK: Public API

	public func report(_ event: AnalyticsEvent) {
		guard consent.isEnabled else { return }
		applyConsent()	// lazily boot the SDK after an opt-in
		provider.send(event.signalName, event.parameters)
	}

	public func consentDidChange() {
		applyConsent()
	}

	// MARK: Private API

	/// Bring the SDK's running state in line with consent. Opt-in boots it (its session/retention signal
	/// fires); opt-out shuts it fully down so no background session signals, timers, or cache drains can
	/// emit while disabled.
	private func applyConsent() {
		switch (consent.isEnabled, isRunning) {
		case (true, false):
			provider.start(appID)
			isRunning = true
		case (false, true):
			provider.stop()
			isRunning = false
		case (true, true), (false, false):
			break
		}
	}
}

extension TelemetryDeckAnalyticsService.Provider {
	/// The live SDK hooks. `terminate()` deinitializes the manager so opt-out leaves nothing running.
	static var telemetryDeck: Self {
		.init(
			start: { appID in TelemetryDeck.initialize(config: .init(appID: appID)) },
			stop: { TelemetryDeck.terminate() },
			send: { name, parameters in TelemetryDeck.signal(name, parameters: parameters) }
		)
	}
}
