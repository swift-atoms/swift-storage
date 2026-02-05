// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "rawlayout-deinit-crossmodule",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "StorageLib",
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
            ]
        ),
        .executableTarget(
            name: "Main",
            dependencies: ["StorageLib"]
        ),
        .testTarget(
            name: "StorageLibTests",
            dependencies: ["StorageLib"]
        )
    ]
)
