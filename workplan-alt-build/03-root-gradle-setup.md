# 03 — Root Gradle Setup

## Goal
Create the Gradle build files at the project root that apply the swift-multiplatform plugin.

## Files to Create

### settings.gradle.kts

```kotlin
pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
        mavenCentral()
        maven {
            name = "DallasLabsPlugins"
            url = uri("https://maven.pkg.github.com/erikg84/swift-multiplatform-gradle-plugin")
            credentials {
                username = providers.gradleProperty("gpr.user").orNull
                    ?: System.getenv("GITHUB_ACTOR") ?: ""
                password = providers.gradleProperty("gpr.key").orNull
                    ?: System.getenv("GITHUB_TOKEN") ?: ""
            }
        }
    }
}

dependencyResolutionManagement {
    repositoriesMode = RepositoriesMode.FAIL_ON_PROJECT_REPOS
    repositories {
        mavenLocal()
        google()
        mavenCentral()
    }
}

rootProject.name = "SwiftAndroidSDK"
```

### build.gradle.kts

```kotlin
plugins {
    id("com.dallaslabs.swift-multiplatform") version "0.1.1"
}

swiftMultiplatform {
    moduleName = "SwiftAndroidSDK"
    sourcesDir = "Sources/SwiftAndroidSDK"
    version = providers.gradleProperty("VERSION_NAME")

    android {
        abis("arm64-v8a", "x86_64")
        swiftSdk("swift-6.3-RELEASE_android.artifactbundle")
        minSdk(28)
        compileSdk(36)
        jextract(enabled = true)
        namespace("io.github.erikg84.swiftandroidsdk")
        excludeFromSwift("Container/TMDBContainerTestHooks.swift", "swift-java.config")
    }

    ios {
        targets("ios-arm64", "ios-simulator-arm64")
        minimumDeployment("15.0")
        frameworkName("SwiftAndroidSDK")
        buildScript("scripts/build-xcframework.sh")  // keep custom script initially
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

dependencies {
    implementation("org.swift.swiftkit:swiftkit-core:1.0-SNAPSHOT")
}
```

### gradle.properties

```properties
# SDK version — single source of truth
VERSION_NAME=1.2.0

# Maven coordinates
GROUP_ID=com.dallaslabs.sdk
ARTIFACT_ID=swift-android-sdk

# GitHub Packages (plugin resolution)
# Set in ~/.gradle/gradle.properties or CI env vars:
# gpr.user=erikg84
# gpr.key=ghp_xxxxx

# Gitea (CI: from secrets; local: set here or in ~/.gradle/gradle.properties)
# GITEA_URL=http://34.60.86.141:3000
# GITEA_TOKEN=your_token

# Gradle
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
```

## ios.buildScript Decision

The current `scripts/build-xcframework.sh` does a non-standard XCFramework build:
1. Archives each platform
2. Manually extracts .o files from the archive
3. Reassembles a static framework using libtool
4. Creates XCFramework from the reassembled frameworks

This is needed because SPM library targets don't produce a standard .framework in the archive.

**Strategy:** Keep the custom script initially via `ios { buildScript = "scripts/build-xcframework.sh" }`. The plugin delegates to it. If standard `xcodebuild archive + create-xcframework` works in testing, we can remove the buildScript line and delete the script.

**Note:** If keeping build-xcframework.sh, it stays in scripts/ but needs a minor update — it currently reads VERSION_NAME from `android/gradle.properties`. After migration, it should read from root `gradle.properties`:

```diff
- VERSION=$(grep '^VERSION_NAME=' android/gradle.properties | cut -d= -f2)
+ VERSION=$(grep '^VERSION_NAME=' gradle.properties | cut -d= -f2)
```

## Credential Flow

| Credential | Local Dev | CI |
|------------|-----------|-----|
| `gpr.user` / `gpr.key` | `~/.gradle/gradle.properties` | `GITHUB_ACTOR` / `GITHUB_TOKEN` env vars |
| `GITEA_URL` / `GITEA_TOKEN` | `~/.gradle/gradle.properties` or root `gradle.properties` | Secrets → env vars |
| `GOOGLE_APPLICATION_CREDENTIALS` | gcloud auth | `GCS_SA_KEY_JSON` secret → file |

## Verification

```bash
# Gradle resolves the plugin
./gradlew tasks --group swift
# Should list: swiftResolve, buildSwiftAndroid, assembleXCFramework, buildAll, publishAll, etc.

# Plugin configures Android correctly
./gradlew :dependencies
# Should show swiftkit-core dependency
```
