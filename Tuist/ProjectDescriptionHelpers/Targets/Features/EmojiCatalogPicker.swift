import Foundation

public let emojiCatalogPicker = Feature(
	name: "EmojiCatalogPicker",
	dependencies: [
		.target(name: core.name),
		.target(name: design.name),
		.target(name: resources.name),
		.target(name: keyboardCore.name)
	],
	hasTesting: false
)
