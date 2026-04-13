# 08 — Client Validation

## Goal
Verify that all 4 client apps can resolve and build against the new v1.2.0 artifacts published from the unified build system.

## Pre-requisites
- `publishAll` succeeded (workplan 06)
- v1.2.0 artifacts live on GCS Maven and Gitea

## Android Clients

### ComposeMultiplatformImdbDemo-Android

```bash
# Update version in gradle/libs.versions.toml
# imdb-sdk = "1.0.6" → no change (different SDK)
# This client uses composemultiplatformsdk, not SwiftAndroidSdk
```

**Not affected** — this client uses the KMP SDK, not the Swift SDK.

### SwiftAndroidImdbDemo-Android

```bash
# Update version in gradle/libs.versions.toml
# swift-android-sdk = "1.1.7" → "1.2.0"

cd /Volumes/EXTERNAL-DRIVE/Documents/SwiftAndroidImdbDemo-Android
# Edit gradle/libs.versions.toml: swift-android-sdk = "1.2.0"
./gradlew assembleDebug
# Should resolve from GCS Maven and build successfully
```

**Verify:**
- Gradle resolves `com.dallaslabs.sdk:swift-android-sdk:1.2.0` from GCS
- Build succeeds
- Install and launch on emulator

## iOS Clients

### ComposeMultiplatformImdbDemo-iOS

**Not affected** — this client uses the KMP SDK.

### SwiftAndroidImdbDemo-iOS

```bash
# Update version in SDKPackage/Package.swift
# from: "1.1.7" → from: "1.2.0"

cd /Volumes/EXTERNAL-DRIVE/Documents/SwiftAndroidImdbDemo-iOS
# Edit SDKPackage/Package.swift: .package(id: "dallaslabs-sdk.swift-android-sdk", from: "1.2.0")

# Clear caches
rm -rf .build Package.resolved
rm -f ~/.swiftpm/security/fingerprints/dallaslabs-sdk.swift-android-sdk.json

swift package resolve
# Should resolve v1.2.0 from Gitea → download XCFramework from GCS

xcodegen generate
xcodebuild -project SwiftAndroidImdbDemo.xcodeproj \
  -scheme SwiftAndroidImdbDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
# Should BUILD SUCCEEDED
```

**Verify:**
- SPM resolves `dallaslabs-sdk.swift-android-sdk` v1.2.0 from Gitea
- Gitea returns Package.swift with binaryTarget pointing at GCS v1.2.0 URL
- XCFramework downloads from GCS
- Build succeeds
- Install and launch on simulator

## MacBook Pro Validation

Repeat the iOS client test on the MacBook Pro (192.168.68.135):

```bash
ssh erikgutierrez@192.168.68.135 'bash -l -s' << 'REMOTE'
export PATH="/opt/homebrew/bin:$PATH"
cd ~/Documents/SwiftAndroidImdbDemo-iOS
git pull
rm -rf .build Package.resolved
swift package resolve
xcodegen generate
xcodebuild -project SwiftAndroidImdbDemo.xcodeproj \
  -scheme SwiftAndroidImdbDemo \
  -destination "generic/platform=iOS Simulator" \
  build 2>&1 | grep BUILD
REMOTE
```

## Checklist

- [ ] SwiftAndroidImdbDemo-Android resolves v1.2.0 from GCS Maven
- [ ] SwiftAndroidImdbDemo-Android builds and runs on emulator
- [ ] SwiftAndroidImdbDemo-iOS resolves v1.2.0 from Gitea
- [ ] SwiftAndroidImdbDemo-iOS builds on Mac Studio simulator
- [ ] SwiftAndroidImdbDemo-iOS builds on MacBook Pro simulator
- [ ] No references to old v1.1.7 remain in client repos

## Do NOT update client repos until validation passes

Only bump versions and push after confirming builds work. If something breaks, the rollback is simply not updating the version — clients continue using v1.1.7 from main branch.
