// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WordLoopCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "WordLoopCore", targets: ["WordLoopCore"]),
    ],
    targets: [
        .target(name: "WordLoopCore"),
        .testTarget(name: "WordLoopCoreTests", dependencies: ["WordLoopCore"]),
    ],
    swiftLanguageModes: [.v6]
)
