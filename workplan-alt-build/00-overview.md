# Workplan: Migrate SwiftAndroidSdk to swift-multiplatform Gradle Plugin

## Branch: `alt_build_system`

## Goal
Replace the dual-Package.swift + symlink + shell scripts architecture with the `com.dallaslabs.swift-multiplatform` Gradle plugin. One source tree, one build system, one command.

## Workplan Files

| File | Phase | Description |
|------|-------|-------------|
| `01-files-to-delete.md` | Prep | Every file/dir being removed and why |
| `02-unified-package-swift.md` | Core | Merging two Package.swift into one |
| `03-root-gradle-setup.md` | Core | New build.gradle.kts, settings.gradle.kts, gradle.properties at root |
| `04-gradle-wrapper.md` | Core | Initialize Gradle wrapper at project root |
| `05-build-validation.md` | Validate | Steps to verify Android + iOS builds work |
| `06-publish-validation.md` | Validate | Steps to verify GCS Maven + GCS + Gitea publishing |
| `07-ci-migration.md` | CI | Simplified release.yml and ci.yml |
| `08-client-validation.md` | E2E | Verify all 4 client apps resolve and build with new artifacts |
| `09-cleanup-and-docs.md` | Final | README updates, remove stale docs, final commit |

## Current State (before)

```
SwiftAndroidSdk/
├── Package.swift                    ← iOS (platforms: iOS, macOS)
├── android/
│   ├── Package.swift                ← Android (platforms: macOS, swift-java)
│   ├── Sources -> ../Sources        ← SYMLINK
│   ├── build.gradle                 ← 200+ lines Groovy
│   ├── settings.gradle
│   ├── gradle.properties            ← VERSION_NAME=1.1.7
│   ├── local.properties             ← TMDB keys (should be gitignored)
│   ├── gradlew / gradlew.bat
│   └── gradle/wrapper/
├── scripts/
│   ├── bootstrap.sh
│   ├── build-android.sh
│   ├── build-xcframework.sh
│   ├── publish-xcframework.gradle
│   ├── publish-swiftkit-core.gradle
│   └── release.sh
├── Sources/SwiftAndroidSDK/
├── Tests/SwiftAndroidSDKTests/
└── .github/workflows/
    ├── release.yml                  ← 2 jobs, ~375 lines
    └── ci.yml
```

## Target State (after)

```
SwiftAndroidSdk/
├── Package.swift                    ← unified (both platforms)
├── build.gradle.kts                 ← ~35 lines applying plugin
├── settings.gradle.kts              ← plugin resolution from GitHub Packages
├── gradle.properties                ← VERSION_NAME + credentials
├── gradlew / gradlew.bat
├── gradle/wrapper/
├── Sources/SwiftAndroidSDK/         ← untouched
├── Tests/SwiftAndroidSDKTests/      ← untouched
├── scripts/
│   └── publish-swiftkit-core.gradle ← kept (external dep, may integrate later)
└── .github/workflows/
    ├── release.yml                  ← 1 job, ~25 lines
    └── ci.yml                       ← simplified
```

## What Gets Deleted

- `android/` entire directory (Package.swift, build.gradle, settings.gradle, gradle.properties, local.properties, symlink, wrapper)
- `scripts/bootstrap.sh`
- `scripts/build-android.sh`
- `scripts/build-xcframework.sh`
- `scripts/publish-xcframework.gradle`
- `scripts/release.sh`

## What Gets Created

- `build.gradle.kts` (root) — applies plugin, ~35 lines
- `settings.gradle.kts` (root) — plugin resolution
- `gradle.properties` (root) — version + config
- `gradlew` / `gradlew.bat` / `gradle/wrapper/` (root) — Gradle wrapper

## What Gets Modified

- `Package.swift` — merged from two files into one
- `.github/workflows/release.yml` — 2 jobs → 1 job
- `.github/workflows/ci.yml` — simplified
- `README.md` — updated build instructions

## Plugin Version

`com.dallaslabs.swift-multiplatform:0.1.1` from GitHub Packages at:
`https://maven.pkg.github.com/erikg84/swift-multiplatform-gradle-plugin`

## Rollback

`git checkout main` — original structure is completely untouched on main.
