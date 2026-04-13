plugins {
    id("com.dallaslabs.swift-multiplatform") version "0.1.10"
}

swiftMultiplatform {
    moduleName.set("SwiftAndroidSDK")
    sourcesDir.set("Sources/SwiftAndroidSDK")
    version.set(providers.gradleProperty("VERSION_NAME"))

    android {
        abis("arm64-v8a", "x86_64")
        swiftSdk.set("swift-6.3-RELEASE_android.artifactbundle")
        swiftVersion.set("6.3")
        minSdk.set(28)
        compileSdk.set(36)
        jextract(enabled = true)
        namespace.set("io.github.erikg84.swiftandroidsdk")
        excludeFromSwift("Container/TMDBContainerTestHooks.swift", "swift-java.config")
    }

    ios {
        targets("ios-arm64", "ios-simulator-arm64")
        minimumDeployment.set("15.0")
        frameworkName.set("SwiftAndroidSDK")
        buildScript.set("scripts/build-xcframework.sh")
    }

    publishing {
        maven {
            groupId.set("com.dallaslabs.sdk")
            artifactId.set("swift-android-sdk")
            repository.set("gcs://dallaslabs-sdk-artifacts/maven")
        }
        gitea {
            registryUrl.set(providers.gradleProperty("GITEA_URL"))
            token.set(providers.gradleProperty("GITEA_TOKEN"))
            scope.set("dallaslabs-sdk")
            packageName.set("swift-android-sdk")
        }
    }
}

dependencies {
    "implementation"("org.swift.swiftkit:swiftkit-core:1.0-SNAPSHOT")
}
