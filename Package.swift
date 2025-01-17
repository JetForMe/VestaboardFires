// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "Fires",
	platforms: [
		.macOS(.v13)
	],
	dependencies:
	[
		.package(url: "https://github.com/apple/swift-argument-parser.git",			from: "1.5.0"),
		.package(url: "https://github.com/swiftlang/swift-testing.git",				from: "6.0.3")
	],
	targets: [
		.executableTarget(
			name: "Fires",
			dependencies:
			[
				.product(name: "ArgumentParser", package: "swift-argument-parser")
			]
		),
//		.testTarget(name: "Tests",
//					dependencies:
//					[
//						"Fires",
//						.product(name: "Testing", package: "swift-testing")
//					])
	]
)
