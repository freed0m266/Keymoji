import Foundation

public let paywall = Feature(
	name: "Paywall",
	dependencies: [
		.target(name: core.name),
		.target(name: design.name),
		.target(name: resources.name)
	]
)
