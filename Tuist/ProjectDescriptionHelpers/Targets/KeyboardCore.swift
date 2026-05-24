import ProjectDescription

private let targetName = "KeyboardCore"

public let keyboardCore: Target = .target(
	name: targetName,
	destinations: [.iPhone],
	product: .framework,
	bundleId: "\(appBundleId).keyboardcore",
	sources: "\(targetName)/Sources/**",
	dependencies: [
		.target(name: resources.name),
		.target(name: core.name)
	],
	settings: .settings(
		base: ["APPLICATION_EXTENSION_API_ONLY": "YES"]
	)
)

public let keyboardCoreTests: Target = .target(
	name: "\(targetName)_Tests",
	destinations: [.iPhone],
	product: .unitTests,
	bundleId: "\(appBundleId).keyboardcore.tests",
	sources: "\(targetName)/Tests/**",
	dependencies: [
		.target(name: targetName),
		.target(name: testing.name)
	]
)
