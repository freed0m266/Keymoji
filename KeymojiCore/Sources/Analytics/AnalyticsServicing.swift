import Foundation

/// Host-app analytics sink. Emits **anonymous** product signals only — settings *states* and
/// lifecycle/funnel events, never anything the user types (boundary 2, ADR 0004). The concrete
/// `TelemetryDeckAnalyticsService` lives in the host-app-only `Analytics` framework so the
/// TelemetryDeck SDK never reaches `KeymojiCore` (which is linked into the keyboard extension). The
/// keyboard extension keeps the default `NoopAnalyticsService` and therefore never emits and never
/// makes a network call — *"the keyboard never calls home"* stays literally true (boundary 1).
///
/// `@MainActor`: every emission point (App lifecycle, `@MainActor` view models) runs on the main
/// thread, so isolating the protocol keeps the global sink free of cross-actor hazards.
@MainActor
public protocol AnalyticsServicing: AnyObject {
	/// Report one anonymous event. A conformer must drop the event entirely when the user has opted
	/// out (see `AnalyticsConsentStore`) so OFF means **zero** signals leave the device.
	func report(_ event: AnalyticsEvent)

	/// Notify the sink that the opt-out flag changed (call after writing `AnalyticsConsentStore`). A
	/// provider with its own background emission (e.g. TelemetryDeck's session signals) must use this to
	/// fully start or stop the underlying SDK — guarding `report` alone wouldn't silence those.
	func consentDidChange()
}

/// The default sink: does nothing. Installed everywhere the real service isn't (keyboard extension,
/// unit tests, SwiftUI previews), so emission is inert unless the host app explicitly opts in by
/// installing `TelemetryDeckAnalyticsService` at launch.
public final class NoopAnalyticsService: AnalyticsServicing {
	public init() {}
	public func report(_ event: AnalyticsEvent) {}
	public func consentDidChange() {}
}
