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
            name: "Storage Dynamic Primitives",
            targets: ["Storage Dynamic Primitives"]
        ),
        .library(
            name: "Storage Static Primitives",
            targets: ["Storage Static Primitives"]
        ),
        .library(
            name: "Storage Primitives Test Support",
            targets: ["Storage Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-pointer-primitives"),
        .package(path: "../swift-property-primitives"),
        .package(path: "../swift-range-primitives"),
    ],
    targets: [
        // Core: Type declarations and fundamental access
        .target(
            name: "Storage Primitives Core",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Pointer Primitives", package: "swift-pointer-primitives"),
                .product(name: "Range Primitives", package: "swift-range-primitives"),
            ]
        ),
        // Dynamic: Bulk operations on heap storage
        .target(
            name: "Storage Dynamic Primitives",
            dependencies: [
                "Storage Primitives Core",
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Range Primitives", package: "swift-range-primitives"),
            ]
        ),
        // Static: Inline storage operations
        .target(
            name: "Storage Static Primitives",
            dependencies: [
                "Storage Primitives Core",
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Range Primitives", package: "swift-range-primitives"),
            ]
        ),
        // Public: Re-exports all modules
        .target(
            name: "Storage Primitives",
            dependencies: [
                "Storage Primitives Core",
                "Storage Dynamic Primitives",
                "Storage Static Primitives",
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
            name: "Storage Primitives Core Tests",
            dependencies: [
                .target(name: "Storage Primitives Core"),
                .target(name: "Storage Primitives Test Support")
            ]
        ),
        .testTarget(
            name: "Storage Dynamic Primitives Tests",
            dependencies: [
                .target(name: "Storage Dynamic Primitives"),
                .target(name: "Storage Primitives Test Support")
            ]
        ),
        .testTarget(
            name: "Storage Static Primitives Tests",
            dependencies: [
                .target(name: "Storage Static Primitives"),
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
