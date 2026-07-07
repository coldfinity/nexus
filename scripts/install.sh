#!/bin/bash
# Builds Nexus.app and installs it to /Applications so it shows up in
# Spotlight / Launchpad like any other app.
#
# Usage: ./scripts/install.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="/Applications/Nexus.app"

"$ROOT/scripts/build-app.sh" release

echo "Installing to $DEST..."
rm -rf "$DEST"
cp -R "$ROOT/Nexus.app" "$DEST"

echo "Installed. Launch it from Spotlight/Launchpad, or:  open \"$DEST\""
