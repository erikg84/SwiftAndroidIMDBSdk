# Publishing Guide

This document is for SDK **maintainers** — people who build and publish new versions.
For integration instructions, see [README.md](README.md).

---

## Prerequisites

### macOS machine (required for Android cross-compilation)
1. **Swiftly** — `curl -L https://swiftlang.github.io/swiftly/swiftly-install.sh | bash`
2. **Swift 6.3** — `swiftly install 6.3 --use`
3. **Swift SDK for Android**
   ```bash
   swift sdk install \
     https://download.swift.org/swift-6.3-release/android-sdk/swift-6.3-RELEASE/swift-6.3-RELEASE_android.artifactbundle.tar.gz \
     --checksum 2f2942c4bcea7965a08665206212c66991dabe23725aeec7c4365fc91acad088
   ```
4. **Android NDK r27d** — downloaded automatically by the Swift SDK setup script,
   or manually from https://developer.android.com/ndk/downloads/
5. **JDK 25** (for bootstrap only) — `sdk install java 25.0.1-amzn && sdk use java 25.0.1-amzn`
6. **gh CLI** — `brew install gh && gh auth login`

---

## First-Time Setup

```bash
git clone https://github.com/YOUR_ORG/SwiftAndroidSdk
cd SwiftAndroidSdk
bash scripts/bootstrap.sh
```

`bootstrap.sh` will:
- Verify Swift 6.3 + Android SDK
- Resolve the `swift-java` Swift package
- Publish swift-java support libraries to `~/.m2` (local Maven)
- Download the Gradle wrapper binary

> ⚠️ The `publishToMavenLocal` step requires **JDK 25**.
> For normal Android builds you can switch back to JDK 17.
> This requirement will be removed once swift-java publishes to Maven Central.

---

## Building

### Android AAR
```bash
bash scripts/build-android.sh --release
# → android/build/outputs/aar/swift-android-sdk-release.aar
```

### iOS (no build step)
iOS consumers use the Swift source directly via SPM. Nothing to compile on the maintainer side.

### Optional: XCFramework binary distribution
If you want to ship a pre-compiled binary instead of source for iOS:

```bash
# Build device slice
xcodebuild archive \
  -scheme SwiftAndroidSDK \
  -destination "generic/platform=iOS" \
  -archivePath ./build/SwiftAndroidSDK-iOS.xcarchive \
  SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# Build simulator slice
xcodebuild archive \
  -scheme SwiftAndroidSDK \
  -destination "generic/platform=iOS Simulator" \
  -archivePath ./build/SwiftAndroidSDK-iOS-Sim.xcarchive \
  SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# Combine into XCFramework
xcodebuild -create-xcframework \
  -framework ./build/SwiftAndroidSDK-iOS.xcarchive/Products/Library/Frameworks/SwiftAndroidSDK.framework \
  -framework ./build/SwiftAndroidSDK-iOS-Sim.xcarchive/Products/Library/Frameworks/SwiftAndroidSDK.framework \
  -output ./build/SwiftAndroidSDK.xcframework

# Zip + get checksum
zip -r SwiftAndroidSDK.xcframework.zip build/SwiftAndroidSDK.xcframework
shasum -a 256 SwiftAndroidSDK.xcframework.zip
```

Then update `Package.swift` to use a `binaryTarget` pointing to the release URL + checksum.

---

## Releasing a New Version

```bash
bash scripts/release.sh 1.2.0
```

This script will:
1. Bump `VERSION_NAME` in `android/gradle.properties`
2. Commit + push + create git tag `v1.2.0`
3. Build the release AAR
4. Create a GitHub Release with the AAR attached

### Publish Android AAR to Maven Central

After the GitHub Release is created:

```bash
cd android

# Set credentials (or put in ~/.gradle/gradle.properties)
export OSSRH_USERNAME=your_sonatype_username
export OSSRH_PASSWORD=your_sonatype_password
export GPG_SIGNING_KEY="$(gpg --armor --export-secret-keys YOUR_KEY_ID)"
export GPG_SIGNING_PASSWORD=your_gpg_passphrase

./gradlew publishReleasePublicationToOSSRHRepository
```

Then log in to https://s01.oss.sonatype.org and **Close → Release** the staging repository.

> First time? You'll need to register a namespace with Sonatype OSSRH:
> https://central.sonatype.org/register/

### Test publish locally (no Sonatype required)
```bash
cd android && ./gradlew publishReleasePublicationToLocalFileRepository
# → android/build/local-repo/
```

---

## Updating the SDK Namespace

Before first publish, replace all `YOUR_ORG` / `YOUR_GITHUB_ID` placeholders:

| File | Field |
|------|-------|
| `android/gradle.properties` | `GROUP_ID` |
| `android/build.gradle` | `namespace`, POM `url`, `scm`, `developers` |
| `README.md` | dependency snippets |
| `PUBLISHING.md` | (this file) |

---

## Adding New Swift Modules / Dependencies

If you add a new `import X` to the Swift source that requires a Swift runtime `.so`:

1. Build the AAR and check the crash log for `UnsatisfiedLinkError: dlopen failed: library "libswiftX.so" not found`
2. Add `'swiftX'` to the `swiftRuntimeLibs` list in `android/build.gradle`
3. Rebuild

---

## swift-java Version Pinning

The `android/Package.swift` uses `from: "0.1.2"`. Before a production release,
pin to an exact version to avoid surprises:

```swift
.package(url: "https://github.com/swiftlang/swift-java.git", exact: "0.1.2"),
```

---

## CI Notes (future)

If you add GitHub Actions later, the recommended matrix is:
- `macos-15` runner (Apple Silicon) — builds both iOS and Android AAR
- Secrets: `OSSRH_USERNAME`, `OSSRH_PASSWORD`, `GPG_SIGNING_KEY`, `GPG_SIGNING_PASSWORD`
