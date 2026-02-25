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
            name: "Storage Pool Primitives",
            targets: ["Storage Pool Primitives"]
        ),
        .library(
            name: "Storage Arena Primitives",
            targets: ["Storage Arena Primitives"]
        ),
        .library(
            name: "Storage Pool Inline Primitives",
            targets: ["Storage Pool Inline Primitives"]
        ),
        .library(
            name: "Storage Arena Inline Primitives",
            targets: ["Storage Arena Inline Primitives"]
        ),
        .library(
            name: "Storage Slab Primitives",
            targets: ["Storage Slab Primitives"]
        ),
        .library(
            name: "Storage Split Primitives",
            targets: ["Storage Split Primitives"]
        ),
        .library(
            name: "Storage Primitives Test Support",
            targets: ["Storage Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-memory-primitives"),
        .package(path: "../swift-property-primitives"),
        .package(path: "../swift-vector-primitives"),
        .package(path: "../swift-standard-library-extensions"),
        .package(path: "../swift-bit-vector-primitives"),
        .package(path: "../swift-finite-primitives"),
    ],
    targets: [
        // Core: Type declarations and fundamental access
        .target(
            name: "Storage Primitives Core",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
                .product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),
                .product(name: "Finite Primitives", package: "swift-finite-primitives"),
            ]
        ),
        // Heap: Bulk operations on heap storage
        .target(
            name: "Storage Heap Primitives",
            dependencies: [
                "Storage Primitives Core",
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
            ]
        ),
        // Inline: Inline storage operations
        .target(
            name: "Storage Inline Primitives",
            dependencies: [
                "Storage Primitives Core",
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Vector Primitives", package: "swift-vector-primitives"),
            ]
        ),
        // Pool: Fixed-capacity pool allocation with per-slot reuse
        .target(
            name: "Storage Pool Primitives",
            dependencies: [
                "Storage Primitives Core",
                .product(name: "Memory Pool Primitives", package: "swift-memory-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Finite Primitives", package: "swift-finite-primitives"),
            ]
        ),
        // Arena: Bump-allocated typed storage with bulk reset
        .target(
            name: "Storage Arena Primitives",
            dependencies: [
                "Storage Primitives Core",
                .product(name: "Memory Arena Primitives", package: "swift-memory-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Finite Primitives", package: "swift-finite-primitives"),
            ]
        ),
        // Pool Inline: Inline pool storage with bounded capacity
        .target(
            name: "Storage Pool Inline Primitives",
            dependencies: [
                "Storage Primitives Core",
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),
                .product(name: "Finite Primitives", package: "swift-finite-primitives"),
            ]
        ),
        // Arena Inline: Inline arena storage with bounded capacity
        .target(
            name: "Storage Arena Inline Primitives",
            dependencies: [
                "Storage Primitives Core",
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),
                .product(name: "Finite Primitives", package: "swift-finite-primitives"),
            ]
        ),
        // Slab: Bitmap-tracked heap storage for sparse data structures
        .target(
            name: "Storage Slab Primitives",
            dependencies: [
                "Storage Primitives Core",
                "Storage Heap Primitives",
                .product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),
            ]
        ),
        // Split: Metadata-driven dual-lane storage
        .target(
            name: "Storage Split Primitives",
            dependencies: [
                "Storage Primitives Core",
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        ),
        // Public: Re-exports all modules
        .target(
            name: "Storage Primitives",
            dependencies: [
                "Storage Primitives Core",
                "Storage Heap Primitives",
                "Storage Inline Primitives",
                "Storage Pool Primitives",
                "Storage Pool Inline Primitives",
                "Storage Arena Primitives",
                "Storage Arena Inline Primitives",
                "Storage Slab Primitives",
                "Storage Split Primitives",
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
                .target(name: "Storage Primitives Core"),
                .target(name: "Storage Inline Primitives"),
                .target(name: "Storage Primitives Test Support")
            ]
        ),
        .testTarget(
            name: "Storage Pool Primitives Tests",
            dependencies: [
                .target(name: "Storage Pool Primitives"),
                .target(name: "Storage Primitives Test Support")
            ]
        ),
        .testTarget(
            name: "Storage Arena Primitives Tests",
            dependencies: [
                .target(name: "Storage Arena Primitives"),
                .target(name: "Storage Primitives Test Support")
            ]
        ),
        .testTarget(
            name: "Storage Pool Inline Primitives Tests",
            dependencies: [
                .target(name: "Storage Pool Inline Primitives"),
                .target(name: "Storage Primitives Test Support")
            ]
        ),
        .testTarget(
            name: "Storage Arena Inline Primitives Tests",
            dependencies: [
                .target(name: "Storage Arena Inline Primitives"),
                .target(name: "Storage Primitives Test Support")
            ]
        ),
        .testTarget(
            name: "Storage Split Primitives Tests",
            dependencies: [
                .target(name: "Storage Split Primitives"),
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
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
    ]

    let package: [SwiftSetting] = [
        .enableExperimentalFeature("RawLayout"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
