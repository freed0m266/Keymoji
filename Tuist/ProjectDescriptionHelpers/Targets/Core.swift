import ProjectDescription

private let targetName = "KeymojiCore"

public let core: Target = .target(
	name: targetName,
	destinations: [.iPhone],
	product: .framework,
	bundleId: "\(appBundleId).core",
	sources: "\(targetName)/Sources/**",
	dependencies: [
		.target(name: resources.name),
		.external(name: "BaseKitX"),
		.external(name: "SwiftyBeaver"),
		.external(name: "KeychainAccess")
	]
)

public let coreTests: Target = .target(
	name: "\(targetName)_Tests",
	destinations: [.iPhone],
	product: .unitTests,
	bundleId: "\(appBundleId).core.tests",
	sources: "\(targetName)/Tests/**",
	dependencies: [
		.target(name: targetName),
		.target(name: testing.name)
	]
)
