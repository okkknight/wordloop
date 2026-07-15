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
    dependencies: [
        .package(path: "../WordLoopCore"),
    ],
    targets: [
        .target(
            name: "WordLoopDesignSystem",
            dependencies: [
                .product(name: "WordLoopCore", package: "WordLoopCore"),
            ]
        ),
        .testTarget(name: "WordLoopDesignSystemTests", dependencies: ["WordLoopDesignSystem"]),
    ],
    swiftLanguageModes: [.v6]
)
