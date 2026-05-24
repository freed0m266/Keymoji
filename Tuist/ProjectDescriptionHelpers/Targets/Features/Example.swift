import Foundation

public let example = Feature(
	name: "Example",
	dependencies: [
		.target(name: core.name),
		.target(name: design.name),
		.target(name: resources.name)
	]
)
