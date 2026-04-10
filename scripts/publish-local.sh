#!/usr/bin/env bash
# publish-local.sh — Build and publish both iOS XCFramework and Android AAR locally.
#
# Runs the iOS and Android builds in PARALLEL, waits for both, then prints
# ready-to-paste consumer snippets for each platform.
#
# Outputs (all under <repo-root>/build/local-publish/):
#   ios/SwiftAndroidSDK.xcframework.zip     — XCFramework archive
#   ios/SwiftAndroidSDK.xcframework.checksum — SHA-256 for Package.swift
#   android/                               — Maven local-file repo layout
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

# ─── iOS build (background) ──────────────────────────────────────────────────
section "iOS — building XCFramework (background)"

IOS_LOG="$LOG_DIR/ios-build.log"
IOS_PID_FILE="$LOG_DIR/ios.pid"

(
    set -euo pipefail
    BUILD="$ROOT/build/xc"
    rm -rf "$BUILD"

    log "Archiving iOS device slice..." | tee -a "$IOS_LOG"
    xcodebuild archive \
        -scheme SwiftAndroidSDK \
        -destination "generic/platform=iOS" \
        -archivePath "$BUILD/SwiftAndroidSDK-iOS.xcarchive" \
        SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        -quiet >> "$IOS_LOG" 2>&1

    log "Archiving iOS Simulator slice..." | tee -a "$IOS_LOG"
    xcodebuild archive \
        -scheme SwiftAndroidSDK \
        -destination "generic/platform=iOS Simulator" \
        -archivePath "$BUILD/SwiftAndroidSDK-iOS-Sim.xcarchive" \
        SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        -quiet >> "$IOS_LOG" 2>&1

    log "Creating XCFramework..." | tee -a "$IOS_LOG"
    xcodebuild -create-xcframework \
        -framework "$BUILD/SwiftAndroidSDK-iOS.xcarchive/Products/Library/Frameworks/SwiftAndroidSDK.framework" \
        -framework "$BUILD/SwiftAndroidSDK-iOS-Sim.xcarchive/Products/Library/Frameworks/SwiftAndroidSDK.framework" \
        -output "$BUILD/SwiftAndroidSDK.xcframework" >> "$IOS_LOG" 2>&1

    ZIPNAME="SwiftAndroidSDK-$VERSION.xcframework.zip"
    zip -qr "$IOS_OUT/$ZIPNAME" "$BUILD/SwiftAndroidSDK.xcframework"
    shasum -a 256 "$IOS_OUT/$ZIPNAME" | awk '{print $1}' > "$IOS_OUT/$ZIPNAME.sha256"

    ok "XCFramework built → $IOS_OUT/$ZIPNAME" | tee -a "$IOS_LOG"
) &
IOS_PID=$!
echo $IOS_PID > "$IOS_PID_FILE"
log "iOS build started (PID $IOS_PID) — tail $IOS_LOG to watch"

# ─── Android build (background) ──────────────────────────────────────────────
section "Android — building AAR + publishing to local repo (background)"

ANDROID_LOG="$LOG_DIR/android-build.log"
ANDROID_PID_FILE="$LOG_DIR/android.pid"

(
    set -euo pipefail
    cd "$ANDROID_DIR"

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
    ZIPNAME="SwiftAndroidSDK-$VERSION.xcframework.zip"
    CHECKSUM=$(cat "$IOS_OUT/$ZIPNAME.sha256" 2>/dev/null || echo "<checksum unavailable>")
    ok "iOS XCFramework"
    echo "   File:     $IOS_OUT/$ZIPNAME"
    echo "   Checksum: $CHECKSUM"
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

ZIPNAME="SwiftAndroidSDK-$VERSION.xcframework.zip"
CHECKSUM=$(cat "$IOS_OUT/$ZIPNAME.sha256" 2>/dev/null || echo "<checksum>")

cat <<EOF

── iOS (Swift Package Manager) ─────────────────────────────────────────────

  // Package.swift — binary distribution (pre-built XCFramework)
  .package(
      url: "https://github.com/erikg84/SwiftAndroidSdk",
      from: "$VERSION"
  )

  // Or point at the local zip for testing:
  .binaryTarget(
      name: "SwiftAndroidSDK",
      path: "$IOS_OUT/$ZIPNAME"
  )
  // Checksum: $CHECKSUM

── Android (Gradle) ─────────────────────────────────────────────────────────

  // settings.gradle(.kts) — add local repo for testing
  dependencyResolutionManagement {
      repositories {
          maven { url = uri("$ANDROID_OUT") }
          mavenCentral()
      }
  }

  // build.gradle(.kts)
  implementation("io.github.erikg84:swift-android-sdk:$VERSION")

─────────────────────────────────────────────────────────────────────────────

Logs: $LOG_DIR/
EOF
