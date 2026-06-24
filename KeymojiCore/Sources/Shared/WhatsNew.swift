import Foundation

/// Versioning baseline for the future "What's New" screen (task 76). This build ships only the
/// *baseline* — a seeded value in the App Group store — with **no UI, no content, no comparison**.
/// A later build will compare `AppGroupStore.whatsNewVersion` against ``currentVersion`` to decide
/// whether to present What's New; planting the baseline first means a fresh install never gets a
/// What's New for the version it was born on.
public enum WhatsNew {

	/// Monotonic content version, bumped **by hand** each time new What's New content is authored.
	/// Deliberately decoupled from the marketing/build version: What's New cadence ≠ release cadence
	/// (a bugfix release may ship no content; one release may carry two announcements), and a plain
	/// `Int` comparison (`stored < current`) beats semantic version-string parsing.
	///
	/// `1` is the baseline: this session has no content. The first real What's New ships as `2`.
	public static let currentVersion = 1
}
