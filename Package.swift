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
        .library(name: "Storage", targets: ["Storage"]),

        .library(name: "Storage Foundation Integration", targets: ["Storage Foundation Integration"]),
        .library(name: "Storage Test Support", targets: ["Storage Test Support"]),
    ],
    traits: [
        .trait(name: "Generational", description: "Generational integration"),
        .trait(name: "Memory", description: "Memory integration"),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-atoms/swift-buffer.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-memory-allocation.git", branch: "main", traits: [.trait(name: "MemorySmall", condition: .when(traits: ["Memory"])), .trait(name: "MemoryInline", condition: .when(traits: ["Memory"])), .trait(name: "MemoryAllocatorArena", condition: .when(traits: ["Memory"]))]),
        .package(url: "https://github.com/swift-atoms/swift-span.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-carrier.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-tagged.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-index.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-cardinal.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-ordinal.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-store.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-memory.git", branch: "main"),
    ],
    targets: [
        .testTarget(
            name: "Absorbed swift-storage-memory Tests",
            dependencies: [
                .product(name: "Cardinal", package: "swift-cardinal", condition: .when(traits: ["Memory"])),
                .product(name: "Index", package: "swift-index", condition: .when(traits: ["Memory"])),
                .product(name: "Memory Allocator", package: "swift-memory-allocation", condition: .when(traits: ["Memory"])),
                .product(name: "Memory Small", package: "swift-memory-allocation", condition: .when(traits: ["Memory"])),
                .product(name: "Memory", package: "swift-memory", condition: .when(traits: ["Memory"])),
                .product(name: "Ordinal", package: "swift-ordinal", condition: .when(traits: ["Memory"])),
                .product(name: "Store", package: "swift-store", condition: .when(traits: ["Memory"])),
                .product(name: "Tagged", package: "swift-tagged", condition: .when(traits: ["Memory"])),
                .target(name: "Storage", condition: .when(traits: ["Memory"])),
            ],
            path: "Tests/Absorbed swift-storage-memory Tests"
        ),
        .testTarget(
            name: "Absorbed swift-storage-generational Tests",
            dependencies: [
                .product(name: "Cardinal", package: "swift-cardinal", condition: .when(traits: ["Generational"])),
                .product(name: "Index", package: "swift-index", condition: .when(traits: ["Generational"])),
                .product(name: "Memory Allocator Pool", package: "swift-memory-allocation", condition: .when(traits: ["Generational"])),
                .product(name: "Memory Allocator", package: "swift-memory-allocation", condition: .when(traits: ["Generational"])),
                .product(name: "Memory", package: "swift-memory", condition: .when(traits: ["Generational"])),
                .product(name: "Ordinal", package: "swift-ordinal", condition: .when(traits: ["Generational"])),
                .product(name: "Store", package: "swift-store", condition: .when(traits: ["Generational"])),
                .product(name: "Tagged", package: "swift-tagged", condition: .when(traits: ["Generational"])),
                .target(name: "Storage", condition: .when(traits: ["Generational"])),
            ],
            path: "Tests/Absorbed swift-storage-generational Tests"
        ),
        .target(
            name: "Storage",
            dependencies: [
                .product(name: "Buffer", package: "swift-buffer", condition: .when(traits: ["Generational"])),
                .product(name: "Cardinal", package: "swift-cardinal", condition: .when(traits: ["Generational", "Memory"])),
                .product(name: "Carrier", package: "swift-carrier", condition: .when(traits: ["Memory"])),
                .product(name: "Index", package: "swift-index", condition: .when(traits: ["Generational", "Memory"])),
                .product(name: "Memory Allocator Pool", package: "swift-memory-allocation", condition: .when(traits: ["Generational"])),
                .product(name: "Memory Allocator Protocol", package: "swift-memory-allocation", condition: .when(traits: ["Memory"])),
                .product(name: "Memory Allocator", package: "swift-memory-allocation", condition: .when(traits: ["Generational", "Memory"])),
                .product(name: "Memory Pool", package: "swift-memory-allocation", condition: .when(traits: ["Generational"])),
                .product(name: "Memory", package: "swift-memory", condition: .when(traits: ["Generational", "Memory"])),
                .product(name: "Ordinal", package: "swift-ordinal", condition: .when(traits: ["Generational", "Memory"])),
                .product(name: "Span", package: "swift-span", condition: .when(traits: ["Memory"])),
                .product(name: "Store", package: "swift-store", condition: .when(traits: ["Generational", "Memory"])),
                .product(name: "Tagged", package: "swift-tagged", condition: .when(traits: ["Generational", "Memory"])),
            ],
            path: "Sources/Storage"
        ),

        .target(
            name: "Storage Foundation Integration",
            dependencies: [
                .target(name: "Storage"),
            ],
            path: "Sources/Storage Foundation Integration"
        ),
        .target(
            name: "Storage Test Support",
            dependencies: [
                .target(name: "Storage"),
            ],
            path: "Tests/Support"
        ),
        .testTarget(
            name: "Storage Tests",
            dependencies: [
                .target(name: "Storage"),
                .target(name: "Storage Test Support"),
                .target(name: "Storage Foundation Integration"),
            ],
            path: "Tests/Storage Tests"
        ),

        .testTarget(name: "Decision Column Integration Tests", dependencies: [.target(name: "Storage", condition: .when(traits: ["Generational"])), .product(name: "Memory Allocator Pool", package: "swift-memory-allocation", condition: .when(traits: ["Generational"])), .product(name: "Memory Allocator", package: "swift-memory-allocation", condition: .when(traits: ["Generational"])), .product(name: "Memory", package: "swift-memory", condition: .when(traits: ["Generational"]))], path: "Tests/Decision Column Integration Tests"),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets {
    target.swiftSettings = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]
}
