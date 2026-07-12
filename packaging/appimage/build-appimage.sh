#!/usr/bin/env bash
# Build a portable AppImage of the Xeneon Edge Linux Hub (bundles Qt).
#
# Requires (downloaded automatically if missing, into ./ tools):
#   - linuxdeploy + linuxdeploy-plugin-qt   (https://github.com/linuxdeploy)
# and on the build host: cmake, a C++ toolchain, Rust (cargo), and the Qt6 dev
# packages (same as a normal build).
#
# NOTE: this has NOT been build-tested in the dev container (no appimagetool
# there). Run it on a normal Linux desktop with the Qt6 dev stack installed.
#
# Usage:  ./packaging/appimage/build-appimage.sh
# Output: xeneon-edge-hub-<version>-x86_64.AppImage in the repo root.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO"
VERSION="$(grep -Po 'project\(.*VERSION \K[0-9.]+' CMakeLists.txt | head -1)"
BUILD="$REPO/build-appimage"
APPDIR="$BUILD/AppDir"
TOOLS="$REPO/build-appimage/tools"
export ARCH=x86_64

mkdir -p "$TOOLS"
_get() { # url -> tools/name (chmod +x)
  local url="$1" out="$TOOLS/$(basename "$1")"
  [ -x "$out" ] || { echo "==> fetching $(basename "$out")"; curl -fL "$url" -o "$out"; chmod +x "$out"; }
  echo "$out"
}
LD="$(_get https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage)"
LDQT="$(_get https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage)"
export PATH="$TOOLS:$PATH"

echo "==> Building (Release) into an AppDir"
cmake -B "$BUILD" -S "$REPO" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev
cmake --build "$BUILD" -j"$(nproc)"
rm -rf "$APPDIR"
DESTDIR="$APPDIR" cmake --install "$BUILD"

# The QML is compiled into the binaries via qrc, so there are no external .qml for
# qmlimportscanner to read — point QML_SOURCES_PATHS at the source tree so the Qt
# plugin still bundles the right QML runtime modules (QtQuick, Controls, Effects,
# Shapes, VirtualKeyboard, …).
export QML_SOURCES_PATHS="$REPO/ui/qml:$REPO/manager/qml"
export EXTRA_QT_MODULES="waylandcompositor"   # ensure the wayland platform plugin is bundled

"$LD" --appdir "$APPDIR" \
  --desktop-file "$APPDIR/usr/share/applications/xeneon-edge-hub.desktop" \
  --icon-file "$APPDIR/usr/share/icons/hicolor/256x256/apps/xeneon-edge-hub.png" \
  --plugin qt \
  --output appimage

echo "==> Done. Note: the orientation-sensor udev rule (auto-rotate) still has to be"
echo "    installed on the host — an AppImage cannot ship a udev rule. See"
echo "    packaging/udev/99-xeneon-edge.rules."
