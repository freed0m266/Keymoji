import Foundation

public let onboarding = Feature(
	name: "Onboarding",
	dependencies: [
		.target(name: core.name),
		.target(name: design.name),
		.target(name: resources.name),
		.target(name: keyboardCore.name)
	]
)
