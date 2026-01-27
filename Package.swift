// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-storage-primitives",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "Storage Primitives",
            targets: ["Storage Primitives"]
        ),
        .library(
            name: "Storage Primitives Test Support",
            targets: ["Storage Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-pointer-primitives"),
        .package(path: "../swift-range-primitives"),
    ],
    targets: [
        .target(
            name: "Storage Primitives",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Pointer Primitives", package: "swift-pointer-primitives"),
                .product(name: "Range Primitives", package: "swift-range-primitives"),
            ]
        ),
        .target(
            name: "Storage Primitives Test Support",
            dependencies: [
                "Storage Primitives",
                .product(name: "Pointer Primitives Test Support", package: "swift-pointer-primitives"),
            ],
            path: "Tests/Support"
        ),
        .testTarget(
            name: "Storage Primitives Tests",
            dependencies: [
                .target(name: "Storage Primitives"),
                .target(name: "Storage Primitives Test Support")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .strictMemorySafety()
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
