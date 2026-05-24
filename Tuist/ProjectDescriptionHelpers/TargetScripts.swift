import ProjectDescription

extension TargetScript {
	/// Runs SwiftLint via Mint as a post-build step.
	public static var swiftlint: TargetScript {
		.post(
			path: "BuildPhases/Swiftlint.sh",
			name: "SwiftLint",
			basedOnDependencyAnalysis: false
		)
	}

	/// Sets CFBundleShortVersionString and CFBundleVersion automatically from git.
	/// Version: vX.Y.Z git tag, Build: CI build number or git commit count fallback.
	public static var setVersions: TargetScript {
		.post(
			path: "BuildPhases/SetVersions.sh",
			name: "Set App Versions",
			basedOnDependencyAnalysis: false
		)
	}
}
