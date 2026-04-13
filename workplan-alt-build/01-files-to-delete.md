# 01 — Files to Delete

## Goal
Remove all files that the Gradle plugin replaces. Every deletion is justified.

## android/ Directory (entire thing)

| File | Why it's deleted |
|------|-----------------|
| `android/Package.swift` | Merged into root Package.swift. Plugin uses root for both platforms. |
| `android/Sources` (symlink → `../Sources`) | No longer needed — plugin builds from root Sources/ directly. |
| `android/build.gradle` (200+ lines) | Replaced by root `build.gradle.kts` (~35 lines) + plugin. |
| `android/settings.gradle` | Replaced by root `settings.gradle.kts`. |
| `android/gradle.properties` | Merged into root `gradle.properties`. |
| `android/local.properties` | Contains TMDB keys — should never have been committed. Not recreated. |
| `android/gradlew` / `android/gradlew.bat` | Replaced by root Gradle wrapper. |
| `android/gradle/wrapper/` | Replaced by root Gradle wrapper. |
| `android/.build/` | Swift build cache — rebuild. |
| `android/build/` | Gradle build output — rebuild. |
| `android/Package.resolved` | SPM lockfile — regenerated from root. |

## scripts/ (most files)

| File | Why it's deleted |
|------|-----------------|
| `scripts/bootstrap.sh` | Plugin handles toolchain discovery + swiftkit-core bootstrap. |
| `scripts/build-android.sh` | Replaced by `./gradlew assembleRelease`. |
| `scripts/build-xcframework.sh` | Replaced by `./gradlew assembleXCFramework`. If the custom .o reassembly is needed, use `ios { buildScript = "scripts/build-xcframework.sh" }` — but try standard xcodebuild first. |
| `scripts/publish-xcframework.gradle` | Replaced by plugin's `publishIosGcs` task. |
| `scripts/release.sh` | Replaced by `./gradlew publishAll`. |

## scripts/ (kept)

| File | Why it's kept |
|------|--------------|
| `scripts/publish-swiftkit-core.gradle` | Re-publishes swiftkit-core JAR to GCS Maven. External dependency not owned by us. May integrate into plugin later. |

## Stale docs (review)

| File | Action |
|------|--------|
| `DISTRIBUTION.md` | Review — may be outdated. Update or delete. |
| `PUBLISHING.md` | Review — references old android/ structure. Update or delete. |
| `WORKPLAN-GRAPHQL.md` | Completed work. Delete if no longer relevant. |

## Execution

```bash
# On alt_build_system branch
rm -rf android/
rm scripts/bootstrap.sh scripts/build-android.sh scripts/build-xcframework.sh
rm scripts/publish-xcframework.gradle scripts/release.sh
```

## Verification

```bash
# No symlinks remain
find . -type l
# Should return nothing

# No android/ directory
ls android/
# Should say "No such file or directory"

# scripts/ only has publish-swiftkit-core.gradle
ls scripts/
# publish-swiftkit-core.gradle
```
