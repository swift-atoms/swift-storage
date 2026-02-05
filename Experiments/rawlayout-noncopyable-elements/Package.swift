// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "rawlayout-noncopyable-elements",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-index-primitives")
    ],
    targets: [
        .executableTarget(
            name: "rawlayout-noncopyable-elements",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives")
            ],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout")
            ]
        )
    ]
)
