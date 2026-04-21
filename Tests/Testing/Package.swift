// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "testing",
    platforms: [
        .macOS(.v26),
    ],
    dependencies: [
        .package(path: "../.."),
        .package(path: "../../../../swift-foundations/swift-testing"),
    ],
    targets: [
        .testTarget(
            name: "Storage Heap Performance Tests",
            dependencies: [
                .product(name: "Storage Heap Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Primitives Test Support", package: "swift-storage-primitives"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "Storage Inline Performance Tests",
            dependencies: [
                .product(name: "Storage Inline Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Primitives Test Support", package: "swift-storage-primitives"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "Storage Pool Performance Tests",
            dependencies: [
                .product(name: "Storage Pool Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Primitives Test Support", package: "swift-storage-primitives"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "Storage Arena Performance Tests",
            dependencies: [
                .product(name: "Storage Arena Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Primitives Test Support", package: "swift-storage-primitives"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "Storage Pool Inline Performance Tests",
            dependencies: [
                .product(name: "Storage Pool Inline Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Primitives Test Support", package: "swift-storage-primitives"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "Storage Arena Inline Performance Tests",
            dependencies: [
                .product(name: "Storage Arena Inline Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Primitives Test Support", package: "swift-storage-primitives"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "Storage Slab Performance Tests",
            dependencies: [
                .product(name: "Storage Slab Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Primitives Test Support", package: "swift-storage-primitives"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "Storage Split Performance Tests",
            dependencies: [
                .product(name: "Storage Split Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Primitives Test Support", package: "swift-storage-primitives"),
                .product(name: "Testing", package: "swift-testing"),
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
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
