// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-storage",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [

        .library(name: "Store Primitive", targets: ["Store Primitive"]),
        .library(name: "Store Protocol", targets: ["Store Protocol"]),
        .library(
            name: "Store Initialization",
            targets: ["Store Initialization"]
        ),
        .library(name: "Store Ledgered", targets: ["Store Ledgered"]),
        .library(name: "Store", targets: ["Store"]),

        .library(name: "Storage Primitive", targets: ["Storage Primitive"]),

        .library(name: "Storage Protocol", targets: ["Storage Protocol"]),

        .library(name: "Storage Contiguous", targets: ["Storage Contiguous"]),

        .library(name: "Store Inline", targets: ["Store Inline"]),

        .library(name: "Storage", targets: ["Storage"]),

        .library(name: "Store Test Support", targets: ["Store Test Support"]),
        .library(
            name: "Storage Test Support",
            targets: ["Storage Test Support"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-molecules/swift-index.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-memory.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-affine.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-ordinal.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-span.git",
            branch: "main"
        ),

        .package(
            url: "https://github.com/swift-molecules/swift-memory-heap.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-memory-allocation.git",
            branch: "main"
        ),
    ],
    targets: [

        .target(
            name: "Store Primitive",
            dependencies: []
        ),

        .target(
            name: "Store Protocol",
            dependencies: [
                "Store Primitive",
                .product(name: "Index", package: "swift-index"),
            ]
        ),

        .target(
            name: "Store Initialization",
            dependencies: [
                "Store Primitive",
                .product(name: "Index", package: "swift-index"),
            ]
        ),

        .target(
            name: "Store Ledgered",
            dependencies: [
                "Store Primitive",
                "Store Protocol",
                "Store Initialization",
                .product(name: "Index", package: "swift-index"),
            ]
        ),

        .target(
            name: "Store",
            dependencies: [
                "Store Primitive",
                "Store Protocol",
                "Store Initialization",
                "Store Ledgered",
            ]
        ),

        .target(
            name: "Storage Primitive",
            dependencies: []
        ),

        .target(
            name: "Storage Protocol",
            dependencies: [
                .product(name: "Index", package: "swift-index"),
                "Store Protocol",
                .product(name: "Affine", package: "swift-affine"),
            ]
        ),

        .target(
            name: "Storage Contiguous",
            dependencies: [
                "Storage Primitive",
                .product(name: "Memory Primitive", package: "swift-memory"),
                .product(name: "Memory Region", package: "swift-memory"),
                .product(name: "Memory Address", package: "swift-memory"),
                .product(name: "Memory Alignment", package: "swift-memory"),
                .product(
                    name: "Memory Standard Library Integration",
                    package: "swift-memory"
                ),
                .product(
                    name: "Memory Allocator Primitive",
                    package: "swift-memory-allocation"
                ),
                .product(
                    name: "Memory Allocator Protocol",
                    package: "swift-memory-allocation"
                ),
                .product(name: "Memory Heap", package: "swift-memory-heap"),
                .product(name: "Index", package: "swift-index"),
                "Store Initialization",
                "Store Protocol",
                "Store Ledgered",
                .product(name: "Span Protocol", package: "swift-span"),
                .product(
                    name: "Affine Standard Library Integration",
                    package: "swift-affine"
                ),
                .product(
                    name: "Ordinal Standard Library Integration",
                    package: "swift-ordinal"
                ),
            ]
        ),

        .target(
            name: "Store Inline",
            dependencies: [
                "Store Primitive",
                "Store Protocol",
                "Store Initialization",
                "Store Ledgered",
                .product(name: "Index", package: "swift-index"),
                .product(
                    name: "Affine Standard Library Integration",
                    package: "swift-affine"
                ),
                .product(
                    name: "Ordinal Standard Library Integration",
                    package: "swift-ordinal"
                ),
            ]
        ),

        .target(
            name: "Storage",
            dependencies: [
                "Storage Primitive",
                "Storage Protocol",
                "Storage Contiguous",
                "Store Inline",
            ]
        ),

        .target(
            name: "Store Test Support",
            dependencies: [
                "Store",
                .product(name: "Index Test Support", package: "swift-index"),
            ],
            path: "Tests/Store Support"
        ),
        .target(
            name: "Storage Test Support",
            dependencies: [
                "Storage",
                .product(
                    name: "Memory Test Support",
                    package: "swift-memory"
                ),
            ],
            path: "Tests/Support"
        ),

        .testTarget(
            name: "Store Tests",
            dependencies: [
                "Store",
                "Store Test Support",
            ]
        ),
        .testTarget(
            name: "Storage Contiguous Tests",
            dependencies: [
                "Storage Contiguous",
                "Storage Test Support",
            ]
        ),
        .testTarget(
            name: "Store Inline Tests",
            dependencies: [
                "Store Inline"
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
