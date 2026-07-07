#!/bin/bash
# Signs, notarizes, and packages Nexus into a distributable DMG that other Macs
# can open without Gatekeeper warnings. Requires a paid Apple Developer account.
#
# One-time setup:
#   1. In Xcode / developer.apple.com, create a "Developer ID Application"
#      certificate and install it in your login keychain.
#   2. Store notary credentials (creates a reusable keychain profile):
#        xcrun notarytool store-credentials nexus-notary \
#          --apple-id "you@example.com" --team-id "TEAMID" \
#          --password "<app-specific-password>"     # appleid.apple.com › App-Specific Passwords
#
# Usage:
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#   NOTARY_PROFILE="nexus-notary" \
#   ./scripts/notarize.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/Nexus.app"
DMG="$ROOT/Nexus.dmg"

: "${SIGN_IDENTITY:?Set SIGN_IDENTITY to your 'Developer ID Application: ...' identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your stored notarytool profile name}"

# 1. Build + sign with the hardened runtime (build-app.sh enables it when
#    SIGN_IDENTITY is a real identity).
SIGN_IDENTITY="$SIGN_IDENTITY" "$ROOT/scripts/build-app.sh" release

# 2. Package a compressed DMG.
echo "Creating $DMG..."
rm -f "$DMG"
hdiutil create -volname "Nexus" -srcfolder "$APP" -ov -format UDZO "$DMG" >/dev/null

# 3. Submit to Apple's notary service and wait for the result.
echo "Notarizing (this can take a few minutes)..."
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

# 4. Staple the ticket so it validates offline.
xcrun stapler staple "$APP"
xcrun stapler staple "$DMG"

echo "Done. Distributable: $DMG"
