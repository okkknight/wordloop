// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WordLoopNetworking",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "WordLoopNetworking", targets: ["WordLoopNetworking"]),
    ],
    dependencies: [
        .package(path: "../WordLoopCore"),
    ],
    targets: [
        .target(
            name: "WordLoopNetworking",
            dependencies: [
                .product(name: "WordLoopCore", package: "WordLoopCore"),
            ]
        ),
        .testTarget(name: "WordLoopNetworkingTests", dependencies: ["WordLoopNetworking"]),
    ],
    swiftLanguageModes: [.v6]
)
