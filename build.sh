#!/usr/bin/env bash
#
# Builds FloatingAI and assembles a runnable macOS .app bundle.
#
# Because only the Command Line Tools (not full Xcode) are required, we build
# the executable with Swift Package Manager and hand-assemble the bundle,
# then ad-hoc code-sign it so macOS can track its Accessibility permission.
#
set -euo pipefail

CONFIG="${1:-release}"
APP_NAME="FloatingAI"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"
ENTITLEMENTS="$ROOT/Resources/FloatingAI.entitlements"

echo "==> Building ($CONFIG) with Swift Package Manager"
swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"
if [[ ! -f "$BIN" ]]; then
    echo "error: built executable not found at $BIN" >&2
    exit 1
fi

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# Optional app icon, if present.
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

echo "==> Ad-hoc code signing"
codesign --force --deep \
    --sign - \
    --entitlements "$ENTITLEMENTS" \
    --options runtime \
    "$APP" 2>/dev/null || \
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP"

echo ""
echo "Built: $APP"
echo "Run with:  open \"$APP\"   (or ./run.sh)"
