import ProjectDescription

private let targetName = "KeyboTesting"

public let testing: Target = .target(
	name: targetName,
	destinations: [.iPhone],
	product: .framework,
	bundleId: "\(appBundleId).testing",
	sources: "\(targetName)/Tests/**",
	dependencies: [
		.xctest,
		.external(name: "SnapshotTesting")
	]
)
