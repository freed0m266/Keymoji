import ProjectDescription

public struct Feature: Sendable {
	public let target: Target
	public let testTarget: Target?

	public var allTargets: [Target] { [target, testTarget].compactMap { $0 } }

	public init(
		name: String,
		dependencies: [TargetDependency],
		hasTests: Bool = true,
		hasTesting: Bool = true
	) {
		let mainBundleID = "\(appBundleId).feature." + name.toBundleID()
		let sources = SourceFilesList.sourceFilesList(
			globs: [
				"Features/\(name)/Sources/**",
				hasTesting ? "Features/\(name)/Testing/**" : nil
			].compactMap { $0 }
		)

		target = .target(
			name: name,
			destinations: .iOS,
			product: .framework,
			bundleId: mainBundleID,
			sources: sources,
			dependencies: dependencies,
			settings: .settings(
				base: ["APPLICATION_EXTENSION_API_ONLY": false]
			)
		)

		testTarget = !hasTests ? nil : .target(
			name: name + "_Tests",
			destinations: .iOS,
			product: .unitTests,
			bundleId: mainBundleID + ".unittests",
			sources: "Features/\(name)/Tests/**",
			dependencies: [
				.target(target),
				.target(testing)
			],
			settings: .settings(
				base: ["APPLICATION_EXTENSION_API_ONLY": false]
			)
		)
	}
}
