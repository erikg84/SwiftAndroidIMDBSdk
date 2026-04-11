// swift-tools-version: 6.2
// Android cross-compilation entry point.
// "android/Sources" is a symlink to "../Sources", so this package shares
// source files with the root iOS/macOS package without duplication.
//
// This package is NOT used by iOS consumers — it is only invoked by the
// Gradle build via `swiftly run swift build --swift-sdk <android-triple>`.

import PackageDescription

let package = Package(
    name: "SwiftAndroidSDK",
    // macOS host is required for cross-compilation; no iOS target here.
    platforms: [.macOS(.v15)],
    products: [
        // .dynamic produces a .so shared library for Android.
        .library(
            name: "SwiftAndroidSDK",
            type: .dynamic,
            targets: ["SwiftAndroidSDK"]
        ),
    ],
    dependencies: [
        // Swinject: runtime DI container — pure Swift, Foundation-only, Linux/Android compatible.
        // Replaced Factory in v1.0.1 due to a Factory upstream .swiftinterface bug
        // that broke iOS XCFramework builds.
        .package(url: "https://github.com/Swinject/Swinject.git", from: "2.10.0"),
        // swift-java: provides the JExtractSwiftPlugin and SwiftJava runtime macros.
        // Pin to a release tag before shipping to production.
        .package(url: "https://github.com/swiftlang/swift-java.git", from: "0.1.2"),
    ],
    targets: [
        .target(
            name: "SwiftAndroidSDK",
            dependencies: [
                .product(name: "Swinject", package: "Swinject"),
                // SwiftJava provides @JavaClass / @JavaMethod macros for advanced bridging.
                .product(name: "SwiftJava", package: "swift-java"),
            ],
            // Sources symlink resolves to ../../Sources/SwiftAndroidSDK at the filesystem level.
            exclude: [
                // swift-java.config is consumed by JExtractSwiftPlugin, not the Swift compiler.
                "swift-java.config",
                // Test hooks use @escaping closures that JExtractSwiftPlugin cannot bridge to JNI.
                // These methods are only needed on iOS/macOS (Darwin) for unit testing.
                "Container/TMDBContainerTestHooks.swift",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ],
            plugins: [
                // JExtractSwiftPlugin scans public Swift API and generates Java wrappers
                // into .build/plugins/outputs/.../JExtractSwiftPlugin/src/generated/java/
                // Gradle picks those up via the srcDir(...) declaration in build.gradle.
                .plugin(name: "JExtractSwiftPlugin", package: "swift-java"),
            ]
        ),
    ]
)
