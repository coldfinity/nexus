#!/bin/bash
# Builds Nexus and packages it as a proper macOS .app bundle.
#
# Running the raw SwiftPM executable (`swift run`) has no Info.plist, so macOS
# won't render SF Symbols and the app misbehaves in the Dock. Wrapping the
# binary in a bundle fixes both.
#
# Usage: ./scripts/build-app.sh [debug|release]   (default: release)

set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/Nexus.app"
BUNDLE_ID="com.nexus.Nexus"
VERSION="0.1.0"

cd "$ROOT"

echo "Building ($CONFIG)..."
swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)/Nexus"
if [[ ! -x "$BIN" ]]; then
    echo "error: built binary not found at $BIN" >&2
    exit 1
fi

echo "Assembling $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Nexus"

# App icon (generate it with: swift scripts/make-icon.swift).
ICON_KEY=""
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
    ICON_KEY='    <key>CFBundleIconFile</key>           <string>AppIcon</string>'
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>               <string>Nexus</string>
    <key>CFBundleDisplayName</key>        <string>Nexus</string>
    <key>CFBundleIdentifier</key>         <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>         <string>Nexus</string>
    <key>CFBundlePackageType</key>        <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>$VERSION</string>
    <key>CFBundleVersion</key>            <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>     <string>14.0</string>
    <key>NSHighResolutionCapable</key>    <true/>
    <key>LSApplicationCategoryType</key>  <string>public.app-category.developer-tools</string>
$ICON_KEY
</dict>
</plist>
PLIST

# Sign. Default is an ad-hoc signature (fine for your own machine). For
# distribution, pass a Developer ID:  SIGN_IDENTITY="Developer ID Application: You (TEAMID)"
# which also enables the hardened runtime required for notarization.
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign --force --sign - "$APP" >/dev/null 2>&1 || true
else
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
    echo "Signed with: $SIGN_IDENTITY"
fi

echo "Done: $APP"
echo "Launch with:  open \"$APP\"    (or double-click it in Finder)"
