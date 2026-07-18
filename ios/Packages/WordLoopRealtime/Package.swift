// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WordLoopRealtime",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "WordLoopRealtime", targets: ["WordLoopRealtime"]),
    ],
    dependencies: [
        .package(path: "../WordLoopCore"),
        .package(path: "../WordLoopNetworking"),
        .package(url: "https://github.com/stasel/WebRTC.git", exact: "150.0.0"),
    ],
    targets: [
        .target(
            name: "WordLoopRealtime",
            dependencies: [
                .product(name: "WordLoopCore", package: "WordLoopCore"),
                .product(name: "WordLoopNetworking", package: "WordLoopNetworking"),
                .product(name: "WebRTC", package: "WebRTC"),
            ]
        ),
        .testTarget(name: "WordLoopRealtimeTests", dependencies: ["WordLoopRealtime"]),
    ],
    swiftLanguageModes: [.v6]
)
