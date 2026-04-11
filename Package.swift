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
        // Swinject — runtime DI container. Replaced Factory 2.5.3 in v1.0.1
        // because Factory's .swiftinterface generation has an unresolvable
        // module-vs-type naming ambiguity that breaks XCFramework builds with
        // BUILD_LIBRARY_FOR_DISTRIBUTION=YES. Swinject's module name is
        // `Swinject` (the main type is `Container`), so it has no such collision.
        .package(url: "https://github.com/Swinject/Swinject.git", from: "2.10.0"),
    ],
    targets: [
        .target(
            name: "SwiftAndroidSDK",
            dependencies: [
                .product(name: "Swinject", package: "Swinject"),
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
