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
        // MARK: - Namespace + sub-namespace targets (per [MOD-031])
        .library(name: "Storage Primitive", targets: ["Storage Primitive"]),
        .library(name: "Storage Error Primitives", targets: ["Storage Error Primitives"]),
        .library(name: "Storage Initialization Primitives", targets: ["Storage Initialization Primitives"]),
        .library(name: "Storage Field Primitives", targets: ["Storage Field Primitives"]),
        .library(name: "Storage Accessor Primitives", targets: ["Storage Accessor Primitives"]),
        .library(name: "Storage Protocol Primitives", targets: ["Storage Protocol Primitives"]),

        // MARK: - Canonical storage forms (retained per Cohort II precedent; cf. Memory.Inline)
        .library(name: "Storage Heap Primitives", targets: ["Storage Heap Primitives"]),
        .library(name: "Storage Inline Primitives", targets: ["Storage Inline Primitives"]),
        .library(name: "Storage Contiguous Primitives", targets: ["Storage Contiguous Primitives"]),

        // MARK: - Umbrella
        .library(name: "Storage Primitives", targets: ["Storage Primitives"]),

        // MARK: - Test Support
        .library(name: "Storage Primitives Test Support", targets: ["Storage Primitives Test Support"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-finite-primitives.git", branch: "main"),
        // W2 mesh: resolve memory against the W2 worktree (Memory.Contiguous conforms Span.Protocol).
        // Path-dep identity is the directory basename `swift-memory-primitives`.
        .package(url: "https://github.com/swift-primitives/swift-memory-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-affine-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-property-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-range-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-bit-vector-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-standard-library-extensions.git", branch: "main"),
        // W2 neutral substrate packages.
        .package(url: "https://github.com/swift-primitives/swift-span-primitives.git", branch: "main"),
        // Storage/memory split — HOLD path-deps (publication-gate flip to url; the
        // .split-wt canonical-basename mesh carries the arc branches):
        .package(path: "../swift-store-primitives"),
        .package(path: "../swift-memory-heap-primitives"),
    ],
    targets: [

        // MARK: - Namespace (per [MOD-017])
        .target(
            name: "Storage Primitive",
            dependencies: []
        ),

        // MARK: - Error
        .target(
            name: "Storage Error Primitives",
            dependencies: [
                "Storage Primitive",
            ]
        ),

        // MARK: - Initialization (SHIM — the ledger relocated to Store.Initialization,
        // storage-memory-split.md §2; this target keeps the import + spelling stable)
        .target(
            name: "Storage Initialization Primitives",
            dependencies: [
                "Storage Primitive",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Store Initialization Primitives", package: "swift-store-primitives"),
            ]
        ),

        // MARK: - Field (layout truth)
        .target(
            name: "Storage Field Primitives",
            dependencies: [
                "Storage Primitive",
                .product(name: "Memory Address Primitives", package: "swift-memory-primitives"),
                .product(name: "Affine Primitives", package: "swift-affine-primitives"),
            ]
        ),

        // MARK: - Accessor tags
        .target(
            name: "Storage Accessor Primitives",
            dependencies: [
                "Storage Primitive",
            ]
        ),

        // MARK: - Protocol (discipline contract — post-split: the pure marker refinement
        // of Store.Tracked.Protocol; consumer-visible requirement set unchanged)
        .target(
            name: "Storage Protocol Primitives",
            dependencies: [
                "Storage Primitive",
                "Storage Initialization Primitives",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Store Protocol Primitives", package: "swift-store-primitives"),
                .product(name: "Store Tracked Primitives", package: "swift-store-primitives"),
            ]
        ),

        // MARK: - Heap (canonical heap-backed storage form)
        .target(
            name: "Storage Heap Primitives",
            dependencies: [
                "Storage Primitive",
                "Storage Error Primitives",
                "Storage Initialization Primitives",
                "Storage Accessor Primitives",
                "Storage Contiguous Primitives",
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        ),

        // MARK: - Inline (canonical inline-backed storage form)
        .target(
            name: "Storage Inline Primitives",
            dependencies: [
                "Storage Primitive",
                "Storage Error Primitives",
                "Storage Initialization Primitives",
                "Storage Accessor Primitives",
                "Storage Protocol Primitives",
                "Storage Heap Primitives",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Finite Bounded Primitives", package: "swift-finite-primitives"),
                .product(name: "Memory Address Primitives", package: "swift-memory-primitives"),
                .product(name: "Memory Alignment Primitives", package: "swift-memory-primitives"),
                .product(name: "Memory Contiguous Primitives", package: "swift-memory-primitives"),
                .product(name: "Memory Primitives Standard Library Integration", package: "swift-memory-primitives"),
                .product(name: "Span Protocol Primitives", package: "swift-span-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Range Primitives", package: "swift-range-primitives"),
                .product(name: "Bit Vector Static Primitives", package: "swift-bit-vector-primitives"),
            ]
        ),

        // MARK: - Contiguous (substrate-lifting storage discipline; the #2 Flat rename — storage-memory-split.md)
        .target(
            name: "Storage Contiguous Primitives",
            dependencies: [
                "Storage Primitive",
                "Storage Protocol Primitives",
                "Storage Initialization Primitives",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Store Protocol Primitives", package: "swift-store-primitives"),
                .product(name: "Store Tracked Primitives", package: "swift-store-primitives"),
                .product(name: "Span Protocol Primitives", package: "swift-span-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                "Storage Accessor Primitives",
                "Storage Error Primitives",
            ]
        ),

        // MARK: - Umbrella
        .target(
            name: "Storage Primitives",
            dependencies: [
                "Storage Primitive",
                "Storage Error Primitives",
                "Storage Initialization Primitives",
                "Storage Field Primitives",
                "Storage Accessor Primitives",
                "Storage Protocol Primitives",
                "Storage Heap Primitives",
                "Storage Inline Primitives",
                "Storage Contiguous Primitives",
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
            name: "Storage Primitives Substrate Tests",
            dependencies: [
                "Storage Primitive",
                "Storage Error Primitives",
                "Storage Initialization Primitives",
                "Storage Field Primitives",
                "Storage Accessor Primitives",
                "Storage Primitives Test Support",
            ]
        ),
        .testTarget(
            name: "Storage Heap Primitives Tests",
            dependencies: [
                "Storage Heap Primitives",
                "Storage Primitives Test Support",
            ]
        ),
        .testTarget(
            name: "Storage Inline Primitives Tests",
            dependencies: [
                "Storage Inline Primitives",
                "Storage Heap Primitives",
                "Storage Primitives Test Support",
                .product(name: "Finite Bounded Primitives", package: "swift-finite-primitives"),
            ]
        ),
        .testTarget(
            name: "Storage Primitives Tests",
            dependencies: [
                "Storage Primitives",
                "Storage Primitives Test Support",
            ]
        ),
        .testTarget(
            name: "Storage Contiguous Primitives Tests",
            dependencies: [
                "Storage Contiguous Primitives",
                "Storage Heap Primitives",
                "Storage Primitives Test Support",
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
