// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KiroUsageKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KiroUsageKit", targets: ["KiroUsageKit"])
    ],
    targets: [
        .target(
            name: "KiroUsageKit",
            path: "Sources/KiroUsageKit"
        ),
        .testTarget(
            name: "KiroUsageKitTests",
            dependencies: ["KiroUsageKit"],
            path: "Tests/KiroUsageKitTests"
        )
    ]
)
