# 04 — Gradle Wrapper

## Goal
Initialize the Gradle wrapper at the project root. The android/ subdirectory had its own wrapper — that's being deleted.

## Current State
- `android/gradlew` exists with Gradle 6.8.3 (very old)
- No wrapper at project root

## Action

```bash
cd /Volumes/EXTERNAL-DRIVE/Documents/SwiftAndroidSdk
gradle wrapper --gradle-version 8.11.1
```

This creates:
- `gradlew` (Unix)
- `gradlew.bat` (Windows)
- `gradle/wrapper/gradle-wrapper.jar`
- `gradle/wrapper/gradle-wrapper.properties`

## Gradle Version: 8.11.1

Matches the version used by the plugin project. Compatible with:
- AGP 8.7.3 (Android Gradle Plugin)
- Kotlin DSL
- Java 17 toolchain
- Composite builds

## .gitignore Updates

Ensure the root `.gitignore` includes:

```
.gradle/
build/
.build/
local.properties
```

The `gradle/wrapper/gradle-wrapper.jar` SHOULD be committed (standard practice — ensures reproducible builds without requiring Gradle pre-installed).

## Verification

```bash
./gradlew --version
# Should show Gradle 8.11.1
```
