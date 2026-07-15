// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WordLoopFeatures",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "WordLoopFeatures", targets: ["WordLoopFeatures"]),
    ],
    dependencies: [
        .package(path: "../WordLoopCore"),
        .package(path: "../WordLoopContent"),
        .package(path: "../WordLoopDesignSystem"),
        .package(path: "../WordLoopAudio"),
        .package(path: "../WordLoopProgress"),
        .package(path: "../WordLoopRealtime"),
    ],
    targets: [
        .target(
            name: "WordLoopFeatures",
            dependencies: [
                .product(name: "WordLoopCore", package: "WordLoopCore"),
                .product(name: "WordLoopContent", package: "WordLoopContent"),
                .product(name: "WordLoopDesignSystem", package: "WordLoopDesignSystem"),
                .product(name: "WordLoopAudio", package: "WordLoopAudio"),
                .product(name: "WordLoopProgress", package: "WordLoopProgress"),
                .product(name: "WordLoopRealtime", package: "WordLoopRealtime"),
            ]
        ),
        .testTarget(name: "WordLoopFeaturesTests", dependencies: ["WordLoopFeatures"]),
    ],
    swiftLanguageModes: [.v6]
)
