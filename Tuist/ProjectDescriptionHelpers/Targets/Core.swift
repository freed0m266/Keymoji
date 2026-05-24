import ProjectDescription

private let targetName = "KeyboCore"

public let core: Target = .target(
	name: targetName,
	destinations: [.iPhone],
	product: .framework,
	bundleId: "\(appBundleId).core",
	sources: "\(targetName)/Sources/**",
	dependencies: [
		.target(name: resources.name),
		.external(name: "ACKategories"),
		.external(name: "BaseKitX"),
		.external(name: "SwiftyBeaver")
	]
)
