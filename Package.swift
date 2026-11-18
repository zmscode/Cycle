// swift-tools-version: 6.2
import PackageDescription

let package = Package(
	name: "Cycle",
	platforms: [.macOS(.v26)],
	targets: [
		.executableTarget(
			name: "Cycle",
			path: "Sources/Cycle",
			swiftSettings: [.swiftLanguageMode(.v5)]
		),
	]
)
