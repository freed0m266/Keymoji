import ProjectDescription

private let targetName = "KeyboardExtension"

public let keyboardExtension: Target = .target(
	name: targetName,
	destinations: [.iPhone],
	product: .appExtension,
	bundleId: "\(appBundleId).keyboard",
	infoPlist: .extendingDefault(with: [
		"CFBundleDisplayName": "Keybo",
		"NSExtension": [
			"NSExtensionPointIdentifier": "com.apple.keyboard-service",
			"NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).KeyboardViewController",
			"NSExtensionAttributes": [
				"IsASCIICapable": false,
				"PrefersRightToLeft": false,
				"PrimaryLanguage": "en-US",
				"RequestsOpenAccess": true
			]
		]
	]),
	sources: "\(targetName)/Sources/**",
	entitlements: .dictionary([
		"com.apple.security.application-groups": .array([.string(appGroupIdentifier)])
	]),
	scripts: [
		.setVersions
	],
	dependencies: [
		.target(name: keyboardCore.name),
		.target(name: keyboardUI.name),
		.target(name: resources.name),
		.target(name: core.name)
	]
)
