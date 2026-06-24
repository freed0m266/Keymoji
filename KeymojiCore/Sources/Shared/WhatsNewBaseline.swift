import Foundation

/// Seeds the What's New content-version baseline at host-app launch (task 76). Pure infrastructure: it
/// stamps a starting value the *first* time the app runs on a device and shows nothing. A future build
/// will compare `AppGroupStore.whatsNewVersion` against `WhatsNew.currentVersion` to decide whether to
/// present a What's New screen — this just guarantees the baseline exists *before* any content ships, so
/// a fresh install doesn't get a What's New for the version it was born on.
public enum WhatsNewBaseline {

	/// Seed-on-absence: if the device has never recorded a What's New version, stamp it with the current
	/// one. Idempotent — a key that's already present (any value, including a legitimate `0` or a higher
	/// version a future build wrote) is left untouched, so this never overwrites or regresses. Detection
	/// is by **presence**, never `== 0`, so `0` stays usable as a real version later. Shows nothing.
	public static func seedIfNeeded(appGroup: AppGroupStore = .shared) {
		guard !appGroup.hasValue(forKey: .whatsNewVersion) else { return }
		appGroup.whatsNewVersion = WhatsNew.currentVersion
	}
}
