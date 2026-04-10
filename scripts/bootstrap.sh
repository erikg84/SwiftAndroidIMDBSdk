#!/usr/bin/env bash
# bootstrap.sh — One-time developer setup.
# Run this ONCE after cloning the repo, before building for Android.
#
# What it does:
#   1. Verifies Swift 6.3 is active via swiftly
#   2. Verifies the Swift SDK for Android is installed
#   3. Verifies Android NDK is discoverable
#   4. Publishes swift-java support libraries to local Maven (~/.m2)
#   5. Downloads the Gradle wrapper binary
#
# Usage:
#   cd /path/to/SwiftAndroidSdk
#   bash scripts/bootstrap.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_ROOT="$(dirname "$SCRIPT_DIR")"
ANDROID_DIR="$SDK_ROOT/android"

log()  { echo "▶ $*"; }
ok()   { echo "✅ $*"; }
fail() { echo "❌ $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Check swiftly + Swift 6.3
# ---------------------------------------------------------------------------
log "Checking Swift toolchain..."
if ! command -v swiftly &>/dev/null; then
    fail "swiftly not found. Install from https://swift.org/install/"
fi

SWIFT_VERSION=$(swiftly run swift --version 2>&1 | grep -oE '6\.[0-9]+\.[0-9]+' | head -1 || true)
if [[ "$SWIFT_VERSION" != 6.* ]]; then
    log "Installing Swift 6.3..."
    swiftly install 6.3 --use
fi
ok "Swift $(swiftly run swift --version 2>&1 | head -1)"

# ---------------------------------------------------------------------------
# 2. Check Swift SDK for Android
# ---------------------------------------------------------------------------
log "Checking Swift SDK for Android..."
if ! swiftly run swift sdk list 2>/dev/null | grep -q 'android'; then
    fail "Swift SDK for Android not installed.\n" \
         "Run: swift sdk install https://download.swift.org/swift-6.3-release/android-sdk/swift-6.3-RELEASE/swift-6.3-RELEASE_android.artifactbundle.tar.gz \\\n" \
         "       --checksum 2f2942c4bcea7965a08665206212c66991dabe23725aeec7c4365fc91acad088"
fi
ok "Swift SDK for Android: $(swiftly run swift sdk list | grep android | head -1)"

# ---------------------------------------------------------------------------
# 3. Check Android NDK
# ---------------------------------------------------------------------------
log "Checking Android NDK..."
NDK_SEARCH_PATHS=(
    "${ANDROID_NDK_HOME:-}"
    "$HOME/Library/Android/sdk/ndk/27*"
    "$HOME/Library/org.swift.swiftpm/swift-sdks/swift-6.3-RELEASE_android.artifactbundle/swift-android/android-ndk-r27d"
)
NDK_FOUND=""
for p in "${NDK_SEARCH_PATHS[@]}"; do
    for expanded in $p; do
        if [[ -d "$expanded" ]]; then NDK_FOUND="$expanded"; break 2; fi
    done
done

if [[ -z "$NDK_FOUND" ]]; then
    echo "⚠️  Android NDK not found automatically."
    echo "   Set ANDROID_NDK_HOME or place NDK r27d in a standard location."
    echo "   See: https://developer.android.com/ndk/downloads/"
else
    ok "Android NDK: $NDK_FOUND"
fi

# ---------------------------------------------------------------------------
# 4. Check JDK
# ---------------------------------------------------------------------------
log "Checking JDK..."
JAVA_VERSION=$(java -version 2>&1 | grep -oE '[0-9]+' | head -1)
if (( JAVA_VERSION < 17 )); then
    fail "JDK 17+ required (found JDK $JAVA_VERSION). Install via sdkman or brew."
fi
ok "JDK $JAVA_VERSION"

if (( JAVA_VERSION < 25 )); then
    echo "⚠️  JDK 25 is needed for the swift-java publishToMavenLocal step."
    echo "   Install with: sdk install java 25.0.1-amzn && sdk use java 25.0.1-amzn"
fi

# ---------------------------------------------------------------------------
# 5. Publish swift-java support libs to local Maven
# ---------------------------------------------------------------------------
log "Resolving swift-java dependency..."
cd "$ANDROID_DIR"
swiftly run swift +6.3 package resolve

SWIFT_JAVA_DIR="$ANDROID_DIR/.build/checkouts/swift-java"
if [[ ! -d "$SWIFT_JAVA_DIR" ]]; then
    fail "swift-java checkout not found at $SWIFT_JAVA_DIR after package resolve."
fi

log "Publishing swift-java support libs to ~/.m2 (requires JDK 25)..."
"$SWIFT_JAVA_DIR/gradlew" --project-dir "$SWIFT_JAVA_DIR" \
    :SwiftKitCore:publishToMavenLocal
ok "swift-java support libs published to ~/.m2"

# ---------------------------------------------------------------------------
# 6. Download Gradle wrapper binary
# ---------------------------------------------------------------------------
log "Setting up Gradle wrapper..."
WRAPPER_JAR="$ANDROID_DIR/gradle/wrapper/gradle-wrapper.jar"
if [[ ! -f "$WRAPPER_JAR" ]]; then
    # Download a known-good wrapper jar from the Gradle distributions.
    curl -fSL -o "$WRAPPER_JAR" \
        "https://raw.githubusercontent.com/nicowillis/gradle-wrapper-jar/main/gradle-wrapper-6.8.3.jar" \
        2>/dev/null || {
        # Fallback: use gradle if installed
        if command -v gradle &>/dev/null; then
            cd "$ANDROID_DIR" && gradle wrapper
        else
            echo "⚠️  Could not download gradle-wrapper.jar."
            echo "   Either install Gradle (brew install gradle) and run: cd android && gradle wrapper"
            echo "   Or download manually from: https://gradle.org/releases/"
        fi
    }
fi
[[ -f "$WRAPPER_JAR" ]] && ok "Gradle wrapper ready" || echo "⚠️  Gradle wrapper not yet set up — run: cd android && gradle wrapper"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Bootstrap complete. To build the Android AAR:"
echo "  bash scripts/build-android.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
