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
            name: "Storage Primitives Core",
            targets: ["Storage Primitives Core"]
        ),
        .library(
            name: "Storage Heap Primitives",
            targets: ["Storage Heap Primitives"]
        ),
        .library(
            name: "Storage Inline Primitives",
            targets: ["Storage Inline Primitives"]
        ),
        .library(
            name: "Storage Primitives Test Support",
            targets: ["Storage Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-range-primitives"),
        .package(path: "../swift-memory-primitives"),
    ],
    targets: [
        // Core: Type declarations and fundamental access
        .target(
            name: "Storage Primitives Core",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Range Primitives", package: "swift-range-primitives"),
                .product(name: "Memory Primitives Core", package: "swift-memory-primitives"),
            ]
        ),
        // Heap: Bulk operations on heap storage
        .target(
            name: "Storage Heap Primitives",
            dependencies: [
                "Storage Primitives Core",
            ]
        ),
        // Inline: Inline storage operations
        .target(
            name: "Storage Inline Primitives",
            dependencies: [
                "Storage Primitives Core",
            ]
        ),
        // Public: Re-exports all modules
        .target(
            name: "Storage Primitives",
            dependencies: [
                "Storage Primitives Core",
                "Storage Heap Primitives",
                "Storage Inline Primitives",
            ]
        ),
        .target(
            name: "Storage Primitives Test Support",
            dependencies: [
                "Storage Primitives",
                .product(name: "Memory Primitives Test Support", package: "swift-memory-primitives"),
            ],
            path: "Tests/Support"
        ),
        .testTarget(
            name: "Storage Primitives Core Tests",
            dependencies: [
                .target(name: "Storage Primitives Core"),
                .target(name: "Storage Primitives Test Support")
            ]
        ),
        .testTarget(
            name: "Storage Heap Primitives Tests",
            dependencies: [
                .target(name: "Storage Heap Primitives"),
                .target(name: "Storage Primitives Test Support")
            ]
        ),
        .testTarget(
            name: "Storage Inline Primitives Tests",
            dependencies: [
                .target(name: "Storage Inline Primitives"),
                .target(name: "Storage Primitives Test Support")
            ]
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
