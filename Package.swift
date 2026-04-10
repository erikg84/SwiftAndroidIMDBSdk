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
        .package(url: "https://github.com/hmlongco/Factory", from: "2.4.0"),
    ],
    targets: [
        .target(
            name: "SwiftAndroidSDK",
            dependencies: [
                .product(name: "Factory", package: "Factory"),
            ]
        ),
        .testTarget(
            name: "SwiftAndroidSDKTests",
            dependencies: [
                "SwiftAndroidSDK",
                .product(name: "Factory", package: "Factory"),
            ]
        ),
    ]
)
