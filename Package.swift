// swift-tools-version: 6.2
import PackageDescription

let package = Package(
	name: "Cycle",
	platforms: [.macOS(.v26)],
	dependencies: [
		// RiftCore: the layout tree, geometry and drop zones behind drag-to-tile.
		.package(
			url: "https://github.com/zmscode/Rift.git",
			revision: "a7143ddd2d80f91a866158103ee5d0ba8877dc4a")
	],
	targets: [
		.executableTarget(
			name: "Cycle",
			dependencies: [.product(name: "RiftCore", package: "Rift")],
			path: "Sources/Cycle",
			swiftSettings: [.swiftLanguageMode(.v5)]
		)
	]
)
