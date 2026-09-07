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
        .library(name: "Storage Standard Library Integration", targets: ["Storage Standard Library Integration"]),
        .library(name: "Storage Foundation Library Integration", targets: ["Storage Foundation Library Integration"]),
        .library(name: "Storage Test Support", targets: ["Storage Test Support"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Storage",
            dependencies: [
            ],
            path: "Sources/Storage"
        ),
        .target(
            name: "Storage Standard Library Integration",
            dependencies: [
                .target(name: "Storage"),
            ],
            path: "Sources/Storage Standard Library Integration"
        ),
        .target(
            name: "Storage Foundation Library Integration",
            dependencies: [
                .target(name: "Storage"),
                .target(name: "Storage Standard Library Integration"),
            ],
            path: "Sources/Storage Foundation Library Integration"
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
                .target(name: "Storage Standard Library Integration"),
                .target(name: "Storage Foundation Library Integration"),
            ],
            path: "Tests/Storage Tests"
        ),
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
