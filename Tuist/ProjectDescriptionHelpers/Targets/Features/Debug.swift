import Foundation

/// DEBUG-only developer tools (simulate fresh / free-user states for QA of the promo trial surfaces).
/// The whole feature is wrapped in `#if DEBUG`, so in Release this compiles to an empty framework with
/// no public symbols. No tests / no `Testing` mocks — the concrete view model is exercised by hand.
public let debug = Feature(
	name: "Debug",
	dependencies: [
		.target(name: core.name)
	],
	hasTests: false,
	hasTesting: false
)
