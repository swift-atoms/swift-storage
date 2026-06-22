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
        // MARK: - Seam namespace + protocol (consolidated from swift-store-primitives per [DS-027].3)
        // The seam protocol target is kept MINIMAL (index-only deps) so seam-only consumers compile
        // against the protocol alone.
        .library(name: "Store Primitive", targets: ["Store Primitive"]),
        .library(name: "Store Protocol Primitives", targets: ["Store Protocol Primitives"]),
        .library(name: "Store Initialization Primitives", targets: ["Store Initialization Primitives"]),
        .library(name: "Store Ledgered Primitives", targets: ["Store Ledgered Primitives"]),
        .library(name: "Store Primitives", targets: ["Store Primitives"]),

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
        .library(name: "Store Primitives Test Support", targets: ["Store Primitives Test Support"]),
        .library(name: "Storage Primitives Test Support", targets: ["Storage Primitives Test Support"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-affine-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-ordinal-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-span-primitives.git", branch: "main"),
        // The W2 allocator tier (element-free allocations). The store seam was consolidated INTO this
        // package per [DS-027].3 — no external swift-store-primitives dependency.
        .package(url: "https://github.com/swift-primitives/swift-memory-heap-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-allocation-primitives.git", branch: "main"),
    ],
    targets: [

        // MARK: - Store seam (consolidated from swift-store-primitives per [DS-027].3)

        // MARK: Namespace (per [MOD-017])
        .target(
            name: "Store Primitive",
            dependencies: []
        ),

        // MARK: Protocol (the neutral element-store capability seam) — MINIMAL: index-only deps,
        // so seam-only consumers compile against the protocol alone.
        .target(
            name: "Store Protocol Primitives",
            dependencies: [
                "Store Primitive",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ]
        ),

        // MARK: Initialization (the uninit↔init ledger vocabulary)
        .target(
            name: "Store Initialization Primitives",
            dependencies: [
                "Store Primitive",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ]
        ),

        // MARK: Ledgered (the settable-ledger refinement beside the seam — ASK-A, ratified 2026-06-10)
        .target(
            name: "Store Ledgered Primitives",
            dependencies: [
                "Store Primitive",
                "Store Protocol Primitives",
                "Store Initialization Primitives",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ]
        ),

        // MARK: Umbrella (store seam)
        .target(
            name: "Store Primitives",
            dependencies: [
                "Store Primitive",
                "Store Protocol Primitives",
                "Store Initialization Primitives",
                "Store Ledgered Primitives",
            ]
        ),

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
                "Store Protocol Primitives",
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
                .product(name: "Memory Allocator Protocol Primitives", package: "swift-memory-allocation-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                "Store Initialization Primitives",
                "Store Protocol Primitives",
                "Store Ledgered Primitives",
                .product(name: "Span Protocol Primitives", package: "swift-span-primitives"),
                .product(name: "Affine Primitives Standard Library Integration", package: "swift-affine-primitives"),
                .product(name: "Ordinal Primitives Standard Library Integration", package: "swift-ordinal-primitives"),
            ]
        ),

        // MARK: - Inline column (Store.Inline — fixed-capacity inline typed storage)
        .target(
            name: "Store Inline Primitives",
            dependencies: [
                "Store Primitive",
                "Store Protocol Primitives",
                "Store Initialization Primitives",
                "Store Ledgered Primitives",
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
            name: "Store Primitives Test Support",
            dependencies: [
                "Store Primitives",
                .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
            ],
            path: "Tests/Store Support"
        ),
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
            name: "Store Primitives Tests",
            dependencies: [
                "Store Primitives",
                "Store Primitives Test Support",
            ]
        ),
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
