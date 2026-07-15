// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WordLoopContent",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "WordLoopContent", targets: ["WordLoopContent"]),
    ],
    dependencies: [
        .package(path: "../WordLoopCore"),
    ],
    targets: [
        .target(
            name: "WordLoopContent",
            dependencies: [
                .product(name: "WordLoopCore", package: "WordLoopCore"),
            ]
        ),
        .testTarget(name: "WordLoopContentTests", dependencies: ["WordLoopContent"]),
    ],
    swiftLanguageModes: [.v6]
)
