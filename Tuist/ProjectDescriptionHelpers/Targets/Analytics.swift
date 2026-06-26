import ProjectDescription

private let targetName = "Analytics"

/// Host-app-only analytics framework. Wraps the TelemetryDeck SDK and is linked **only** into the
/// Keymoji app — never the keyboard extension, never `KeymojiCore` — so the SDK can never reach the
/// extension (boundary 1, ADR 0004). Not extension-API-only on purpose: TelemetryDeck uses app-only
/// APIs, which is exactly why it must stay out of the extension's dependency graph.
public let analytics: Target = .target(
	name: targetName,
	destinations: [.iPhone],
	product: .framework,
	bundleId: "\(appBundleId).analytics",
	sources: "\(targetName)/Sources/**",
	dependencies: [
		.target(name: core.name),
		.external(name: "TelemetryDeck")
	]
)

public let analyticsTests: Target = .target(
	name: "\(targetName)_Tests",
	destinations: [.iPhone],
	product: .unitTests,
	bundleId: "\(appBundleId).analytics.tests",
	sources: "\(targetName)/Tests/**",
	dependencies: [
		.target(name: targetName)
	]
)
