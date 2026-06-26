import Foundation

/// Process-wide analytics sink, backing `AppDependency.analytics`. Starts as a no-op so the keyboard
/// extension, unit tests, and SwiftUI previews never emit; the host app swaps in the real
/// `TelemetryDeckAnalyticsService` once at launch. `@MainActor` because every read and the single
/// write happen on the main thread (App lifecycle, `@MainActor` view models).
@MainActor
private var installedAnalyticsService: any AnalyticsServicing = NoopAnalyticsService()

public extension AppDependency {
	/// The host-app analytics sink. Read it to `report` events; the host app assigns the concrete
	/// `TelemetryDeckAnalyticsService` at launch. Defaults to `NoopAnalyticsService` everywhere else,
	/// so call sites in shared feature code stay inert outside the host app.
	@MainActor
	var analytics: any AnalyticsServicing {
		get { installedAnalyticsService }
		set { installedAnalyticsService = newValue }
	}
}
