// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WordLoopProgress",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "WordLoopProgress", targets: ["WordLoopProgress"]),
    ],
    dependencies: [
        .package(path: "../WordLoopCore"),
        .package(path: "../WordLoopNetworking"),
    ],
    targets: [
        .target(
            name: "WordLoopProgress",
            dependencies: [
                .product(name: "WordLoopCore", package: "WordLoopCore"),
                .product(name: "WordLoopNetworking", package: "WordLoopNetworking"),
            ]
        ),
        .testTarget(
            name: "WordLoopProgressTests",
            dependencies: [
                "WordLoopProgress",
                .product(name: "WordLoopCore", package: "WordLoopCore"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
