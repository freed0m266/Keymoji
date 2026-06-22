import os

/// Dev-only performance signposts (task 73, Phase 0). Wraps `OSSignposter` so the keyboard's hot
/// paths (`handle`, suggestion compute, `matches`, `learn`, `rebuild`) can be profiled in Instruments
/// during development.
///
/// **Ships nothing.** Every signpost call is gated behind `#if DEBUG`; in a release build `measure`
/// collapses to a direct `body()` call with zero added instrumentation, so the privacy claim ("we
/// collect nothing") holds and no telemetry reaches the App Store binary.
public enum Perf {
	#if DEBUG
	/// Single shared signposter for all keyboard hot-path intervals. Subsystem/category show up as the
	/// filter in Instruments' os_signpost track.
	public static let signposter = OSSignposter(subsystem: "com.freedommartin.keymoji", category: "hotpath")
	#endif

	/// Times `body` as a signpost interval named `name`. Release builds compile this to a plain
	/// `body()` invocation (the `#else` branch), so it is a true no-op outside DEBUG.
	@inline(__always)
	public static func measure<T>(_ name: StaticString, _ body: () throws -> T) rethrows -> T {
		#if DEBUG
		let state = signposter.beginInterval(name)
		defer { signposter.endInterval(name, state) }
		return try body()
		#else
		return try body()
		#endif
	}
}
