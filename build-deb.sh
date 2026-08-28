#!/usr/bin/env bash
#
# build-deb.sh — export the Godot 4 desktop build headless and package it
# as a Debian package for x86_64 Linux.
#
# Requirements on the build host:
#   * godot4  (with the "Linux/X11" export templates installed)
#   * dpkg-deb, fakeroot
#
# Usage:
#   ./build-deb.sh [version]
#
# Output:
#   dist/childsplay-modern_<version>_amd64.deb
#
set -euo pipefail

# --- configuration ---------------------------------------------------------
PKG_NAME="childsplay-modern"
VERSION="${1:-0.1.0}"
ARCH="amd64"
MAINTAINER="Childsplay-Modern contributors <noreply@example.org>"
GODOT_BIN="${GODOT_BIN:-godot4}"
EXPORT_PRESET="${EXPORT_PRESET:-Linux/X11}"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT_DIR="$PROJECT_DIR/desktop-godot"
BUILD_DIR="$PROJECT_DIR/build/deb"
DIST_DIR="$PROJECT_DIR/dist"
BIN_NAME="$PKG_NAME"

# Debian install layout inside the staging root.
PKG_ROOT="$BUILD_DIR/$PKG_NAME"
INSTALL_LIBDIR="/usr/lib/$PKG_NAME"
INSTALL_BINDIR="/usr/bin"
INSTALL_SHAREDIR="/usr/share"

# --- sanity checks -------------------------------------------------------
command -v "$GODOT_BIN" >/dev/null 2>&1 || {
  echo "error: '$GODOT_BIN' not found (set GODOT_BIN to your Godot 4 binary)" >&2
  exit 1
}
command -v dpkg-deb >/dev/null 2>&1 || { echo "error: dpkg-deb not found" >&2; exit 1; }

# --- clean staging -------------------------------------------------------
rm -rf "$BUILD_DIR"
mkdir -p "$PKG_ROOT$INSTALL_LIBDIR" \
         "$PKG_ROOT$INSTALL_BINDIR" \
         "$PKG_ROOT$INSTALL_SHAREDIR/applications" \
         "$PKG_ROOT$INSTALL_SHAREDIR/pixmaps" \
         "$PKG_ROOT/DEBIAN" \
         "$DIST_DIR"

# --- 1. headless Godot export -----------------------------------------
# Mirror the shared assets/ into the Godot project (res:// is project-local).
"$GODOT_DIR/sync-assets.sh"

echo ">> exporting Godot project ($EXPORT_PRESET) ..."
(
  cd "$GODOT_DIR"
  # --import first so a clean checkout builds the resource cache.
  "$GODOT_BIN" --headless --import .
  "$GODOT_BIN" --headless --export-release "$EXPORT_PRESET" \
    "$PKG_ROOT$INSTALL_LIBDIR/$BIN_NAME.x86_64"
)
chmod +x "$PKG_ROOT$INSTALL_LIBDIR/$BIN_NAME.x86_64"
# Godot writes the .pck next to the binary; keep both together.
[ -f "$PKG_ROOT$INSTALL_LIBDIR/$BIN_NAME.pck" ] || true

# --- 2. launcher wrapper ------------------------------------------------
cat > "$PKG_ROOT$INSTALL_BINDIR/$PKG_NAME" <<EOF
#!/bin/sh
exec "$INSTALL_LIBDIR/$BIN_NAME.x86_64" "\$@"
EOF
chmod +x "$PKG_ROOT$INSTALL_BINDIR/$PKG_NAME"

# --- 3. desktop entry + icon -----------------------------------------
cat > "$PKG_ROOT$INSTALL_SHAREDIR/applications/$PKG_NAME.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Childsplay-Modern
Comment=Educational activity suite for children ages 2-7
Exec=$PKG_NAME
Icon=$PKG_NAME
Categories=Education;Game;
Terminal=false
EOF

if [ -f "$PROJECT_DIR/assets/icons/logo_cp.svg" ]; then
  cp "$PROJECT_DIR/assets/icons/logo_cp.svg" \
     "$PKG_ROOT$INSTALL_SHAREDIR/pixmaps/$PKG_NAME.svg"
fi

# --- 4. control file --------------------------------------------------
INSTALLED_SIZE=$(du -ks "$PKG_ROOT" | cut -f1)
cat > "$PKG_ROOT/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $VERSION
Section: education
Priority: optional
Architecture: $ARCH
Maintainer: $MAINTAINER
Installed-Size: $INSTALLED_SIZE
Depends: libc6, libgl1
Description: Childsplay-Modern educational activity suite
 A Godot 4 port of the classic Childsplay suite of learning games
 for children between 2 and 7 years old. Includes Packid,
 Fallingletter, Soundmemory, Memory and Billiards.
EOF

# --- 5. build the .deb ---------------------------------------------
OUT="$DIST_DIR/${PKG_NAME}_${VERSION}_${ARCH}.deb"
echo ">> packaging $OUT ..."
if command -v fakeroot >/dev/null 2>&1; then
  fakeroot dpkg-deb --build "$PKG_ROOT" "$OUT"
else
  dpkg-deb --build "$PKG_ROOT" "$OUT"
fi

echo ">> done: $OUT"
