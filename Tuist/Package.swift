// swift-tools-version: 6.0
@preconcurrency import PackageDescription

let package = Package(
	name: "PackageName",
	dependencies: [
		.package(
			url: "https://github.com/freed0m266/BaseKitX",
			from: "1.4.0"
		),
		.package(
			url: "https://github.com/SwiftyBeaver/SwiftyBeaver",
			from: "2.1.0"
		),
		.package(
			url: "https://github.com/pointfreeco/swift-snapshot-testing",
			from: "1.18.4"
		),
		.package(
			url: "https://github.com/AckeeCZ/ACKategories",
			from: "6.16.0"
		)
	]
)
