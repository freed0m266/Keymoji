import ProjectDescription

private let targetName = "KeyboardUI"

public let keyboardUI: Target = .target(
	name: targetName,
	destinations: [.iPhone],
	product: .framework,
	bundleId: "\(appBundleId).keyboardui",
	sources: "\(targetName)/Sources/**",
	dependencies: [
		.target(name: keyboardCore.name),
		.target(name: design.name),
		.target(name: resources.name),
		.target(name: core.name)
	],
	settings: .settings(
		base: ["APPLICATION_EXTENSION_API_ONLY": "YES"]
	)
)

public let keyboardUITests: Target = .target(
	name: "\(targetName)_Tests",
	destinations: [.iPhone],
	product: .unitTests,
	bundleId: "\(appBundleId).keyboardui.tests",
	sources: "\(targetName)/Tests/**",
	dependencies: [
		.target(name: targetName),
		.target(name: keyboardCore.name),
		.target(name: testing.name)
	]
)
