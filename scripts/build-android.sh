#!/usr/bin/env bash
# build-android.sh — Build the Android AAR from Swift source.
#
# Prerequisites: run scripts/bootstrap.sh once first.
#
# Usage:
#   bash scripts/build-android.sh [--release]
#
# Outputs:
#   android/build/outputs/aar/swift-android-sdk-release.aar  (--release)
#   android/build/outputs/aar/swift-android-sdk-debug.aar    (default)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_DIR="$(dirname "$SCRIPT_DIR")/android"

VARIANT="debug"
[[ "${1:-}" == "--release" ]] && VARIANT="release"

log()  { echo "▶ $*"; }
ok()   { echo "✅ $*"; }

cd "$ANDROID_DIR"

GRADLEW="$ANDROID_DIR/gradlew"
if [[ ! -f "$GRADLEW" ]]; then
    echo "❌ Gradle wrapper not found. Run scripts/bootstrap.sh first." >&2
    exit 1
fi

if [[ "$VARIANT" == "release" ]]; then
    log "Building Android AAR (release)..."
    "$GRADLEW" assembleRelease
    AAR="$ANDROID_DIR/build/outputs/aar/swift-android-sdk-release.aar"
else
    log "Building Android AAR (debug)..."
    "$GRADLEW" assembleDebug
    AAR="$ANDROID_DIR/build/outputs/aar/swift-android-sdk-debug.aar"
fi

ok "AAR built: $AAR"
echo "Size: $(du -sh "$AAR" | cut -f1)"
