# 06 — Publish Validation

## Goal
Verify that `./gradlew publishAll` publishes artifacts to GCS Maven, GCS (XCFramework), and Gitea Swift Registry.

## Pre-requisites
- GCP authenticated (`GOOGLE_APPLICATION_CREDENTIALS` or `gcloud auth`)
- Gitea credentials (`GITEA_URL` + `GITEA_TOKEN` in gradle.properties or env)
- Build validation (05) passed

## Step 1: Publish Android AAR to GCS Maven

```bash
./gradlew publishAndroid
```

**Verifies:**
```bash
# Check GCS for the AAR
gcloud storage ls gs://dallaslabs-sdk-artifacts/maven/com/dallaslabs/sdk/swift-android-sdk/1.2.0/
# Should list: swift-android-sdk-1.2.0.aar, .pom, .module
```

## Step 2: Publish iOS XCFramework to GCS

```bash
./gradlew publishIosGcs
```

**Verifies:**
```bash
gcloud storage ls gs://dallaslabs-sdk-artifacts/maven/com/dallaslabs/sdk/swift-android-sdk-ios/1.2.0/
# Should list: swift-android-sdk-ios-1.2.0.zip
```

## Step 3: Publish to Gitea Swift Registry

```bash
./gradlew publishIosGitea
```

**Verifies:**
```bash
# Check Gitea registry
curl -s 'http://34.60.86.141:3000/api/packages/dallaslabs-sdk/swift/dallaslabs-sdk/swift-android-sdk/1.2.0' \
  -H 'Accept: application/vnd.swift.registry.v1+json' | python3 -m json.tool

# Should show version 1.2.0 with author.name: "Dallas Labs"

# Check Package.swift content
curl -s 'http://34.60.86.141:3000/api/packages/dallaslabs-sdk/swift/dallaslabs-sdk/swift-android-sdk/1.2.0/Package.swift' \
  -H 'Accept: application/vnd.swift.registry.v1+swift'

# Should show binaryTarget with GCS URL and correct checksum
```

## Step 4: Full Publish

```bash
./gradlew publishAll
```

**Verifies:** All three publishing tasks run in one command.

## Step 5: swiftkit-core on GCS (if needed)

The current release.yml re-publishes swiftkit-core to GCS Maven so consumers don't need `mavenLocal()`. This step uses the existing `scripts/publish-swiftkit-core.gradle`:

```bash
gradle -p /tmp/swiftkit-pub \
  publishSwiftkitCorePublicationToGCSRepository \
  -PjarPath=$(find ~/.m2/repository/org/swift/swiftkit/swiftkit-core/1.0-SNAPSHOT -name "swiftkit-core-*.jar" ! -name "*sources*" ! -name "*javadoc*" | head -1)
```

This remains a manual step or CI step — not yet integrated into the plugin.

## Version Bump Strategy

For this validation, use version `1.2.0` (bump from current `1.1.7`). This ensures:
- No conflict with existing artifacts on GCS/Gitea
- Clean verification that new artifacts were actually published
- Clear distinction from main branch artifacts

## Rollback

If publishing goes wrong:
- GCS: `gcloud storage rm gs://dallaslabs-sdk-artifacts/maven/com/dallaslabs/sdk/swift-android-sdk/1.2.0/**`
- Gitea: `curl -X DELETE 'http://34.60.86.141:3000/api/v1/packages/dallaslabs-sdk/swift/dallaslabs-sdk.swift-android-sdk/1.2.0' -H 'Authorization: token <TOKEN>'`
