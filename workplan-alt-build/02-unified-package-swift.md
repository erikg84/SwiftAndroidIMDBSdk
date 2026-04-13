# 02 — Unified Package.swift

## Goal
Merge the two Package.swift files into one that works for both iOS XCFramework builds and Android cross-compilation.

## Current State

**Root (iOS):** swift-tools-version 6.0, platforms: iOS 15 + macOS 12, depends on Swinject only.

**Android:** swift-tools-version 6.2, platforms: macOS 15 (cross-compile host), depends on Swinject + swift-java, uses JExtractSwiftPlugin, excludes TMDBContainerTestHooks.swift + swift-java.config, swiftLanguageMode .v5, library type .dynamic.

## Merged Package.swift

```swift
// swift-tools-version: 6.2
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
```

## Key Decisions

### swift-tools-version: 6.2
Bumped from 6.0 to 6.2. Required for swift-java compatibility and Android cross-compilation.

### platforms: [.iOS(.v15), .macOS(.v15)]
- `.iOS(.v15)` — needed for XCFramework builds
- `.macOS(.v15)` — needed as cross-compilation host for Android

### .dynamic library type
Required for Android (produces .so). For iOS, `xcodebuild -create-xcframework` produces a proper static framework from the xcarchive regardless of this setting.

### swift-java included for both platforms
swift-java and JExtractSwiftPlugin are present in both builds. On iOS:
- SwiftJava runtime compiles cleanly (it's cross-platform Swift)
- JExtractSwiftPlugin runs and generates Java sources in .build/ — they're simply unused
- No functional impact on the XCFramework

### Excludes
- `swift-java.config` — consumed by JExtract, not the Swift compiler
- `TMDBContainerTestHooks.swift` — uses `@escaping` closures that JExtract can't bridge. iOS tests don't use the main target's test hooks anyway — they're in the test target.

### swiftLanguageMode(.v5)
Required for swift-java macro compatibility. Applied to both platforms.

## Impact on Tests

The test target (`SwiftAndroidSDKTests`) does NOT include swift-java or JExtract. `swift test` continues to work as before — runs on macOS host against the iOS-compatible target.

`TMDBContainerTestHooks.swift` is excluded from the main target but the test target has its own test files in `Tests/SwiftAndroidSDKTests/`. If any test depends on TMDBContainerTestHooks, it needs to be moved to the test target.

## Verification

```bash
# iOS: should resolve and build
swift package resolve
swift build

# Android cross-compilation: should work via Gradle
./gradlew swiftResolve
./gradlew buildSwiftAndroid_arm64v8a
```
