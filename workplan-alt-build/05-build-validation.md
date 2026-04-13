# 05 — Build Validation

## Goal
Verify that both Android and iOS builds work after migration.

## Pre-requisites
- Plugin v0.1.1 available (GitHub Packages or Maven Local)
- `gpr.user` + `gpr.key` in `~/.gradle/gradle.properties` (or plugin published to Maven Local)
- Swift 6.3 installed with Android SDK bundle
- Xcode 16+ available
- JDK 17 available

## Step 1: Plugin Resolution

```bash
./gradlew tasks --group swift
```

**Expected output includes:**
- `swiftResolve`
- `bootstrapSwiftkitCore`
- `buildSwiftAndroid`
- `buildSwiftAndroid_arm64v8a`
- `buildSwiftAndroid_x86_64`
- `copyJniLibs`
- `buildIosDevice`
- `buildIosSimulator`
- `assembleXCFramework`
- `zipXCFramework`
- `buildAll`
- `swiftTest`
- `publishAndroid`
- `publishIosGcs`
- `publishIosGitea`
- `publishAll`

## Step 2: Swift Package Resolution

```bash
./gradlew swiftResolve
```

**Verifies:** SPM resolves Swinject + swift-java from root Package.swift.

## Step 3: swiftkit-core Bootstrap

```bash
./gradlew bootstrapSwiftkitCore
```

**Verifies:** swiftkit-core JAR is in `~/.m2/repository/org/swift/swiftkit/swiftkit-core/`.

## Step 4: Android Cross-Compilation

```bash
# Single ABI
./gradlew buildSwiftAndroid_arm64v8a

# All ABIs
./gradlew buildSwiftAndroid
```

**Verifies:**
- `.build/aarch64-unknown-linux-android28/debug/` contains .so files
- `.build/x86_64-unknown-linux-android28/debug/` contains .so files
- JExtract generated Java sources in `.build/plugins/outputs/`

## Step 5: Android AAR

```bash
./gradlew assembleRelease
```

**Verifies:**
- `build/outputs/aar/SwiftAndroidSDK-release.aar` exists
- AAR contains `jni/arm64-v8a/*.so` and `jni/x86_64/*.so`
- AAR contains generated Java classes

## Step 6: iOS XCFramework

```bash
./gradlew assembleXCFramework
```

**Verifies:**
- `build/xcframeworks/SwiftAndroidSDK.xcframework/` exists
- Contains `ios-arm64/` and `ios-arm64_x86_64-simulator/` subdirectories
- `Info.plist` is present

## Step 7: XCFramework Zip + Checksum

```bash
./gradlew zipXCFramework
```

**Verifies:**
- `build/xcframeworks/SwiftAndroidSDK-1.2.0.xcframework.zip` exists
- `build/xcframeworks/SwiftAndroidSDK-1.2.0.xcframework.sha256` exists
- Checksum is a valid 64-char hex string

## Step 8: Full Build

```bash
./gradlew buildAll
```

**Verifies:** Both AAR and XCFramework build in one command.

## Step 9: Swift Tests

```bash
./gradlew swiftTest
```

**Verifies:** Host-platform tests pass (macOS).

## Troubleshooting

| Error | Likely Cause | Fix |
|-------|-------------|-----|
| Plugin not found | gpr.user/gpr.key not set | Add to ~/.gradle/gradle.properties |
| swiftly not found | swiftly not installed | Install from swift.org/install |
| Swift SDK not found | Android SDK bundle missing | `swift sdk install <url>` |
| xcodebuild not found | Xcode not installed | Install Xcode |
| swiftkit-core resolution failed | Bootstrap didn't run | `./gradlew bootstrapSwiftkitCore` |
| JExtract Java sources missing | swift-java not resolved | `./gradlew swiftResolve` first |
