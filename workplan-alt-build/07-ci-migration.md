# 07 — CI Migration

## Goal
Replace the two-job, 375-line release.yml with a single-job workflow that runs `./gradlew publishAll`.

## Current release.yml (before)

```
Jobs:
  build-aar (60 min):
    - Inspect runner state
    - Configure JDK 17 + Android NDK + Swift
    - Verify Swift Android SDK
    - Override version (dispatch only)
    - Resolve swift-java SPM
    - Bootstrap swiftkit-core (with JDK patching)
    - Authenticate to GCP
    - Publish swiftkit-core to GCS Maven
    - Build Android AAR
    - Publish AAR to GCS Maven
    - Verify AAR

  build-xcframework (60 min):
    - Inspect Xcode
    - Override version (dispatch only)
    - Build XCFramework (shell script)
    - Authenticate to GCP
    - Publish XCFramework to GCS Maven (Gradle script)
    - Upload to Gitea Swift Registry (curl)
```

**Total: ~375 lines, 2 parallel jobs, 20+ steps**

## New release.yml (after)

```yaml
name: Release

on:
  push:
    tags: ['v*']
  workflow_dispatch:
    inputs:
      version:
        description: 'Release version (e.g. 1.2.0)'
        required: false

permissions:
  contents: read
  packages: read

jobs:
  publish:
    runs-on: [self-hosted, mac-studio]
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4

      - name: Configure environment
        run: |
          JDK17="$(/usr/libexec/java_home -v 17)"
          echo "JAVA_HOME=$JDK17" >> "$GITHUB_ENV"
          echo "$JDK17/bin" >> "$GITHUB_PATH"
          echo "/opt/homebrew/bin" >> "$GITHUB_PATH"

      - name: Override version (workflow_dispatch)
        if: github.event_name == 'workflow_dispatch' && inputs.version != ''
        run: sed -i.bak "s/^VERSION_NAME=.*/VERSION_NAME=${{ inputs.version }}/" gradle.properties

      - name: Authenticate to GCP
        env:
          GCS_SA_KEY_JSON: ${{ secrets.GCS_SA_KEY_JSON }}
        run: |
          echo "$GCS_SA_KEY_JSON" > "$RUNNER_TEMP/gcs-key.json"
          echo "GOOGLE_APPLICATION_CREDENTIALS=$RUNNER_TEMP/gcs-key.json" >> "$GITHUB_ENV"

      - name: Publish all artifacts
        run: ./gradlew publishAll --no-daemon
        env:
          GITEA_URL: ${{ secrets.GITEA_URL }}
          GITEA_TOKEN: ${{ secrets.GITEA_TOKEN }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Total: ~35 lines, 1 job, 4 steps**

## What the plugin handles internally

The `publishAll` task orchestrates everything that was previously spread across 20+ CI steps:

1. `swiftResolve` — resolves SPM dependencies
2. `bootstrapSwiftkitCore` — patches + builds swiftkit-core to Maven Local
3. `buildSwiftAndroid` — cross-compiles for each ABI
4. `copyJniLibs` — bundles .so + runtime
5. `assembleRelease` — produces AAR
6. `publishAndroid` → GCS Maven
7. `buildIosDevice` + `buildIosSimulator` — archives
8. `assembleXCFramework` — creates XCFramework
9. `zipXCFramework` — zip + checksum
10. `publishIosGcs` → GCS
11. `publishIosGitea` → Gitea registry

## New ci.yml

```yaml
name: CI

on:
  push:
    branches: [main, alt_build_system]
  pull_request:

jobs:
  test:
    runs-on: [self-hosted, mac-studio]
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4

      - name: Configure environment
        run: |
          echo "JAVA_HOME=$(/usr/libexec/java_home -v 17)" >> "$GITHUB_ENV"
          echo "/opt/homebrew/bin" >> "$GITHUB_PATH"

      - name: Swift tests
        run: swift test
        env:
          TMDB_READ_TOKEN: ${{ secrets.TMDB_READ_TOKEN }}

      - name: Build all (no publish)
        run: ./gradlew buildAll --no-daemon
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Secrets Required (unchanged)

| Secret | Used by |
|--------|---------|
| `GCS_SA_KEY_JSON` | GCP authentication for GCS upload |
| `GITEA_URL` | Gitea registry URL |
| `GITEA_TOKEN` | Gitea API token |
| `TMDB_READ_TOKEN` | Integration tests |
| `GITHUB_TOKEN` | Plugin resolution from GitHub Packages (auto-provided) |

## swiftkit-core Re-publishing

The current workflow re-publishes swiftkit-core to GCS Maven. This is NOT yet handled by the plugin. Options:

1. **Keep as separate CI step** (add after `publishAll`):
   ```yaml
   - name: Publish swiftkit-core to GCS Maven
     run: |
       JAR=$(find ~/.m2/repository/org/swift/swiftkit/swiftkit-core/1.0-SNAPSHOT -name "swiftkit-core-*.jar" ! -name "*sources*" ! -name "*javadoc*" | head -1)
       gradle -p "$RUNNER_TEMP/swiftkit-pub" publishSwiftkitCorePublicationToGCSRepository -PjarPath="$JAR" --no-daemon
     shell: bash
   ```

2. **Integrate into plugin later** — add a `republishSwiftkitCore` task

Start with option 1 for now.

## Steps

1. Write new `release.yml` on alt_build_system branch
2. Write new `ci.yml` on alt_build_system branch
3. Test CI locally: `./gradlew buildAll`
4. Push and verify CI runs
5. Tag to test release workflow
