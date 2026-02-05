// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "bitvector-slot-tracking",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-bit-vector-primitives"),
        .package(path: "../../../swift-bit-index-primitives")
    ],
    targets: [
        .executableTarget(
            name: "bitvector-slot-tracking",
            dependencies: [
                .product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),
                .product(name: "Bit Index Primitives Test Support", package: "swift-bit-index-primitives")
            ],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout")
            ]
        )
    ]
)
