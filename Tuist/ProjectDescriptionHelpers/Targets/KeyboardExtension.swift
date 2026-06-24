import ProjectDescription

private let targetName = "KeyboardExtension"

public let keyboardExtension: Target = .target(
	name: targetName,
	destinations: [.iPhone],
	product: .appExtension,
	bundleId: "\(appBundleId).keyboard",
	infoPlist: .extendingDefault(with: [
		"CFBundleDisplayName": "Keymoji",
		"NSExtension": [
			"NSExtensionPointIdentifier": "com.apple.keyboard-service",
			"NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).KeyboardViewController",
			"NSExtensionAttributes": [
				"IsASCIICapable": false,
				"PrefersRightToLeft": false,
				// "mul" (ISO 639 "multiple languages") makes the system keyboard switcher label the
				// keyboard "Multiple languages" instead of "English". This is compile-time only (iOS
				// reads it at registration), so it can't track the in-app accent choice. It no longer
				// feeds word completion — the completion language is resolved from the accent set
				// (accent → device → English; task 78, ADR 0002), not from this static tag.
				"PrimaryLanguage": "mul",
				"RequestsOpenAccess": true
			]
		]
	]),
	sources: "\(targetName)/Sources/**",
	entitlements: .dictionary([
		"com.apple.security.application-groups": .array([.string(appGroupIdentifier)]),
		"keychain-access-groups": .array([.string(keychainSharedAccessGroup)])
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
