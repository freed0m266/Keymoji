import Foundation

/// Syncs the cheap App Group mirror (`promoPlusExpiresAt`) from the Keychain master record at host-app
/// launch. The Keychain survives an app reinstall but the App Group container does **not**, so a freshly
/// reinstalled app would otherwise show a still-valid trial as expired (and let a consumed grant be
/// re-taken). Run once at launch — never on the hot path.
///
/// The Keychain is always the master: the activators write Keychain *then* mirror to the App Group, so
/// the mirror can only ever be staler, never fresher.
@MainActor
public enum PromoTrialReconciliation {

	/// Bring the App Group mirror in line with the Keychain master. Posts `.promoPlusExpiresAt` if the
	/// mirror actually changed, so a keyboard that's already running picks up a post-reinstall restore.
	public static func reconcile(
		promoStore: any PromoTrialStoring,
		appGroup: AppGroupStore = .shared,
		notifier: SettingsChangeNotifier = .shared
	) {
		let master = promoStore.record.expiresAt
		let mirror = appGroup.promoPlusExpiresAt

		// Tolerant compare: the mirror serializes through an epoch string and the master through JSON, so
		// the two `Date`s for the *same* grant can differ by sub-second float drift. A 1s tolerance avoids
		// a spurious re-post (and keyboard churn) on every launch while still catching real divergence —
		// grants are day-scale, so 1s is never meaningful.
		let needsSync: Bool
		switch (master, mirror) {
		case (nil, nil):
			needsSync = false
		case (nil, .some), (.some, nil):
			needsSync = true
		case let (master?, mirror?):
			needsSync = abs(master.timeIntervalSince1970 - mirror.timeIntervalSince1970) > 1
		}

		guard needsSync else { return }
		appGroup.promoPlusExpiresAt = master
		notifier.post(.promoPlusExpiresAt)
	}

	/// Production entry point: reconcile against the shared Keychain store. Call once at app launch.
	public static func reconcileShared() {
		reconcile(promoStore: PromoTrialStore.makeShared())
	}
}
