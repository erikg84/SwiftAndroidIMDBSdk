#!/usr/bin/env bash
# build-xcframework.sh — Build a multi-platform XCFramework from the SwiftPM
# library target, packaging it as a static framework so iOS/macOS consumers can
# add it via SPM .binaryTarget(...).
#
# Why this script exists:
#   `xcodebuild archive` of a SwiftPM library scheme does NOT produce a real
#   `.framework` bundle. The archive only contains loose .o files under
#   `Products/Users/<user>/Objects/`, and the swiftmodule files live in
#   DerivedData. `xcodebuild -create-xcframework -framework <path>` therefore
#   fails with "the path does not point to a valid framework".
#
#   The fix is to assemble each platform's framework manually from the archive's
#   .o files (merged with libtool) plus the swiftmodule from DerivedData, then
#   feed those framework dirs into `xcodebuild -create-xcframework`.
#
#   We tried `swift-create-xcframework` (segment-integrations fork) and the
#   Homebrew tap, but its bundled swift-llbuild does not compile against the
#   macOS 26 SDK (`posix_spawn_file_actions_addchdir` redeclaration). The
#   manual approach has no external dependencies beyond xcodebuild + libtool.
#
# Usage:
#   bash scripts/build-xcframework.sh [output-dir] [version]
#     output-dir   default: $PWD/build/xcframework
#     version      default: VERSION_NAME from android/gradle.properties

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
OUT_DIR="${1:-$ROOT/build/xcframework}"
VERSION="${2:-}"

if [[ -z "$VERSION" ]]; then
  VERSION=$(grep '^VERSION_NAME=' "$ROOT/android/gradle.properties" | cut -d= -f2)
fi
[[ -z "$VERSION" ]] && VERSION="0.0.0"

SCHEME="SwiftAndroidSDK"
BUNDLE_ID="io.github.erikg84.SwiftAndroidSDK"
IOS_MIN="15.0"
MACOS_MIN="12.0"

log()  { echo "▶ $*"; }
ok()   { echo "✅ $*"; }
fail() { echo "❌ $*" >&2; exit 1; }

mkdir -p "$OUT_DIR"
WORK="$OUT_DIR/.work"
rm -rf "$WORK"
mkdir -p "$WORK"

archive_one() {
  local name=$1 destination=$2
  log "Archive — $destination"
  xcodebuild archive \
    -scheme "$SCHEME" \
    -destination "generic/platform=$destination" \
    -archivePath "$WORK/$name.xcarchive" \
    -derivedDataPath "$WORK/dd-$name" \
    -quiet \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SWIFT_VERIFY_EMITTED_MODULE_INTERFACE=NO
}

# SwiftPM library targets archive only object files into the .xcarchive and
# leave the swiftmodule in DerivedData. Reassemble both into a static framework.
build_framework() {
  local name=$1 plist_min=$2
  local arc="$WORK/$name.xcarchive"
  local dd="$WORK/dd-$name"
  local sm_dir
  sm_dir=$(find "$dd/Build/Intermediates.noindex/ArchiveIntermediates/$SCHEME/BuildProductsPath" \
    -type d -name "$SCHEME.swiftmodule" 2>/dev/null | head -1)
  [[ -d "$sm_dir" ]] || fail "swiftmodule not found for $name"

  local fw="$WORK/fw-$name/$SCHEME.framework"
  rm -rf "$fw"
  mkdir -p "$fw/Modules/$SCHEME.swiftmodule"
  cp -R "$sm_dir/." "$fw/Modules/$SCHEME.swiftmodule/"

  # Merge SwiftAndroidSDK.o + Swinject.o into a single static archive named
  # after the framework. xcodebuild -create-xcframework treats this as the
  # framework binary and is happy with `current ar archive` content.
  xcrun libtool -static -o "$fw/$SCHEME" \
    "$arc/Products/Users/$USER/Objects/$SCHEME.o" \
    "$arc/Products/Users/$USER/Objects/Swinject.o"

  cat > "$fw/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$SCHEME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>$SCHEME</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>MinimumOSVersion</key><string>$plist_min</string>
</dict>
</plist>
PLIST
  ok "Built $name framework"
}

cd "$ROOT"

archive_one ios          "iOS"
archive_one ios-sim      "iOS Simulator"
archive_one macos        "macOS"

build_framework ios       "$IOS_MIN"
build_framework ios-sim   "$IOS_MIN"
build_framework macos     "$MACOS_MIN"

XCF="$OUT_DIR/$SCHEME.xcframework"
rm -rf "$XCF"
log "Assembling XCFramework"
xcodebuild -create-xcframework \
  -framework "$WORK/fw-ios/$SCHEME.framework" \
  -framework "$WORK/fw-ios-sim/$SCHEME.framework" \
  -framework "$WORK/fw-macos/$SCHEME.framework" \
  -output "$XCF"

ZIP="$OUT_DIR/$SCHEME.xcframework.zip"
rm -f "$ZIP"
log "Zipping → $ZIP"
( cd "$OUT_DIR" && zip -qry "$(basename "$ZIP")" "$(basename "$XCF")" )

CHECKSUM=""
if command -v swift >/dev/null 2>&1; then
  CHECKSUM=$(swift package compute-checksum "$ZIP" 2>/dev/null || true)
fi
if [[ -z "$CHECKSUM" ]]; then
  CHECKSUM=$(shasum -a 256 "$ZIP" | awk '{print $1}')
fi
echo "$CHECKSUM" > "$OUT_DIR/$SCHEME.xcframework.sha256"

# Strip working files; the workflow only needs the .xcframework, .zip, .sha256
rm -rf "$WORK"

ok "XCFramework: $XCF"
ok "Zip:        $ZIP ($(du -sh "$ZIP" | cut -f1))"
ok "SHA-256:    $CHECKSUM"
