import Foundation

public let emojiCodes = Feature(
	name: "EmojiCodes",
	dependencies: [
		.target(name: core.name),
		.target(name: design.name),
		.target(name: resources.name),
		.target(name: keyboardCore.name)
	]
)
