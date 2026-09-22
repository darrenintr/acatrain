#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FULL_VERSION="$(awk '/^version:/ {print $2; exit}' pubspec.yaml)"
APP="$(find build/macos/Build/Products/Release -maxdepth 1 -type d -name '*.app' -print -quit)"

if [[ -z "$APP" ]]; then
  echo "macOS .app bundle not found" >&2
  exit 1
fi

DIST="$ROOT_DIR/dist"
WORK="$ROOT_DIR/build/packaging-macos"
DMGROOT="$WORK/dmg-root"
rm -rf "$WORK"
mkdir -p "$DIST" "$DMGROOT"

cp -R "$APP" "$DMGROOT/Acatrain.app"
ln -s /Applications "$DMGROOT/Applications"

hdiutil create \
  -volname "Acatrain" \
  -srcfolder "$DMGROOT" \
  -ov \
  -format UDZO \
  "$DIST/acatrain-${FULL_VERSION}-macos.dmg"

ls -lh "$DIST"/*.dmg
