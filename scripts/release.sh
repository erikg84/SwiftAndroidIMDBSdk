#!/usr/bin/env bash
# release.sh — Tag a new SDK release and publish both iOS and Android artifacts.
#
# What it does:
#   1. Bumps VERSION_NAME in android/gradle.properties
#   2. Creates a git tag
#   3. Builds the Android release AAR
#   4. Creates a GitHub Release with the AAR attached
#   5. Prints SPM consumer instructions (iOS ships as source, no artifact needed)
#
# Prerequisites:
#   - gh CLI installed and authenticated (brew install gh && gh auth login)
#   - Gradle wrapper set up (scripts/bootstrap.sh)
#   - GPG key configured for signing (see PUBLISHING.md)
#
# Usage:
#   bash scripts/release.sh 1.2.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
ANDROID_DIR="$ROOT/android"
GRADLEW="$ANDROID_DIR/gradlew"

log()  { echo "▶ $*"; }
ok()   { echo "✅ $*"; }
fail() { echo "❌ $*" >&2; exit 1; }

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    fail "Usage: bash scripts/release.sh <VERSION>  (e.g. 1.0.0)"
fi

# Validate semver-ish
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    fail "Version must be X.Y.Z format (e.g. 1.0.0)"
fi

TAG="v$VERSION"

# Make sure working tree is clean
if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
    fail "Working tree is not clean. Commit or stash changes before releasing."
fi

log "Releasing SDK $TAG..."

# 1. Bump VERSION_NAME in gradle.properties
sed -i.bak "s/^VERSION_NAME=.*/VERSION_NAME=$VERSION/" "$ANDROID_DIR/gradle.properties"
rm -f "$ANDROID_DIR/gradle.properties.bak"
ok "Updated android/gradle.properties → VERSION_NAME=$VERSION"

# 2. Commit + tag
git -C "$ROOT" add android/gradle.properties
git -C "$ROOT" commit -m "chore: release $TAG

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
git -C "$ROOT" tag "$TAG"
ok "Git tag $TAG created"

# 3. Build Android release AAR
log "Building Android release AAR..."
bash "$SCRIPT_DIR/build-android.sh" --release
AAR="$ANDROID_DIR/build/outputs/aar/swift-android-sdk-release.aar"
AAR_SHA=$(shasum -a 256 "$AAR" | awk '{print $1}')
ok "AAR: $AAR (SHA-256: $AAR_SHA)"

# 4. Push + create GitHub Release
log "Pushing tag and creating GitHub Release..."
git -C "$ROOT" push origin main
git -C "$ROOT" push origin "$TAG"

gh release create "$TAG" \
    --title "SwiftAndroidSDK $TAG" \
    --notes "## SwiftAndroidSDK $TAG

### Android
Add to your \`build.gradle\`:
\`\`\`groovy
dependencies {
    implementation 'io.github.YOUR_ORG:swift-android-sdk:$VERSION'
}
\`\`\`

### iOS (Swift Package Manager)
In Xcode: File → Add Package Dependencies → \`https://github.com/YOUR_ORG/SwiftAndroidSdk\`
Or in \`Package.swift\`:
\`\`\`swift
.package(url: \"https://github.com/YOUR_ORG/SwiftAndroidSdk\", from: \"$VERSION\")
\`\`\`

### AAR SHA-256
\`$AAR_SHA\`" \
    "$AAR"

ok "GitHub Release $TAG created"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Next steps:"
echo "  Publish to Maven Central: cd android && ./gradlew publishReleasePublicationToOSSRHRepository"
echo "  iOS consumers: SPM source is live at tag $TAG — no further action needed."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
