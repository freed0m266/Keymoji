import Foundation

public let settings = Feature(
	name: "Settings",
	dependencies: [
		.target(name: core.name),
		.target(name: design.name),
		.target(name: resources.name),
		.target(keyboardCore),
		.target(onboarding),
		.target(paywall),
		.target(about),
		.target(emojiCodes),
		.target(favoriteEmojisEditor),
		.target(learnedWordsEditor),
		.target(debug)
	]
)
