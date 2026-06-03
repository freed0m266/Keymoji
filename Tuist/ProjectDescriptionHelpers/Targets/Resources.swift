import ProjectDescription

private let targetName = "KeymojiResources"

public let resources = Target.target(
	name: targetName,
	destinations: [.iPhone],
	product: .framework,
	bundleId: "\(appBundleId).resources",
	sources: "\(targetName)/Sources/**",
	resources: "\(targetName)/Resources/**"
)
