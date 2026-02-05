// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "discard-self-availability",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "discard-self-availability",
            swiftSettings: [
                .enableExperimentalFeature("RawLayout")
            ]
        )
    ]
)
