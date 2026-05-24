import ProjectDescription

private let targetName = "KeyboUI"

public let design = Target.target(
	name: targetName,
	destinations: [.iPhone],
	product: .framework,
	bundleId: "\(appBundleId).ui",
	sources: "\(targetName)/Sources/**",
	dependencies: [
		.target(name: core.name),
		.target(name: resources.name)
	]
)
