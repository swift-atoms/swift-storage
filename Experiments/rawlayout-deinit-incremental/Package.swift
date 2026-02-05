// swift-tools-version: 6.2
// MARK: - Incremental Deinit Investigation
// Purpose: Add complexity to working experiment until deinit fails
// Hypothesis: One of the following causes deinit to not be called:
//   1. Module re-export (public import)
//   2. Complex generic types (Range<Index<Element>>)
//   3. Multi-module dependency structure
//   4. SwiftSettings (strictMemorySafety, InternalImportsByDefault, etc.)
//
// Toolchain: Swift 6.2 (Xcode 26)
// Platform: macOS 26 (arm64)
//
// Result: IN_PROGRESS
// Date: 2026-02-05

import PackageDescription

let package = Package(
    name: "rawlayout-deinit-incremental",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-index-primitives"),
        .package(path: "../../"),  // swift-storage-primitives itself
    ],
    targets: [
        // Variant 1: Single module (baseline - should pass)
        .target(
            name: "Variant1_Baseline",
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
            ]
        ),
        .testTarget(
            name: "Variant1_BaselineTests",
            dependencies: ["Variant1_Baseline"]
        ),

        // Variant 2: Add module split with public import
        .target(
            name: "Variant2_Core",
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
            ]
        ),
        .target(
            name: "Variant2_Extensions",
            dependencies: ["Variant2_Core"],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
            ]
        ),
        .testTarget(
            name: "Variant2_ExtensionsTests",
            dependencies: ["Variant2_Core", "Variant2_Extensions"]
        ),

        // Variant 3: Add all the real package's SwiftSettings
        .target(
            name: "Variant3_Core",
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        ),
        .target(
            name: "Variant3_Extensions",
            dependencies: ["Variant3_Core"],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        ),
        .testTarget(
            name: "Variant3_ExtensionsTests",
            dependencies: ["Variant3_Core", "Variant3_Extensions"],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        ),

        // Variant 4: Add complex generic Initialization type
        .target(
            name: "Variant4_Core",
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        ),
        .target(
            name: "Variant4_Extensions",
            dependencies: ["Variant4_Core"],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        ),
        .testTarget(
            name: "Variant4_ExtensionsTests",
            dependencies: ["Variant4_Core", "Variant4_Extensions"],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        ),

        // Variant 5: Multi-module import graph (mirrors real package structure)
        // Core + Inline + Heap + TestSupport all imported by test
        .target(
            name: "Variant5_Core",
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        ),
        .target(
            name: "Variant5_Inline",
            dependencies: ["Variant5_Core"],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        ),
        .target(
            name: "Variant5_Heap",
            dependencies: ["Variant5_Core"],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        ),
        .target(
            name: "Variant5_TestSupport",
            dependencies: ["Variant5_Core", "Variant5_Inline", "Variant5_Heap"],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        ),
        .testTarget(
            name: "Variant5_Tests",
            dependencies: ["Variant5_Core", "Variant5_Inline", "Variant5_Heap", "Variant5_TestSupport"],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        ),

        // Variant 6: External package dependency (real Index_Primitives)
        // This mirrors the actual swift-storage-primitives structure with real dependencies
        .target(
            name: "Variant6_Core",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        ),
        .target(
            name: "Variant6_Inline",
            dependencies: ["Variant6_Core"],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        ),
        .target(
            name: "Variant6_Heap",
            dependencies: ["Variant6_Core"],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        ),
        .target(
            name: "Variant6_TestSupport",
            dependencies: ["Variant6_Core", "Variant6_Inline", "Variant6_Heap"],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        ),
        .testTarget(
            name: "Variant6_Tests",
            dependencies: [
                "Variant6_Core",
                "Variant6_Inline",
                "Variant6_Heap",
                "Variant6_TestSupport",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        ),

        // RealPackageTest: Test using the ACTUAL swift-storage-primitives types
        .executableTarget(
            name: "RealPackageTest",
            dependencies: [
                .product(name: "Storage Primitives Core", package: "swift-storage-primitives"),
                .product(name: "Storage Inline Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Heap Primitives", package: "swift-storage-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        ),

        // CoreOnlyTest: Test using ONLY Storage_Primitives_Core (no extensions module)
        .executableTarget(
            name: "CoreOnlyTest",
            dependencies: [
                .product(name: "Storage Primitives Core", package: "swift-storage-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
