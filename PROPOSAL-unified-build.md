# Proposal: Unified Gradle Build System for SwiftAndroidSDK

## Branch: `alt_build_system`

## Summary

Replace the current dual-Package.swift + symlink build architecture with a single Gradle plugin (`com.dallaslabs.swift-multiplatform`) that orchestrates both Android AAR and iOS XCFramework generation from one source tree.

## Motivation

The current build system works but has structural friction:

| Issue | Impact |
|-------|--------|
| Two `Package.swift` files | Divergent configs, easy to miss changes in one |
| Symlink (`android/Sources -> ../Sources`) | Breaks on Windows, confusing to new contributors |
| Separate CI jobs for Android + iOS | Longer pipelines, duplicated setup steps |
| Shell scripts for XCFramework | Untyped, no caching, no incremental builds |
| Version in multiple places | `gradle.properties` + git tag + manual coordination |

Kotlin Multiplatform solves all of this with a single Gradle plugin. We can do the same for Swift.

## What Changes

### Before → After

```
BEFORE:                              AFTER:
SwiftAndroidSdk/                     SwiftAndroidSdk/
├── Package.swift (iOS)              ├── Package.swift (unified)
├── android/                         ├── build.gradle.kts (~30 lines)
│   ├── Package.swift (Android)      ├── settings.gradle.kts
│   ├── Sources -> ../Sources        ├── gradle.properties
│   ├── build.gradle (200+ lines)    ├── Sources/SwiftAndroidSDK/
│   ├── settings.gradle              ├── Tests/SwiftAndroidSDKTests/
│   ├── gradle.properties            └── .github/workflows/
│   └── gradle/                          └── release.yml (1 job, ~30 lines)
├── scripts/
│   ├── build-xcframework.sh
│   ├── publish-xcframework.gradle
│   └── publish-swiftkit-core.gradle
├── Sources/SwiftAndroidSDK/
├── Tests/SwiftAndroidSDKTests/
└── .github/workflows/
    └── release.yml (2 jobs, ~180 lines)
```

### The Plugin

The Gradle plugin (`com.dallaslabs.swift-multiplatform`) is developed in a separate repo:
- **Repo**: `erikg84/swift-multiplatform-gradle-plugin`
- **Published to**: GitHub Packages
- **Plugin ID**: `com.dallaslabs.swift-multiplatform`

### SDK's build.gradle.kts (entire file)

```kotlin
plugins {
    id("com.dallaslabs.swift-multiplatform") version "1.0.0"
}

swiftMultiplatform {
    moduleName = "SwiftAndroidSDK"
    sourcesDir = "Sources/SwiftAndroidSDK"
    version = providers.gradleProperty("VERSION_NAME")

    android {
        abis("arm64-v8a", "x86_64")
        swiftSdk("swift-6.3-RELEASE_android")
        minSdk(28)
        compileSdk(36)
        jextract(enabled = true)
        namespace("com.dallaslabs.sdk.swiftandroidsdk")
        excludeFromSwift("Container/TMDBContainerTestHooks.swift", "swift-java.config")
    }

    ios {
        targets("ios-arm64", "ios-simulator-arm64")
        minimumDeployment("15.0")
        frameworkName("SwiftAndroidSDK")
    }

    publishing {
        maven {
            groupId = "com.dallaslabs.sdk"
            artifactId = "swift-android-sdk"
            repository = "https://storage.googleapis.com/dallaslabs-sdk-artifacts/maven"
        }
        gitea {
            registryUrl = providers.gradleProperty("GITEA_URL")
            token = providers.gradleProperty("GITEA_TOKEN")
            scope = "dallaslabs-sdk"
            packageName = "swift-android-sdk"
        }
    }
}
```

### SDK's CI (entire release workflow)

```yaml
jobs:
  publish:
    runs-on: [self-hosted, mac-studio]
    steps:
      - uses: actions/checkout@v4
      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCS_SA_KEY_JSON }}
      - run: ./gradlew publishAll --no-daemon
        env:
          GITEA_TOKEN: ${{ secrets.GITEA_TOKEN }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Implementation Plan

1. **Build the Gradle plugin** (separate repo, workplan in plugin repo)
2. **Publish plugin v1.0.0** to GitHub Packages
3. **Migrate SDK** on this branch (`alt_build_system`):
   - Add `build.gradle.kts` + `settings.gradle.kts` at root
   - Merge two Package.swift into one
   - Delete `android/` directory
   - Delete shell scripts
   - Simplify CI
4. **Validate**: `./gradlew buildAll` + `./gradlew publishAll`
5. **Merge to main** after full validation

## Risk Mitigation

- All work on `alt_build_system` branch — `main` is untouched
- Plugin developed and tested independently before SDK migration
- Existing CI continues to work on `main` during development
- Rollback = `git checkout main`

## Success Criteria

- [ ] `./gradlew buildAll` produces AAR + XCFramework from single source tree
- [ ] `./gradlew publishAll` publishes to GCS Maven + GCS + Gitea
- [ ] Zero symlinks in the repo
- [ ] One Package.swift
- [ ] CI workflow is a single job
- [ ] iOS clients resolve new version from Gitea
- [ ] Android clients resolve new version from GCS Maven
