// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WordLoopDesignSystem",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "WordLoopDesignSystem", targets: ["WordLoopDesignSystem"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "WordLoopDesignSystem",
            dependencies: [],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "WordLoopDesignSystemTests", dependencies: ["WordLoopDesignSystem"]),
    ],
    swiftLanguageModes: [.v6]
)
