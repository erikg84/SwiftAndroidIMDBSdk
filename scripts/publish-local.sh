#!/usr/bin/env bash
# publish-local.sh — Validate iOS SPM package and publish Android AAR locally.
#
# Runs both platforms in PARALLEL, waits for both, then prints consumer snippets.
#
# iOS strategy:
#   XCFramework binary creation requires BUILD_LIBRARY_FOR_DISTRIBUTION=YES on
#   ALL transitive dependencies (including Factory). Factory 2.x has a known
#   Swift 6.3 naming-conflict bug in its .swiftinterface (Factory<T> struct vs
#   Factory module name) that causes archive failure. XCFramework builds are
#   therefore deferred to GitHub Actions CI where the environment can be fully
#   controlled. Locally we validate that the SPM source package builds cleanly
#   and package the source tree — the primary iOS distribution is source-via-SPM.
#
# Android strategy:
#   If swiftkit-core (the Java runtime from swift-java) is not yet published to
#   Maven Local, it is bootstrapped automatically from the swift-java SPM checkout
#   before the main Gradle build runs.
#
# Outputs (all under <repo-root>/build/local-publish/):
#   ios/SwiftAndroidSDK-<version>-sources.zip  — Source zip for local SPM testing
#   android/                                   — Maven local-file repo layout
#     io/github/erikg84/swift-android-sdk/<version>/*.aar
#
# Usage:
#   bash scripts/publish-local.sh            # uses VERSION_NAME from gradle.properties
#   bash scripts/publish-local.sh 1.2.0      # override version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
ANDROID_DIR="$ROOT/android"
OUT="$ROOT/build/local-publish"
IOS_OUT="$OUT/ios"
ANDROID_OUT="$OUT/android"
LOG_DIR="$OUT/logs"

# ─── Helpers ─────────────────────────────────────────────────────────────────
log()     { echo "[$(date +%H:%M:%S)] ▶ $*"; }
ok()      { echo "[$(date +%H:%M:%S)] ✅ $*"; }
section() { echo ""; echo "━━━ $* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }
fail()    { echo "❌ $*" >&2; exit 1; }

# ─── Version ─────────────────────────────────────────────────────────────────
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    VERSION=$(grep '^VERSION_NAME=' "$ANDROID_DIR/gradle.properties" | cut -d= -f2)
fi
[[ -z "$VERSION" ]] && fail "Could not determine version. Pass it explicitly: bash publish-local.sh 1.0.0"
log "Publishing SDK version $VERSION locally"

# ─── Prerequisite checks ─────────────────────────────────────────────────────
section "Preflight checks"

if ! command -v xcodebuild &>/dev/null; then
    fail "xcodebuild not found. This script must run on macOS with Xcode installed."
fi

GRADLEW="$ANDROID_DIR/gradlew"
if [[ ! -f "$GRADLEW" ]]; then
    fail "Gradle wrapper not found. Run scripts/bootstrap.sh first."
fi

# Activate open-source Swift toolchain (required for Android cross-compile)
if [[ -f "$HOME/.swiftly/env.sh" ]]; then
    source "$HOME/.swiftly/env.sh"
    log "swiftly toolchain activated: $(swift --version 2>&1 | head -1)"
fi

mkdir -p "$IOS_OUT" "$ANDROID_OUT" "$LOG_DIR"

# ─── iOS — source validation + zip (background) ──────────────────────────────
section "iOS — validating SPM package + creating source zip (background)"

IOS_LOG="$LOG_DIR/ios-build.log"

(
    set -euo pipefail

    log "Building iOS/macOS package with swift build..." | tee "$IOS_LOG"
    # swift build on the host validates the package compiles and all
    # dependencies resolve. We target macOS (the host) since we don't have
    # a cross-compile toolchain for iOS installed here.
    cd "$ROOT"
    swift build 2>&1 | tee -a "$IOS_LOG"

    log "Running tests..." | tee -a "$IOS_LOG"
    swift test --parallel 2>&1 | tee -a "$IOS_LOG"

    log "Packaging source zip..." | tee -a "$IOS_LOG"
    ZIPNAME="SwiftAndroidSDK-$VERSION-sources.zip"
    cd "$ROOT"
    zip -qr "$IOS_OUT/$ZIPNAME" \
        Package.swift \
        Sources/ \
        --exclude "*.DS_Store" \
        --exclude "*/.build/*"
    shasum -a 256 "$IOS_OUT/$ZIPNAME" | awk '{print $1}' > "$IOS_OUT/$ZIPNAME.sha256"

    ok "iOS source package ready → $IOS_OUT/$ZIPNAME" | tee -a "$IOS_LOG"
) &
IOS_PID=$!
log "iOS build started (PID $IOS_PID) — tail $IOS_LOG to watch"

# ─── Android build (background) ──────────────────────────────────────────────
section "Android — bootstrapping + building AAR (background)"

ANDROID_LOG="$LOG_DIR/android-build.log"
ANDROID_PID_FILE="$LOG_DIR/android.pid"

(
    set -euo pipefail
    cd "$ANDROID_DIR"

    # ── Bootstrap swiftkit-core (swift-java Java runtime) ────────────────────
    # swiftkit-core is the Java-side runtime for the JNI bridge. It is not yet
    # published to Maven Central, so we must publish it to Maven Local from the
    # swift-java SPM checkout on first use (one-time per machine).
    SWIFTKIT_MARKER="$HOME/.m2/repository/org/swift/swiftkit/swiftkit-core"
    if [[ ! -d "$SWIFTKIT_MARKER" ]]; then
        log "Bootstrapping swiftkit-core → Maven Local (one-time setup)..." | tee -a "$ANDROID_LOG"
        SWIFT_JAVA_DIR="$ANDROID_DIR/.build/checkouts/swift-java"
        if [[ ! -f "$SWIFT_JAVA_DIR/gradlew" ]]; then
            # Ensure swift-java is checked out by resolving SPM dependencies first
            log "Resolving swift-java SPM dependency..." | tee -a "$ANDROID_LOG"
            (cd "$ANDROID_DIR" && swift package resolve 2>&1 | tee -a "$ANDROID_LOG")
        fi
        if [[ -f "$SWIFT_JAVA_DIR/gradlew" ]]; then
            (cd "$SWIFT_JAVA_DIR" && \
                ./gradlew :SwiftKitCore:publishToMavenLocal \
                    -PskipSamples=true \
                    --no-daemon \
                    2>&1 | tee -a "$ANDROID_LOG")
            ok "swiftkit-core published to Maven Local" | tee -a "$ANDROID_LOG"
        else
            echo "⚠️  swift-java checkout not found — swiftkit-core bootstrap skipped" | tee -a "$ANDROID_LOG"
            echo "   Run manually: cd android && swift package resolve && cd .build/checkouts/swift-java && ./gradlew :SwiftKitCore:publishToMavenLocal -PskipSamples=true" | tee -a "$ANDROID_LOG"
        fi
    else
        log "swiftkit-core already in Maven Local — skipping bootstrap" | tee -a "$ANDROID_LOG"
    fi

    # Update version in gradle.properties for this build
    sed -i.bak "s/^VERSION_NAME=.*/VERSION_NAME=$VERSION/" gradle.properties
    rm -f gradle.properties.bak

    log "Running Gradle publishReleasePublicationToLocalFileRepository..." | tee -a "$ANDROID_LOG"
    ./gradlew publishReleasePublicationToLocalFileRepository \
        -Pmaven.repo.local="$ANDROID_OUT" \
        --no-daemon >> "$ANDROID_LOG" 2>&1

    ok "Android AAR published → $ANDROID_OUT" | tee -a "$ANDROID_LOG"
) &
ANDROID_PID=$!
echo $ANDROID_PID > "$ANDROID_PID_FILE"
log "Android build started (PID $ANDROID_PID) — tail $ANDROID_LOG to watch"

# ─── Wait for both ───────────────────────────────────────────────────────────
section "Waiting for parallel builds"

IOS_STATUS=0
ANDROID_STATUS=0

log "Waiting for iOS build (PID $IOS_PID)..."
wait "$IOS_PID" || IOS_STATUS=$?

log "Waiting for Android build (PID $ANDROID_PID)..."
wait "$ANDROID_PID" || ANDROID_STATUS=$?

# ─── Results ─────────────────────────────────────────────────────────────────
section "Results"

if [[ $IOS_STATUS -ne 0 ]]; then
    echo "❌ iOS build FAILED — see $IOS_LOG"
    echo ""
    tail -30 "$IOS_LOG"
else
    ZIPNAME="SwiftAndroidSDK-$VERSION-sources.zip"
    CHECKSUM=$(cat "$IOS_OUT/$ZIPNAME.sha256" 2>/dev/null || echo "<checksum unavailable>")
    ok "iOS source package"
    echo "   File:     $IOS_OUT/$ZIPNAME"
    echo "   Checksum: $CHECKSUM"
    echo "   Note: XCFramework binary is built in CI (GitHub Actions release.yml)"
fi

echo ""

if [[ $ANDROID_STATUS -ne 0 ]]; then
    echo "❌ Android build FAILED — see $ANDROID_LOG"
    echo ""
    tail -30 "$ANDROID_LOG"
else
    AAR=$(find "$ANDROID_OUT" -name "*.aar" 2>/dev/null | head -1)
    ok "Android AAR"
    echo "   Local repo: $ANDROID_OUT"
    echo "   AAR:        ${AAR:-<not found>}"
fi

# Bail if either failed
if [[ $IOS_STATUS -ne 0 || $ANDROID_STATUS -ne 0 ]]; then
    exit 1
fi

# ─── Consumer snippets ───────────────────────────────────────────────────────
section "Consumer integration snippets"

ZIPNAME="SwiftAndroidSDK-$VERSION-sources.zip"
CHECKSUM=$(cat "$IOS_OUT/$ZIPNAME.sha256" 2>/dev/null || echo "<checksum>")

cat <<EOF

── iOS (Swift Package Manager — source) ────────────────────────────────────
  // Recommended: add via GitHub URL in Xcode or Package.swift
  .package(
      url: "https://github.com/erikg84/SwiftAndroidSdk",
      from: "$VERSION"
  )

  // Local source zip for offline testing:
  // Unzip $IOS_OUT/$ZIPNAME
  // Then: .package(path: "/path/to/SwiftAndroidSDK")

  // XCFramework binary: built by GitHub Actions on release tag.
  // See .github/workflows/release.yml

── Android (Gradle) ─────────────────────────────────────────────────────────

  // settings.gradle(.kts) — add local repo for testing
  dependencyResolutionManagement {
      repositories {
          maven { url = uri("$ANDROID_OUT") }
          mavenLocal()   // needed for swiftkit-core
          mavenCentral()
      }
  }

  // build.gradle(.kts)
  implementation("io.github.erikg84:swift-android-sdk:$VERSION")

─────────────────────────────────────────────────────────────────────────────

Logs: $LOG_DIR/
EOF
