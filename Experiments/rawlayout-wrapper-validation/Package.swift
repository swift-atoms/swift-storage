// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "rawlayout-wrapper-validation",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "rawlayout-wrapper-validation",
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
            ]
        )
    ]
)
