# 09 — Cleanup and Docs

## Goal
Final cleanup, README updates, and commit history.

## README.md Updates

Update the README to reflect the new build system:

### Build Instructions (replace current)

```markdown
## Build

Prerequisites: JDK 17, Swift 6.3 with Android SDK, Xcode 16+, swiftly

### All artifacts (Android AAR + iOS XCFramework)
```bash
./gradlew buildAll
```

### Android only
```bash
./gradlew assembleRelease
```

### iOS XCFramework only
```bash
./gradlew assembleXCFramework
```

### Run tests
```bash
swift test                    # host platform tests
./gradlew swiftTest           # same, via Gradle
```

### Publish everything
```bash
./gradlew publishAll          # → GCS Maven + GCS + Gitea
```
```

### Architecture Section (update)

Remove references to:
- `android/` subdirectory
- Symlink
- Two Package.swift files
- Shell scripts

Add:
```markdown
## Build System

This SDK uses the [swift-multiplatform Gradle plugin](https://github.com/erikg84/swift-multiplatform-gradle-plugin)
to build both Android and iOS artifacts from a single Swift source tree.

- **One `Package.swift`** — dependency manifest for both platforms
- **One `build.gradle.kts`** — configures the plugin
- **One command** — `./gradlew publishAll` builds and publishes everything
- **No symlinks, no shell scripts, no dual configuration**
```

### Consumer Setup (update versions)

```markdown
**Android:**
```kotlin
implementation("com.dallaslabs.sdk:swift-android-sdk:1.2.0")
```

**iOS:**
```swift
.package(id: "dallaslabs-sdk.swift-android-sdk", from: "1.2.0")
```
```

## Stale Documentation

| File | Action |
|------|--------|
| `DISTRIBUTION.md` | Delete — references old android/ structure |
| `PUBLISHING.md` | Delete — replaced by plugin's publishAll |
| `WORKPLAN-GRAPHQL.md` | Delete — completed work |
| `PROPOSAL-unified-build.md` | Keep — documents the decision for future reference |
| `workplan-alt-build/` | Keep on branch — remove before merge to main |

## .gitignore Updates

Ensure root `.gitignore` includes:

```
.gradle/
build/
.build/
local.properties
*.aar
```

## Commit Strategy

Make clean, atomic commits:

1. `Delete android/ directory and obsolete scripts`
2. `Add unified Package.swift`
3. `Add root Gradle setup (build.gradle.kts, settings.gradle.kts, gradle.properties)`
4. `Initialize Gradle wrapper`
5. `Simplify CI workflows`
6. `Update README for unified build system`
7. `Remove stale documentation`

Or if preferred, a single squash commit:
`Migrate to swift-multiplatform Gradle plugin — unified build system`

## Pre-Merge Checklist

Before merging `alt_build_system` → `main`:

- [ ] `./gradlew buildAll` produces AAR + XCFramework
- [ ] `./gradlew publishAll` publishes to GCS + Gitea
- [ ] `swift test` passes
- [ ] CI workflow runs successfully on the branch
- [ ] iOS client resolves new version from Gitea
- [ ] Android client resolves new version from GCS Maven
- [ ] No symlinks in repo (`find . -type l` returns nothing)
- [ ] `ls android/` returns "No such file or directory"
- [ ] README is accurate
- [ ] No credentials in committed files
