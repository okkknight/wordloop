// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WordLoopAudio",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "WordLoopAudio", targets: ["WordLoopAudio"]),
    ],
    dependencies: [
        .package(path: "../WordLoopCore"),
    ],
    targets: [
        .target(
            name: "WordLoopAudio",
            dependencies: [
                .product(name: "WordLoopCore", package: "WordLoopCore"),
            ]
        ),
        .testTarget(name: "WordLoopAudioTests", dependencies: ["WordLoopAudio"]),
    ],
    swiftLanguageModes: [.v6]
)
