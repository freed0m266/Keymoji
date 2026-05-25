import os.signpost

/// Shared `OSSignposter` used to attribute keyboard rendering work in Instruments.
/// Intervals show up in the Points of Interest track under
/// `subsystem: com.keybo.keyboard / category: perf`.
///
/// **Why this exists:** added while diagnosing the swipe-down dismiss jank tracked in
/// `tasks/29-swipe-down-dismiss-jank.md`. The four hypotheses there each need empirical
/// evidence (is `viewDidLayoutSubviews` firing every frame? is `rebuild()` running mid-gesture?
/// is SwiftUI's `body` re-evaluating per frame?) — these signposts make that visible without
/// having to attach a SwiftUI template every time.
///
/// **Cost:** `OSSignposter` is a near-noop when no profiler is attached, so it's safe to leave
/// the calls in shipping code. Grep for `perfSignposter` to find every active call site.
public let perfSignposter = OSSignposter(subsystem: "com.keybo.keyboard", category: "perf")
