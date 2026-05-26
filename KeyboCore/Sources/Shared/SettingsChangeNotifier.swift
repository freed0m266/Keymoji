import Foundation

/// Cross-process notifier for `AppGroupStore` changes, built on Darwin notifications
/// (`CFNotificationCenterGetDarwinNotifyCenter`) — the only IPC mechanism iOS allows
/// between a host app and its keyboard extension short of polling.
///
/// Darwin notifications are payload-free by design: the contract is "this key changed,
/// re-read it from `AppGroupStore` to see the new value". The notifier exposes one
/// notification name per `AppGroupStoreKey` so subscribers can listen for only the
/// keys they care about instead of re-reading every setting on every change.
///
/// Without this, the keyboard extension only picks up host-app toggle changes on the
/// next `viewWillAppear` — the user has to dismiss and re-open the keyboard for a
/// toggle flip to take effect.
public final class SettingsChangeNotifier: Sendable {

	public static let shared = SettingsChangeNotifier()

	public init() {}

	/// Posts a Darwin notification announcing that `key`'s value changed. Cross-process,
	/// payload-free — receivers re-read `AppGroupStore` to learn the new value.
	public func post(_ key: AppGroupStoreKey) {
		let name = Self.notificationName(for: key)
		CFNotificationCenterPostNotification(
			CFNotificationCenterGetDarwinNotifyCenter(),
			name,
			nil,
			nil,
			true
		)
	}

	/// Subscribes `handler` to changes for `key`. The returned token owns the
	/// subscription — drop it (or let it deinit) to deregister. `handler` always runs
	/// on the main actor: Darwin may deliver on an arbitrary thread, so the token
	/// hops before invoking.
	@MainActor
	public func addObserver(
		for key: AppGroupStoreKey,
		handler: @escaping @MainActor @Sendable () -> Void
	) -> SettingsObservationToken {
		SettingsObservationToken(key: key, handler: handler)
	}

	/// Namespaced under the app bundle ID so notifications from this app don't collide
	/// with anything else on the device. Stays well under Darwin's 128-char name cap.
	static func notificationName(for key: AppGroupStoreKey) -> CFNotificationName {
		CFNotificationName("com.freedommartin.keybo.settings.\(key.rawValue)" as CFString)
	}
}

/// RAII handle for a Darwin notification subscription. `deinit` removes the observer
/// from `CFNotificationCenter`, so the subscription's lifetime matches the token's —
/// no manual `removeObserver` call required at the call site.
@MainActor
public final class SettingsObservationToken {

	private let name: CFNotificationName
	private let box: HandlerBox

	fileprivate init(
		key: AppGroupStoreKey,
		handler: @escaping @MainActor @Sendable () -> Void
	) {
		self.name = SettingsChangeNotifier.notificationName(for: key)
		self.box = HandlerBox(handler: handler)

		// The `observer` pointer doubles as the de-dup key for add/remove pairs — we
		// pass the box's address and recover the box in the C callback. `passUnretained`
		// is safe because the token owns the box and removes the observer in `deinit`,
		// strictly before the box can be freed.
		let observer = Unmanaged.passUnretained(box).toOpaque()
		CFNotificationCenterAddObserver(
			CFNotificationCenterGetDarwinNotifyCenter(),
			observer,
			{ _, observer, _, _, _ in
				guard let observer else { return }
				let box = Unmanaged<HandlerBox>.fromOpaque(observer).takeUnretainedValue()
				let handler = box.handler
				// Darwin can deliver on any thread; hop to main before invoking.
				Task { @MainActor in
					handler()
				}
			},
			name.rawValue,
			nil,
			.deliverImmediately
		)
	}

	deinit {
		let observer = Unmanaged.passUnretained(box).toOpaque()
		CFNotificationCenterRemoveObserver(
			CFNotificationCenterGetDarwinNotifyCenter(),
			observer,
			name,
			nil
		)
	}
}

/// Sendable storage so the handler closure can be reached from the `@convention(c)`
/// Darwin callback (which has no Swift isolation context). The box is immutable; the
/// `@MainActor @Sendable` closure is itself safe to ferry across actors.
private final class HandlerBox: Sendable {
	let handler: @MainActor @Sendable () -> Void

	init(handler: @escaping @MainActor @Sendable () -> Void) {
		self.handler = handler
	}
}
