// swift-tools-version: 6.0
// iOS / macOS / Linux entry point — standard Swift Package, no android-specific tooling.

import PackageDescription

let package = Package(
    name: "SwiftAndroidSDK",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "SwiftAndroidSDK",
            targets: ["SwiftAndroidSDK"]
        ),
    ],
    dependencies: [
        // Swinject — runtime DI container
        .package(url: "https://github.com/Swinject/Swinject.git", from: "2.10.0"),
        // swift-log — cross-platform logging (OSLog on iOS, Logcat on Android)
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.2"),
    ],
    targets: [
        .target(
            name: "SwiftAndroidSDK",
            dependencies: [
                .product(name: "Swinject", package: "Swinject"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .testTarget(
            name: "SwiftAndroidSDKTests",
            dependencies: [
                "SwiftAndroidSDK",
            ]
        ),
    ]
)
