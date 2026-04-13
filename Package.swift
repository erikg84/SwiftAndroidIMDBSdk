// swift-tools-version: 6.2
// Unified Package.swift — used by both iOS (XCFramework) and Android (cross-compilation).
// Gradle plugin orchestrates all builds; this file is the dependency manifest.

import PackageDescription

let package = Package(
    name: "SwiftAndroidSDK",
    platforms: [.iOS(.v15), .macOS(.v15)],
    products: [
        .library(
            name: "SwiftAndroidSDK",
            type: .dynamic,
            targets: ["SwiftAndroidSDK"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Swinject/Swinject.git", from: "2.10.0"),
        .package(url: "https://github.com/swiftlang/swift-java.git", from: "0.1.2"),
    ],
    targets: [
        .target(
            name: "SwiftAndroidSDK",
            dependencies: [
                .product(name: "Swinject", package: "Swinject"),
                .product(name: "SwiftJava", package: "swift-java"),
            ],
            exclude: [
                "swift-java.config",
                "Container/TMDBContainerTestHooks.swift",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ],
            plugins: [
                .plugin(name: "JExtractSwiftPlugin", package: "swift-java"),
            ]
        ),
        .testTarget(
            name: "SwiftAndroidSDKTests",
            dependencies: ["SwiftAndroidSDK"]
        ),
    ]
)
