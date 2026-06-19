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
				// reads it at registration), so it can't track the in-app accent choice. It stays the
				// completion base via `currentLanguage`; `UITextCheckerAdapter.resolveLanguage` remaps
				// the unsupported "mul" tag to English, so completions are unaffected (task 65).
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
