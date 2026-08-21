// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-storage-primitives",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [

        .library(name: "Store Primitive", targets: ["Store Primitive"]),
        .library(name: "Store Protocol Primitives", targets: ["Store Protocol Primitives"]),
        .library(
            name: "Store Initialization Primitives",
            targets: ["Store Initialization Primitives"]
        ),
        .library(name: "Store Ledgered Primitives", targets: ["Store Ledgered Primitives"]),
        .library(name: "Store Primitives", targets: ["Store Primitives"]),

        .library(name: "Storage Primitive", targets: ["Storage Primitive"]),

        .library(name: "Storage Protocol Primitives", targets: ["Storage Protocol Primitives"]),

        .library(name: "Storage Contiguous Primitives", targets: ["Storage Contiguous Primitives"]),

        .library(name: "Store Inline Primitives", targets: ["Store Inline Primitives"]),

        .library(name: "Storage Primitives", targets: ["Storage Primitives"]),

        .library(name: "Store Primitives Test Support", targets: ["Store Primitives Test Support"]),
        .library(
            name: "Storage Primitives Test Support",
            targets: ["Storage Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-primitives/swift-index-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-memory-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-affine-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-ordinal-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-span-primitives.git",
            branch: "main"
        ),

        .package(
            url: "https://github.com/swift-primitives/swift-memory-heap-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-memory-allocation-primitives.git",
            branch: "main"
        ),
    ],
    targets: [

        .target(
            name: "Store Primitive",
            dependencies: []
        ),

        .target(
            name: "Store Protocol Primitives",
            dependencies: [
                "Store Primitive",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ]
        ),

        .target(
            name: "Store Initialization Primitives",
            dependencies: [
                "Store Primitive",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ]
        ),

        .target(
            name: "Store Ledgered Primitives",
            dependencies: [
                "Store Primitive",
                "Store Protocol Primitives",
                "Store Initialization Primitives",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ]
        ),

        .target(
            name: "Store Primitives",
            dependencies: [
                "Store Primitive",
                "Store Protocol Primitives",
                "Store Initialization Primitives",
                "Store Ledgered Primitives",
            ]
        ),

        .target(
            name: "Storage Primitive",
            dependencies: []
        ),

        .target(
            name: "Storage Protocol Primitives",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                "Store Protocol Primitives",
                .product(name: "Affine Primitives", package: "swift-affine-primitives"),
            ]
        ),

        .target(
            name: "Storage Contiguous Primitives",
            dependencies: [
                "Storage Primitive",
                .product(name: "Memory Primitive", package: "swift-memory-primitives"),
                .product(name: "Memory Region Primitives", package: "swift-memory-primitives"),
                .product(name: "Memory Address Primitives", package: "swift-memory-primitives"),
                .product(name: "Memory Alignment Primitives", package: "swift-memory-primitives"),
                .product(
                    name: "Memory Primitives Standard Library Integration",
                    package: "swift-memory-primitives"
                ),
                .product(
                    name: "Memory Allocator Primitive",
                    package: "swift-memory-allocation-primitives"
                ),
                .product(
                    name: "Memory Allocator Protocol Primitives",
                    package: "swift-memory-allocation-primitives"
                ),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                "Store Initialization Primitives",
                "Store Protocol Primitives",
                "Store Ledgered Primitives",
                .product(name: "Span Protocol Primitives", package: "swift-span-primitives"),
                .product(
                    name: "Affine Primitives Standard Library Integration",
                    package: "swift-affine-primitives"
                ),
                .product(
                    name: "Ordinal Primitives Standard Library Integration",
                    package: "swift-ordinal-primitives"
                ),
            ]
        ),

        .target(
            name: "Store Inline Primitives",
            dependencies: [
                "Store Primitive",
                "Store Protocol Primitives",
                "Store Initialization Primitives",
                "Store Ledgered Primitives",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(
                    name: "Affine Primitives Standard Library Integration",
                    package: "swift-affine-primitives"
                ),
                .product(
                    name: "Ordinal Primitives Standard Library Integration",
                    package: "swift-ordinal-primitives"
                ),
            ]
        ),

        .target(
            name: "Storage Primitives",
            dependencies: [
                "Storage Primitive",
                "Storage Protocol Primitives",
                "Storage Contiguous Primitives",
                "Store Inline Primitives",
            ]
        ),

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
                .product(
                    name: "Memory Primitives Test Support",
                    package: "swift-memory-primitives"
                ),
            ],
            path: "Tests/Support"
        ),

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
                "Store Inline Primitives"
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
        .enableExperimentalFeature("Lifetimes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]

    let package: [SwiftSetting] = [
        .enableExperimentalFeature("RawLayout")
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
