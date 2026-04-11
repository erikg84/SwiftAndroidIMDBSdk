# Distribution Architecture

This document explains **how** SwiftAndroidSDK is published, **where** consumers get it, and **why** it's structured this way. If you're a consumer, jump to [Consumer setup](#consumer-setup). If you're a maintainer, you'll want all of it.

---

## TL;DR for consumers

**iOS (Swift Package Manager):**
```swift
.package(url: "https://github.com/erikg84/swift-android-idbm-sdk-spm", from: "1.0.0")
```
Plus a one-time `~/.netrc` entry for `maven.pkg.github.com` — see [Consumer setup](#consumer-setup).

**Android (Gradle):**
```groovy
implementation 'io.github.erikg84:swift-android-sdk:1.0.0'
```
Plus a one-time `settings.gradle` entry for the GitHub Packages Maven repo.

That's the whole interface. Everything below is the *why*.

---

## The problem

The source repo, `SwiftAndroidIMDBSdk`, contains a lot more than the iOS SDK:

- A Gradle Android subproject (`android/`) that cross-compiles Swift to ARM64/ARMv7/x86_64 `.so` files via `swiftly` + the Swift Android SDK
- A swift-java configuration that runs `JExtractSwiftPlugin` to generate JNI Java wrappers
- Build scripts (`scripts/`), CI workflows (`.github/workflows/`), test fixtures, screenshots
- Multi-page maintainer docs (`PUBLISHING.md`, `DISTRIBUTION.md`, `README.md`)

For an iOS consumer that just wants the compiled SDK, **none of that is useful**. But Swift Package Manager doesn't care: when you add a dependency by URL, SPM clones the **entire git repository** at the requested ref before it even reads `Package.swift`. This is a [well-documented SPM limitation](https://github.com/swiftlang/swift-package-manager/issues/6062). For our repo, that's wasted bandwidth, wasted disk, and slow `swift package resolve` for every iOS consumer.

The Android side has its own problem: shipping the AAR as a release asset means consumers have to manually download and `implementation files()` it. That's not how Android dependencies usually work — they expect a Maven coordinate.

We want **two clean coordinates**, one per platform, that consumers reference once and forget.

---

## The solution — four publishing channels, two consumer URLs

| Artifact | Where it lives | Who consumes it | Auth |
|---|---|---|---|
| **iOS SPM wrapper** (`Package.swift`) | [`erikg84/swift-android-idbm-sdk-spm`](https://github.com/erikg84/swift-android-idbm-sdk-spm) — separate repo, ~5KB total | Xcode / SPM consumers | None (public repo) |
| **iOS XCFramework** (`.zip`) | GitHub Packages Maven: `io.github.erikg84:swift-android-sdk-ios:<v>` | SPM downloads transparently from the wrapper's `binaryTarget` URL; KMP/Gradle consumers can also pull it directly | `~/.netrc` entry for `maven.pkg.github.com` (SPM auto-reads it; Gradle uses standard Maven creds) |
| **Android AAR** | GitHub Packages Maven: `io.github.erikg84:swift-android-sdk:<v>` | Gradle / Android consumers | `read:packages` PAT in `settings.gradle` credentials block |
| **GitHub Releases assets** (AAR + XCFramework zip) | The `Releases` tab on the source repo | Manual downloaders, fallback users, CI systems that don't want Maven auth | None (public release) |

The release workflow publishes all four on every tag push. **Consumers only ever need two URLs** — the SPM wrapper repo URL and the Android Maven coordinate. The other two are convenience fallbacks.

### The wrapper repo pattern

The wrapper repo ([`swift-android-idbm-sdk-spm`](https://github.com/erikg84/swift-android-idbm-sdk-spm)) contains nothing but a `Package.swift`, a `README.md`, a `LICENSE`, and a `.gitignore`. The `Package.swift` declares one `binaryTarget` whose URL points at the GitHub Packages Maven artifact for the matching version, plus the SHA-256 checksum.

When a consumer adds the wrapper repo as a dependency, SPM:
1. Clones the wrapper repo (~5KB)
2. Reads `Package.swift`
3. Sees the `binaryTarget`, fetches the URL via HTTPS
4. Reads `~/.netrc`, sends Basic Auth header to `maven.pkg.github.com`
5. Verifies the SHA-256 against the declared checksum
6. Unpacks the XCFramework into the consumer's `.build/artifacts/`

**No Android cross-compilation toolchain. No `swift-java`. No 100+MB checkout. No `swift package resolve` waiting on `.so` files.**

This is the same pattern Lottie uses ([`lottie-spm`](https://github.com/airbnb/lottie-spm)), Sparkle uses (PR [sparkle-project/Sparkle#1634](https://github.com/sparkle-project/Sparkle/pull/1634)), and Touchlab's [KMMBridge](https://kmmbridge.touchlab.co) auto-generates for KMP projects. It's the community-standard workaround for SPM's clone-the-whole-repo behavior.

### Why GitHub Packages instead of `.binaryTarget(url: "github.com/...releases/download/...")`?

We could put the XCFramework only as a GitHub Releases asset and point `binaryTarget(url:)` directly at `https://github.com/.../releases/download/v1.0.0/SwiftAndroidSDK.xcframework.zip`. That's the simplest possible setup. So why bother with GitHub Packages?

1. **Symmetry with Android.** The Android AAR has to live in GitHub Packages anyway (Maven is the canonical Android distribution channel). Putting the iOS XCFramework in the same place gives one mental model: *all SDK binaries are in GitHub Packages, indexed by Maven coordinate*. Both platforms share the `read:packages` PAT story.
2. **Standard Maven coordinate.** `io.github.erikg84:swift-android-sdk-ios:1.0.0` is a coordinate Gradle/KMP consumers can resolve. A release asset URL is opaque.
3. **Versioned, immutable, queryable.** GitHub Packages exposes a real package metadata API: list versions, query last-published, audit pulls. Release assets are just blobs.
4. **The consumer experience is unchanged.** SPM (Xcode 13.3+) reads `~/.netrc` automatically, so consumers don't see any of this — they just configure auth once and the binaryTarget URL works.

We **also** still publish to GitHub Releases as a fallback for users who refuse to set up `~/.netrc` or can't authenticate to GitHub Packages from CI. The release notes show both URLs.

---

## Consumer setup

### iOS: one-time `~/.netrc` for GitHub Packages

GitHub Packages requires authentication for **all** downloads, even from public packages. SPM (Xcode 13.3+) automatically reads `~/.netrc` and sends Basic Auth headers when downloading binary targets. The setup is one-time per developer machine and works for every package that uses GitHub Packages.

1. **Create a GitHub Personal Access Token**

   Go to https://github.com/settings/tokens (classic) or https://github.com/settings/personal-access-tokens/new (fine-grained, recommended).
   - **Classic PAT**: tick the `read:packages` scope and nothing else
   - **Fine-grained PAT**: limit to `Public repositories (read-only)` + **Permissions → Account → Packages: Read**

2. **Add to `~/.netrc`** (create the file if it doesn't exist)

   ```
   machine maven.pkg.github.com
     login <your-github-username>
     password <your-pat>
   ```

3. **Lock down the file**

   ```bash
   chmod 600 ~/.netrc
   ```

That's it. From now on, any SPM `binaryTarget(url:)` pointing at `maven.pkg.github.com/...` Just Works, in Xcode and on the command line, for this and any other SDK.

### iOS: add the dependency

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/erikg84/swift-android-idbm-sdk-spm", from: "1.0.0"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "SwiftAndroidSDK", package: "swift-android-idbm-sdk-spm")
        ]
    ),
]
```

### Android: one-time `settings.gradle` Maven repo

```groovy
// settings.gradle
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://maven.pkg.github.com/erikg84/SwiftAndroidIMDBSdk")
            credentials {
                username = settings.ext.find('gpr.user') ?: System.getenv('GITHUB_ACTOR')
                password = settings.ext.find('gpr.token') ?: System.getenv('GITHUB_TOKEN')
            }
        }
    }
}
```

Store your PAT in `~/.gradle/gradle.properties`:

```properties
gpr.user=<your-github-username>
gpr.token=<your-pat-with-read-packages>
```

Then in your module:

```groovy
// app/build.gradle
dependencies {
    implementation 'io.github.erikg84:swift-android-sdk:1.0.0'
}
```

`minSdkVersion` must be ≥ 28.

---

## Maintainer setup

Run once per release: `git tag vX.Y.Z && git push origin vX.Y.Z`. Everything else is automated. The release workflow has four jobs:

1. **`build-aar`** — cross-compiles Swift for all Android ABIs, runs JExtractSwiftPlugin, builds the release AAR, and publishes it to GitHub Packages as `io.github.erikg84:swift-android-sdk:<version>`. Idempotent on HTTP 409 (re-tag of same version is allowed).

2. **`build-xcframework`** — runs `scripts/build-xcframework.sh` which archives each platform (`iOS`, `iOS Simulator`, `macOS`) into separate DerivedData paths, libtool-merges `SwiftAndroidSDK.o + Swinject.o` into a static framework binary per platform, and feeds them into `xcodebuild -create-xcframework`. Then publishes the resulting zip to GitHub Packages as `io.github.erikg84:swift-android-sdk-ios:<version>` via `scripts/publish-xcframework.gradle`. Same idempotency on 409.

3. **`create-release`** — downloads both artifacts, creates the GitHub Release with the AAR + XCFramework as fallback assets, and writes the release notes with the canonical SPM/Gradle snippets.

4. **`update-spm-wrapper`** — clones the wrapper repo, rewrites `Package.swift` with the new version + checksum, commits, tags, and pushes. **This is the critical job that makes the SPM URL "just work" for consumers.**

### Why do we need a separate auth mechanism for `update-spm-wrapper`?

The default `GITHUB_TOKEN` injected into a workflow only has permissions on the **repo where the workflow runs**. To push to a different repo (the wrapper) we need a token that has write access there.

There are four reasonable mechanisms. Comparing them:

| Mechanism | Scriptable? | Scope | Expires? | Setup time |
|---|---|---|---|---|
| **SSH deploy key** *(what we use)* | ✅ via `gh api` | Single repo | No | ~30s |
| **GitHub App** | ❌ creation requires UI form | Multi-repo, fine-grained perms | Tokens are short-lived | ~5 min |
| **Fine-grained PAT** | ❌ creation requires UI form | Single repo, fine-grained perms | Yes (max 1y) | ~2 min |
| **Classic PAT** | ❌ creation requires UI form | Account-wide | Optional | ~1 min |

We default to the **SSH deploy key**. It's the only mechanism that can be created entirely from the command line via `gh api`, it's scoped to exactly one repo (the wrapper), and it never expires. The tradeoff vs a GitHub App is that the deploy key grants write access to *the entire repo* — there's no per-path or per-permission slicing — but for a repo containing four files, that's not a meaningful distinction.

### One-time deploy key setup (one shell session, ~30 seconds)

Run from any machine with `gh` authenticated and `repo` scope:

```bash
# 1. Generate an ed25519 keypair (no passphrase — workflow needs unattended access)
ssh-keygen -t ed25519 -N "" \
    -f /tmp/spm-wrapper-deploy \
    -C "spm-wrapper-bot@swift-android-imdb-sdk"

# 2. Register the public half on the wrapper repo as a write-enabled deploy key
gh api -X POST repos/erikg84/swift-android-idbm-sdk-spm/keys \
    -f title="release-workflow (write)" \
    -f key="$(cat /tmp/spm-wrapper-deploy.pub)" \
    -F read_only=false

# 3. Store the private half as a secret in the source repo
gh secret set SPM_WRAPPER_DEPLOY_KEY \
    -R erikg84/SwiftAndroidIMDBSdk \
    < /tmp/spm-wrapper-deploy

# 4. Scrub the local copies — the only authoritative copy is now in repo secrets
shred -uz /tmp/spm-wrapper-deploy 2>/dev/null || rm -P /tmp/spm-wrapper-deploy
rm -f /tmp/spm-wrapper-deploy.pub
```

That's the entire setup. The `update-spm-wrapper` job uses [`webfactory/ssh-agent@v0.9.0`](https://github.com/webfactory/ssh-agent) to load the private key into the runner's SSH agent at the start of the run, then clones / commits / pushes via `git@github.com:...` URLs as you normally would.

### Rotating the deploy key

If you ever need to rotate (e.g. suspected compromise):

```bash
# Find the existing key id
gh api repos/erikg84/swift-android-idbm-sdk-spm/keys \
    --jq '.[] | select(.title=="release-workflow (write)") | .id'

# Delete it
gh api -X DELETE repos/erikg84/swift-android-idbm-sdk-spm/keys/<id>

# Then re-run the four steps above to generate + register a fresh key.
```

### Alternative: GitHub App or fine-grained PAT

If you'd rather use a GitHub App for granular permissions, or a fine-grained PAT for simpler conceptual model:

- **GitHub App**: Create at https://github.com/settings/apps/new, set Repository permissions → Contents: Read and write, generate a private key, install it on the wrapper repo. Store `SPM_WRAPPER_APP_ID` and `SPM_WRAPPER_APP_PRIVATE_KEY` as secrets, and replace the SSH agent step in the workflow with [`actions/create-github-app-token@v3`](https://github.com/actions/create-github-app-token).
- **Fine-grained PAT**: Create at https://github.com/settings/personal-access-tokens/new with Repository access limited to `swift-android-idbm-sdk-spm` and Contents: Read and write. Store as `WRAPPER_REPO_TOKEN` and clone via `https://x-access-token:${{ secrets.WRAPPER_REPO_TOKEN }}@github.com/...` in the workflow.

Both require web UI clicks for creation. Both work fine. The deploy key path is just the only one that's fully `gh api` -scriptable.

---

## Why not the Swift Package Registry (SE-0292)?

The cleanest possible solution would be a real Swift Package Registry: consumers do `.package(id: "erikg84.SwiftAndroidSDK", from: "1.0.0")`, no wrapper repo, no `.netrc`, no GitHub Packages indirection. SE-0292 was accepted in 2022 and shipped in Swift 5.7.

The blocker: **GitHub Packages does not implement the SE-0292 server protocol**. As of 2026 only AWS CodeArtifact has shipped server support. The community has been [asking GitHub for it since 2022](https://github.com/orgs/community/discussions/36327) with no public timeline. Until that lands, the wrapper-repo pattern is the cleanest available approach for distributing through GitHub.

If you ever migrate to a registry that supports SE-0292 (CodeArtifact, a self-hosted [`swift-package-registry`](https://github.com/mattt/swift-package-registry-prototype) instance, or whoever ships it next), the wrapper repo can be deleted and consumers can switch to the registry URL with no other changes — the binary artifact format is identical.

---

## References

- [SPM clones whole repo issue #6062](https://github.com/swiftlang/swift-package-manager/issues/6062)
- [Touchlab KMMBridge documentation](https://kmmbridge.touchlab.co/docs/)
- [KMMBridge `MavenPublishArtifactManager.kt`](https://github.com/touchlab/KMMBridge/blob/main/kmmbridge/src/main/kotlin/co/touchlab/kmmbridge/artifactmanager/MavenPublishArtifactManager.kt) — the canonical Maven URL builder
- [`lottie-spm`](https://github.com/airbnb/lottie-spm) — production example of the wrapper-repo pattern
- [Marco Eidinger: Xcode 13.3 supports SPM binary dependency in private GitHub release](https://blog.eidinger.info/xcode-133-supports-spm-binary-dependency-in-private-github-release) — the original `~/.netrc` write-up
- [SwiftPM binary dependency in private GitHub release — Swift Forums](https://forums.swift.org/t/swiftpm-binary-dependency-in-private-github-release/52514)
- [SE-0292 Package Registry Service](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0292-package-registry-service.md)
- [GitHub community discussion: Does GitHub Package Registry support SE-0292?](https://github.com/orgs/community/discussions/36327)
- [Working with the Apache Maven registry — GitHub Docs](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-apache-maven-registry)
- [`actions/create-github-app-token`](https://github.com/actions/create-github-app-token) — the action we use for cross-repo auth
