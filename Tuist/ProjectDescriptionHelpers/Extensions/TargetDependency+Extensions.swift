import ProjectDescription

public extension TargetDependency {
	static func target(_ feature: Feature) -> TargetDependency {
		.target(feature.target)
	}
}
