#if DEBUG
import Foundation

/// DEBUG-only developer overrides that live in the entitlement domain. The one override today is
/// ``forceFreeTier``, which masks a real (paid) Plus entitlement down to `false` so a developer can
/// **simulate a free user** without resetting StoreKit or losing their real purchase. It belongs in
/// `KeymojiCore` (next to `PurchaseService` / `effectiveIsPlus`) because the mask is applied inside the
/// single entitlement writer, `PurchaseService.applyEntitlement`.
///
/// **Host-only by construction:** the flag lives in `UserDefaults.standard` (not the App Group), so the
/// keyboard extension never sees it — the extension only ever reads the *already-masked*
/// `AppGroupStore.isPlus` mirror the host writes. That keeps the cross-process contract honest: one
/// masked value flows out, rather than a shared toggle both processes have to agree on.
///
/// The whole type is compiled out of Release (`#if DEBUG`), so no debug logic can leak into production.
public enum DebugOverrides {

	/// Backing store for the override flags. `internal` and mutable so unit tests can swap in an isolated
	/// suite instead of polluting the shared `UserDefaults.standard`; production always uses `.standard`.
	nonisolated(unsafe) static var defaults: UserDefaults = .standard

	private static let forceFreeTierKey = "debug.forceFreeTier"

	/// When `true`, `PurchaseService.applyEntitlement` masks paid Plus to `false`, simulating a free user
	/// across every effective-Plus gate (favorites cap, Settings row, paywall, keyboard). **Persistent**
	/// (survives relaunch) so a QA session stays in the simulated state across restarts, and **live** —
	/// flipping it then calling `PurchaseService.refreshEntitlement()` re-applies the mask (or restores
	/// real Plus when turned off) and re-posts the `.isPlus` notification, so UI and keyboard update at once.
	public static var forceFreeTier: Bool {
		get { defaults.bool(forKey: forceFreeTierKey) }
		set { defaults.set(newValue, forKey: forceFreeTierKey) }
	}
}
#endif
