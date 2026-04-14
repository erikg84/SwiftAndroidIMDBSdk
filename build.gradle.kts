plugins {
    id("io.multiplatform.swift.sdk") version "1.0.1"
}

swiftMultiplatform {
    moduleName("SwiftAndroidSDK")
    sources("Sources/SwiftAndroidSDK")
    version(providers.gradleProperty("VERSION_NAME"))

    android {
        abis("arm64-v8a", "x86_64")
        swiftSdk("swift-6.3-RELEASE_android.artifactbundle")
        swiftVersion("6.3")
        minSdk(28)
        compileSdk(36)
        jextract(true)
        namespace("io.github.erikg84.swiftandroidsdk")
        excludeFiles("Container/TMDBContainerTestHooks.swift", "swift-java.config")
    }

    ios {
        deploymentTarget("15.0")
        frameworkName("SwiftAndroidSDK")
        buildScript("scripts/build-xcframework.sh")
    }

    publishing {
        maven {
            groupId("com.dallaslabs.sdk")
            artifactId("swift-android-sdk")
            url("gcs://dallaslabs-sdk-artifacts/maven")
        }
        swiftRegistry {
            url(providers.environmentVariable("GITEA_URL"))
            token(providers.environmentVariable("GITEA_TOKEN"))
            scope("dallaslabs-sdk")
            packageName("swift-android-sdk")
            authorName("Dallas Labs")
        }
    }
}

dependencies {
    "implementation"("org.swift.swiftkit:swiftkit-core:1.0-SNAPSHOT")
}
