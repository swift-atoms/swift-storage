// swift-tools-version: 6.3.1

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
        // MARK: - Namespace (hosts the Storage<Allocation> carrier + the Contiguous primary body)
        .library(name: "Storage Primitive", targets: ["Storage Primitive"]),

        // MARK: - Seam derivations (generic algorithms over the convenience Store.Protocol seam)
        .library(name: "Storage Protocol Primitives", targets: ["Storage Protocol Primitives"]),

        // MARK: - Canonical storage forms
        .library(name: "Storage Contiguous Primitives", targets: ["Storage Contiguous Primitives"]),

        // MARK: - Inline column (Store.Inline — Allocation-independent, on the Store namespace)
        .library(name: "Store Inline Primitives", targets: ["Store Inline Primitives"]),

        // MARK: - Umbrella
        .library(name: "Storage Primitives", targets: ["Storage Primitives"]),

        // MARK: - Test Support
        .library(name: "Storage Primitives Test Support", targets: ["Storage Primitives Test Support"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-finite-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-affine-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-ordinal-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-property-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-range-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-bit-vector-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-span-primitives.git", branch: "main"),
        // Storage/memory split + the W2 allocator tier (element-free allocations).
        .package(url: "https://github.com/swift-primitives/swift-store-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-heap-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-allocation-primitives.git", branch: "main"),
    ],
    targets: [

        // MARK: - Namespace (per [MOD-017]) — the generic Storage<Allocation> carrier + Contiguous
        // primary body (6.3.2 mechanic #1: the nested deinit-bearing product is declared here).
        .target(
            name: "Storage Primitive",
            dependencies: []
        ),

        // MARK: - Protocol (Cleave-5: marker dissolved; hosts the single-region lifecycle
        // derivations as `extension Store.Protocol` — Allocation-independent, pure 4-op seam)
        .target(
            name: "Storage Protocol Primitives",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Store Protocol Primitives", package: "swift-store-primitives"),
                .product(name: "Affine Primitives", package: "swift-affine-primitives"),
            ]
        ),

        // MARK: - Contiguous (the dense column — Storage<Allocation>.Contiguous<Element>)
        .target(
            name: "Storage Contiguous Primitives",
            dependencies: [
                "Storage Primitive",
                .product(name: "Memory Primitive", package: "swift-memory-primitives"),
                .product(name: "Memory Region Primitives", package: "swift-memory-primitives"),
                .product(name: "Memory Address Primitives", package: "swift-memory-primitives"),
                .product(name: "Memory Alignment Primitives", package: "swift-memory-primitives"),
                .product(name: "Memory Primitives Standard Library Integration", package: "swift-memory-primitives"),
                .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Store Initialization Primitives", package: "swift-store-primitives"),
                .product(name: "Store Protocol Primitives", package: "swift-store-primitives"),
                .product(name: "Span Protocol Primitives", package: "swift-span-primitives"),
                .product(name: "Affine Primitives Standard Library Integration", package: "swift-affine-primitives"),
                .product(name: "Ordinal Primitives Standard Library Integration", package: "swift-ordinal-primitives"),
            ]
        ),

        // MARK: - Inline column (Store.Inline — fixed-capacity inline typed storage)
        .target(
            name: "Store Inline Primitives",
            dependencies: [
                .product(name: "Store Primitive", package: "swift-store-primitives"),
                .product(name: "Store Protocol Primitives", package: "swift-store-primitives"),
                .product(name: "Store Initialization Primitives", package: "swift-store-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Affine Primitives Standard Library Integration", package: "swift-affine-primitives"),
                .product(name: "Ordinal Primitives Standard Library Integration", package: "swift-ordinal-primitives"),
            ]
        ),

        // MARK: - Umbrella
        .target(
            name: "Storage Primitives",
            dependencies: [
                "Storage Primitive",
                "Storage Protocol Primitives",
                "Storage Contiguous Primitives",
                "Store Inline Primitives",
            ]
        ),

        // MARK: - Test Support
        .target(
            name: "Storage Primitives Test Support",
            dependencies: [
                "Storage Primitives",
                .product(name: "Memory Primitives Test Support", package: "swift-memory-primitives"),
            ],
            path: "Tests/Support"
        ),

        // MARK: - Tests
        .testTarget(
            name: "Storage Contiguous Primitives Tests",
            dependencies: [
                "Storage Contiguous Primitives",
                "Storage Primitives Test Support",
            ]
        ),
        .testTarget(
            name: "Store Inline Primitives Tests",
            dependencies: [
                "Store Inline Primitives",
            ]
        ),
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
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = [
        .enableExperimentalFeature("RawLayout"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
