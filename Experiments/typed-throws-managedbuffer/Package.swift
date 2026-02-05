// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "typed-throws-managedbuffer",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "typed-throws-managedbuffer",
            swiftSettings: [
                .strictMemorySafety()
            ]
        )
    ]
)
