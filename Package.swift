// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "WhisprLocal",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "WhisprLocal", targets: ["WhisprLocal"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.7.0")
    ],
    targets: [
        // Binary target for whisper.cpp XCFramework
        .binaryTarget(
            name: "whisper",
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/v1.8.3/whisper-v1.8.3-xcframework.zip",
            checksum: "a970006f256c8e689bc79e73f7fa7ddb8c1ed2703ad43ee48eb545b5bb6de6af"
        ),

        // Main executable target (app entry point)
        .executableTarget(
            name: "WhisprLocal",
            dependencies: [
                "WhisprLocalCore",
                "WhisprLocalUI"
            ],
            path: "Sources/WhisprLocal"
        ),

        // Core library (all business logic, testable)
        .target(
            name: "WhisprLocalCore",
            dependencies: [
                "whisper",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: "Sources/WhisprLocalCore"
        ),

        // UI library (SwiftUI views)
        .target(
            name: "WhisprLocalUI",
            dependencies: [
                "WhisprLocalCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: "Sources/WhisprLocalUI"
        ),

        // Tests
        .testTarget(
            name: "WhisprLocalCoreTests",
            dependencies: ["WhisprLocalCore"],
            path: "Tests/WhisprLocalCoreTests"
        )
    ]
)
