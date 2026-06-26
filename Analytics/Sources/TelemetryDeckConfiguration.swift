import Foundation

/// TelemetryDeck wiring constants.
public enum TelemetryDeckConfiguration {

	/// Sentinel for "no real App ID has been set yet". While `appID` equals this, analytics stays fully
	/// inert — the SDK is never initialized and nothing is ever sent (see `isValid`) — so a forgotten
	/// placeholder can't spam a non-existent TelemetryDeck project.
	public static let unconfiguredAppID = "REPLACE-WITH-TELEMETRYDECK-APP-ID"

	/// The TelemetryDeck **App ID** — the UUID found in the TelemetryDeck dashboard under
	/// *App Settings → "Your App's ID"*. This is **not** the App Store Connect app ID (6776134522).
	///
	/// ⚠️ Placeholder. Replace this single string before shipping. Until then analytics is a no-op:
	/// `TelemetryDeckAnalyticsService` treats an unconfigured ID as opted-out, so the SDK is never booted
	/// and no signals are attempted. The build and tests do not need a real value (tests inject a sink).
	public static let appID = unconfiguredAppID

	/// Whether `id` is a real, usable App ID (i.e. set and not the placeholder). Gates SDK initialization
	/// and emission so an unconfigured build sends nothing.
	public static func isValid(_ id: String) -> Bool {
		!id.isEmpty && id != unconfiguredAppID
	}
}
