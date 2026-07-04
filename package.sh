#!/usr/bin/env bash
#
# Builds a *shareable* FloatingAI.app:
#   - universal binary (arm64 + x86_64) so it runs on Apple Silicon AND Intel
#   - ad-hoc signed (no Apple Developer ID — recipients bypass Gatekeeper once)
#   - places FloatingAI.app in the repo root
#   - produces FloatingAI.dmg (drag-to-Applications installer) for sending
#
set -euo pipefail

APP_NAME="FloatingAI"
VOL_NAME="Floating AI"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$ROOT/$APP_NAME.app"
ENTITLEMENTS="$ROOT/Resources/FloatingAI.entitlements"
DIST="$ROOT/dist"
DMG="$ROOT/$APP_NAME.dmg"

# A true --arch universal build needs the Xcode build system (xcbuild), which
# isn't in the Command Line Tools. Instead we build each slice with the native
# build system (x86_64 via Rosetta) and lipo them together. SwiftPM writes each
# arch to its own .build/<triple> dir, so the two builds don't collide.
echo "==> Building arm64 slice"
swift build -c release
ARM_BIN="$(swift build -c release --show-bin-path)/$APP_NAME"

echo "==> Building x86_64 slice (via Rosetta)"
arch -x86_64 swift build -c release
X86_BIN="$(arch -x86_64 swift build -c release --show-bin-path)/$APP_NAME"

echo "==> Assemble $APP (universal)"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "$ARM_BIN" "$X86_BIN" -output "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
[ -f "$ROOT/Resources/AppIcon.icns" ] && cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

echo "==> Ad-hoc code sign"
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP"
codesign --verify --verbose "$APP"

echo "==> Stage disk image contents"
rm -rf "$DIST" "$DMG"
STAGE="$DIST/$VOL_NAME"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/$APP_NAME.app"
# Drag-to-install target inside the DMG window.
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/HOW-TO-OPEN.txt" <<'TXT'
========================================================================
 Floating AI  —  How to install  (macOS 13 Ventura or later)
========================================================================

This app was NOT distributed through the App Store and is not notarized by
Apple, so macOS Gatekeeper will block it on the first open. This is normal
for indie apps. You only do the steps below ONCE.

------------------------------------------------------------------------
STEP 1 — Move the app
------------------------------------------------------------------------
Drag "FloatingAI.app" into your /Applications folder.

------------------------------------------------------------------------
STEP 2 — Remove the quarantine flag (most reliable method)
------------------------------------------------------------------------
Open the Terminal app and paste this line, then press Return:

    xattr -dr com.apple.quarantine /Applications/FloatingAI.app

Now double-click FloatingAI.app. It should open.

  (Alternative without Terminal: right-click the app -> Open -> Open.
   If macOS still refuses, go to
   System Settings -> Privacy & Security, scroll down, and click
   "Open Anyway" next to the FloatingAI message, then open it again.)

------------------------------------------------------------------------
STEP 3 — First launch setup
------------------------------------------------------------------------
  * Enter YOUR OWN OpenAI API key (create one at:
    https://platform.openai.com/api-keys ).
    The key is stored only on your Mac, in the Keychain. It is sent
    directly to OpenAI and nowhere else.

  * Grant Accessibility permission when prompted:
    System Settings -> Privacy & Security -> Accessibility -> turn ON
    "FloatingAI". This lets it read your selected text (Copy) and paste
    answers back (Paste). You can revoke it anytime.

------------------------------------------------------------------------
STEP 4 — Use it
------------------------------------------------------------------------
  * Floating AI lives in your MENU BAR (the ✦ icon) — there is no Dock icon.
  * Select any text in any app, then press:   Command + Shift + K
    (You can also click the ✦ menu bar icon -> Open Assistant.)
  * Pick a quick action (Explain, Rewrite, Summarize, ...) or type a prompt.
  * Copy the answer, or Replace / Insert it back into your document.

Runs on both Apple Silicon and Intel Macs.
TXT

echo "==> Build compressed disk image"
hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$DMG" >/dev/null
rm -rf "$DIST"

echo ""
echo "Architectures: $(lipo -archs "$APP/Contents/MacOS/$APP_NAME")"
echo "App:  $APP"
echo "DMG:  $DMG   (send this — double-click, drag the app to Applications)"
