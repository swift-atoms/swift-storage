// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "deinit-guard-idempotence",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "deinit-guard-idempotence",
            swiftSettings: [
                .enableExperimentalFeature("RawLayout")
            ]
        )
    ]
)
