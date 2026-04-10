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
    targets: [
        .target(
            name: "SwiftAndroidSDK"
        ),
        .testTarget(
            name: "SwiftAndroidSDKTests",
            dependencies: ["SwiftAndroidSDK"]
        ),
    ]
)
