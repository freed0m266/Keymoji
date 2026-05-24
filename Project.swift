import ProjectDescription
import ProjectDescriptionHelpers

let features: [Feature] = [
	example,
	onboarding,
	about,
	settings
]
let appTargets: [Target] = features.flatMap(\.allTargets)

let project = Project(
	name: "Keybo",
	organizationName: "Freedom Martin, s.r.o.",
	options: .options(
		developmentRegion: "en"
	),
	settings: .settings(
		base: [
			"SWIFT_VERSION": "6.0",
			"IPHONEOS_DEPLOYMENT_TARGET": "26.0",
			"TARGETED_DEVICE_FAMILY": "1",
			"DEVELOPMENT_TEAM": "DSKL7YS6PW",
			"CODE_SIGN_STYLE": "Automatic",
			"DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
			"CODE_SIGN_ALLOW_ENTITLEMENTS_MODIFICATION": "YES"
		],
		configurations: [
			.debug(name: "Debug"),
			.release(name: "Release"),
		]
	),
	targets: [
		app,
		core,
		coreTests,
		design,
		resources,
		testing,
		keyboardCore,
		keyboardCoreTests,
		keyboardUI,
		keyboardUITests,
		keyboardExtension
	]
	+ appTargets,
	schemes: [
		.scheme(
			name: "Keybo",
			buildAction: .buildAction(
				targets: ["Keybo", "KeyboardExtension"]
			),
			runAction: .runAction(
				executable: .executable("Keybo"),
				arguments: .arguments(
					environmentVariables: [
						"OS_ACTIVITY_MODE": "disable",
					]
				)
			),
			archiveAction: .archiveAction(
				configuration: "Release"
			),
			profileAction: .profileAction(
				configuration: "Release", executable: .executable("Keybo")
			)
		)
	]
)
