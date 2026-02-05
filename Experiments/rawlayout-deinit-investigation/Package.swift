// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "rawlayout-deinit-investigation",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "rawlayout-deinit-investigation",
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
            ]
        )
    ]
)
