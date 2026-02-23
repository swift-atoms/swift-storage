// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "escapable-deinit-lifetime",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "escapable-deinit-lifetime",
            swiftSettings: [
                .strictMemorySafety(),
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
