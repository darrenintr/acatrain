#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FULL_VERSION="$(awk '/^version:/ {print $2; exit}' pubspec.yaml)"
VERSION="${FULL_VERSION%%+*}"
BUILD_NUMBER="${FULL_VERSION#*+}"
if [[ "$BUILD_NUMBER" == "$FULL_VERSION" ]]; then
  BUILD_NUMBER=1
fi

BUNDLE="$ROOT_DIR/build/linux/x64/release/bundle"
DIST="$ROOT_DIR/dist"
WORK="$ROOT_DIR/build/packaging-linux"
ROOTFS="$WORK/rootfs"
APP_ID="io.github.darrenintr.acatrain"

if [[ ! -x "$BUNDLE/acatrain" ]]; then
  echo "Linux release bundle not found: $BUNDLE" >&2
  exit 1
fi

rm -rf "$WORK"
mkdir -p "$DIST" "$ROOTFS/usr/lib/acatrain" "$ROOTFS/usr/bin"
cp -a "$BUNDLE/." "$ROOTFS/usr/lib/acatrain/"
ln -s ../lib/acatrain/acatrain "$ROOTFS/usr/bin/acatrain"
install -Dm644 "packaging/linux/$APP_ID.desktop" \
  "$ROOTFS/usr/share/applications/$APP_ID.desktop"
install -Dm644 "packaging/linux/$APP_ID.svg" \
  "$ROOTFS/usr/share/icons/hicolor/scalable/apps/$APP_ID.svg"

echo "Packaging DEB..."
DEBROOT="$WORK/deb"
cp -a "$ROOTFS" "$DEBROOT"
mkdir -p "$DEBROOT/DEBIAN"
INSTALLED_SIZE="$(du -sk "$ROOTFS" | awk '{print $1}')"
cat > "$DEBROOT/DEBIAN/control" <<EOF
Package: acatrain
Version: $FULL_VERSION
Section: education
Priority: optional
Architecture: amd64
Maintainer: darrenintr <168272439+darrenintr@users.noreply.github.com>
Installed-Size: $INSTALLED_SIZE
Depends: libgtk-3-0 | libgtk-3-0t64, libstdc++6, libgcc-s1
Homepage: https://github.com/darrenintr/acatrain
Description: Offline-first study sets with safe content updates
 Acatrain is a responsive Flutter study application with local review progress
 and optional Firebase-backed cross-device sync.
EOF
dpkg-deb --build --root-owner-group "$DEBROOT" \
  "$DIST/acatrain_${FULL_VERSION}_amd64.deb"

echo "Packaging RPM..."
RPM_TOP="$WORK/rpmbuild"
mkdir -p "$RPM_TOP"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
SPEC="$RPM_TOP/SPECS/acatrain.spec"
cat > "$SPEC" <<EOF
Name: acatrain
Version: $VERSION
Release: $BUILD_NUMBER%{?dist}
Summary: Offline-first study sets with safe content updates
License: NOASSERTION
URL: https://github.com/darrenintr/acatrain
BuildArch: x86_64

%description
Acatrain is a responsive Flutter study application with local review progress
and optional Firebase-backed cross-device sync.

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a %{acatrain_root}/. %{buildroot}/

%files
/usr/bin/acatrain
/usr/lib/acatrain
/usr/share/applications/$APP_ID.desktop
/usr/share/icons/hicolor/scalable/apps/$APP_ID.svg
EOF
rpmbuild -bb \
  --define "_topdir $RPM_TOP" \
  --define "acatrain_root $ROOTFS" \
  "$SPEC"
RPM_FILE="$(find "$RPM_TOP/RPMS" -type f -name '*.rpm' -print -quit)"
if [[ -z "$RPM_FILE" ]]; then
  echo "RPM output not found" >&2
  exit 1
fi
cp "$RPM_FILE" "$DIST/acatrain-${VERSION}-${BUILD_NUMBER}.x86_64.rpm"

echo "Packaging AppImage..."
APPDIR="$WORK/Acatrain.AppDir"
mkdir -p "$APPDIR"
cp -a "$ROOTFS/usr" "$APPDIR/usr"
cp "packaging/linux/$APP_ID.desktop" "$APPDIR/$APP_ID.desktop"
cp "packaging/linux/$APP_ID.svg" "$APPDIR/$APP_ID.svg"
ln -s "$APP_ID.svg" "$APPDIR/.DirIcon"
cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/acatrain" "$@"
EOF
chmod +x "$APPDIR/AppRun"
APPIMAGETOOL="$WORK/appimagetool-x86_64.AppImage"
curl -fL --retry 3 \
  https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage \
  -o "$APPIMAGETOOL"
chmod +x "$APPIMAGETOOL"
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$APPIMAGETOOL" \
  "$APPDIR" "$DIST/acatrain-${FULL_VERSION}-x86_64.AppImage"
chmod +x "$DIST/acatrain-${FULL_VERSION}-x86_64.AppImage"

echo "Packaging Flatpak..."
FLATPAK_REPO="$WORK/flatpak-repo"
FLATPAK_BUILD="$WORK/flatpak-build"
flatpak-builder --force-clean --repo="$FLATPAK_REPO" \
  "$FLATPAK_BUILD" "packaging/linux/$APP_ID.yml"
flatpak build-bundle "$FLATPAK_REPO" \
  "$DIST/acatrain-${FULL_VERSION}-x86_64.flatpak" "$APP_ID"

echo "Linux packages:"
ls -lh "$DIST"/*.deb "$DIST"/*.rpm "$DIST"/*.AppImage "$DIST"/*.flatpak
