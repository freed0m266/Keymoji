import Foundation

public let favoriteEmojisEditor = Feature(
	name: "FavoriteEmojisEditor",
	dependencies: [
		.target(name: core.name),
		.target(name: design.name),
		.target(name: resources.name),
		.target(name: keyboardCore.name),
		.target(emojiCatalogPicker)
	]
)
