import Foundation

/// The opt-out switch for anonymous analytics. **Default ON** (opt-out, per ADR 0004): absence of a
/// stored value reads as enabled, so the user is opted in until they turn it off in Settings.
///
/// Lives in **host-side `UserDefaults.standard`**, deliberately *not* the App Group: the keyboard
/// extension never emits and so never needs to read it (boundary 1). The flag's *state* is still
/// reported in the settings snapshot (so we can see opt-out rate), but that emission happens only in
/// the host app. Flipping it takes effect immediately — `TelemetryDeckAnalyticsService` re-reads
/// `isEnabled` on every `report`, so turning it OFF drops all subsequent signals to zero.
///
/// `@unchecked Sendable`: the only stored property is `UserDefaults`, which Apple documents as
/// thread-safe.
public final class AnalyticsConsentStore: @unchecked Sendable {

	public static let shared = AnalyticsConsentStore()

	private let defaults: UserDefaults
	private let key = "analytics.enabled"

	/// Injectable for tests; defaults to the host app's standard defaults.
	public init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	/// Whether anonymous analytics is enabled. Unset → `true` (opt-out default-on). Probe
	/// `object(forKey:)` so a stored `false` is distinguishable from "never set".
	public var isEnabled: Bool {
		get {
			guard defaults.object(forKey: key) != nil else { return true }
			return defaults.bool(forKey: key)
		}
		set { defaults.set(newValue, forKey: key) }
	}
}
