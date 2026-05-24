import ProjectDescription

let appBundleId = "com.freedommartin.keybo"

private let targetName = "Keybo"

public let app: Target = .target(
	name: targetName,
	destinations: [.iPhone],
	product: .app,
	bundleId: appBundleId,
	infoPlist: .extendingDefault(with: [
		"CFBundleDisplayName": .string(targetName),
		"UILaunchScreen": [
			"UIColorName": "BackgroundColor",
		],
		"UIUserInterfaceStyle": "Dark",
		"UIApplicationSceneManifest": [
			"UIApplicationSupportsMultipleScenes": false,
			"UISceneConfigurations": .dictionary([:]),
		],
	]),
	sources: ["\(targetName)/Sources/**"],
	resources: ["\(targetName)/Resources/**"],
	entitlements: .dictionary([
		"com.apple.security.application-groups": .array([.string(appGroupIdentifier)])
	]),
	scripts: [
		.swiftlint,
		.setVersions
	],
	dependencies: [
		.target(core),
		.target(design),
		.target(example),
		.target(onboarding),
		.target(about),
		.target(settings),
		.target(resources),
		.target(keyboardUI),
		.target(keyboardExtension)
	],
	settings: .settings(
		base: [
			"ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
		]
	)
)
