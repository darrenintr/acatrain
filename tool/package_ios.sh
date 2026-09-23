#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FULL_VERSION="$(awk '/^version:/ {print $2; exit}' pubspec.yaml)"
APP="$(find build/ios/iphoneos -maxdepth 1 -type d -name '*.app' -print -quit)"

if [[ -z "$APP" ]]; then
  echo "iOS .app bundle not found" >&2
  exit 1
fi

DIST="$ROOT_DIR/dist"
WORK="$ROOT_DIR/build/packaging-ios"
PAYLOAD="$WORK/Payload"
rm -rf "$WORK"
mkdir -p "$DIST" "$PAYLOAD"

cp -R "$APP" "$PAYLOAD/"
(
  cd "$WORK"
  ditto -c -k --sequesterRsrc --keepParent Payload \
    "$DIST/acatrain-${FULL_VERSION}-ios-unsigned.ipa"
)

ls -lh "$DIST"/*.ipa
