import Foundation

public let about = Feature(
	name: "About",
	dependencies: [
		.target(name: core.name),
		.target(name: design.name),
		.target(name: resources.name)
	]
)
