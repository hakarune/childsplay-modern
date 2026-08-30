#!/usr/bin/env bash
#
# build-deb.sh - export the Childsplay Modern Godot 4 project to a
# standalone Linux x86_64 binary and package it as a .deb.
#
#   Run from anywhere:  desktop-godot/build-deb.sh [VERSION]
#
# Requirements on the build host:
#   * Godot 4  (godot4 or godot on PATH, or set GODOT_BIN) with the
#     "Linux" export templates for that exact version installed
#   * dpkg-deb          (from dpkg)
#   * fakeroot          (optional; only needed if dpkg-deb lacks
#                        --root-owner-group)
#   * desktop-file-validate  (optional, from desktop-file-utils)
#
# Flags:
#   --no-export     skip the Godot export step (package whatever binary is
#                   already staged, or a clearly-marked placeholder) -
#                   for testing the packaging pipeline without templates
#   --force-preset  regenerate export_presets.cfg even if it exists
#   --keep          do not wipe the staging dir first
#   -h | --help     show this help
#
# Output:  dist/childsplay-modern_<version>_amd64.deb
#
set -euo pipefail

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------
PKG_NAME="childsplay-modern"
APP_NAME="Childsplay Modern"
ARCH="amd64"
MAINTAINER="${DEBFULLNAME:-Childsplay-Modern contributors} <${DEBEMAIL:-noreply@example.org}>"
HOMEPAGE="https://github.com/hakarune/childsplay-modern"
EXPORT_PRESET="Linux"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # the Godot project
REPO_DIR="$(cd "$PROJECT_DIR/.." && pwd)"
# Stage on a POSIX-permission filesystem: dpkg-deb rejects a DEBIAN/ dir
# whose mode isn't 0755-0775, which e.g. FAT/sdcardfs mounts force. Override
# with CHILDSPLAY_BUILD_DIR if /tmp is unsuitable.
BUILD_DIR="${CHILDSPLAY_BUILD_DIR:-${TMPDIR:-/tmp}/childsplay-modern-build}"
STAGE="$BUILD_DIR/$PKG_NAME"
DIST_DIR="$REPO_DIR/dist"

# Install paths inside the package.
BIN_PATH="usr/bin/$PKG_NAME"
DESKTOP_PATH="usr/share/applications/$PKG_NAME.desktop"
ICON_PATH="usr/share/icons/hicolor/scalable/apps/$PKG_NAME.svg"
PIXMAP_PATH="usr/share/pixmaps/$PKG_NAME.svg"
DOC_DIR="usr/share/doc/$PKG_NAME"

DO_EXPORT=1
FORCE_PRESET=0
KEEP=0

for arg in "$@"; do
	case "$arg" in
		--no-export) DO_EXPORT=0 ;;
		--force-preset) FORCE_PRESET=1 ;;
		--keep) KEEP=1 ;;
		-h|--help) sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
		-*) echo "unknown flag: $arg" >&2; exit 2 ;;
		*) VERSION="$arg" ;;
	esac
done

# Version: arg > $VERSION env > project.godot > 0.1.0
if [ -z "${VERSION:-}" ]; then
	VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' "$PROJECT_DIR/project.godot" 2>/dev/null || true)"
fi
VERSION="${VERSION:-0.1.0}"

# Godot binary: $GODOT_BIN, then godot4, then godot.
GODOT_BIN="${GODOT_BIN:-}"
if [ -z "$GODOT_BIN" ]; then
	if command -v godot4 >/dev/null 2>&1; then GODOT_BIN="godot4"
	elif command -v godot >/dev/null 2>&1; then GODOT_BIN="godot"
	fi
fi

say()  { printf '\033[1;36m>> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mxx %s\033[0m\n' "$*" >&2; exit 1; }

# --------------------------------------------------------------------------
# Preflight
# --------------------------------------------------------------------------
command -v dpkg-deb >/dev/null 2>&1 || die "dpkg-deb not found (install 'dpkg')"

DEB_BUILD_ARGS=(--build)
if dpkg-deb --help 2>&1 | grep -q -- '--root-owner-group'; then
	DEB_BUILD_ARGS=(--root-owner-group --build)
elif command -v fakeroot >/dev/null 2>&1; then
	DEB_WRAP="fakeroot"
else
	warn "no --root-owner-group and no fakeroot: package files will be owned by $(id -un)"
fi

if [ "$DO_EXPORT" -eq 1 ]; then
	[ -n "$GODOT_BIN" ] || die "Godot not found. Install Godot 4 or set GODOT_BIN, or pass --no-export."
	command -v "$GODOT_BIN" >/dev/null 2>&1 || die "GODOT_BIN='$GODOT_BIN' is not executable"
fi

# --------------------------------------------------------------------------
# Staging layout
# --------------------------------------------------------------------------
[ "$KEEP" -eq 1 ] || rm -rf "$BUILD_DIR"
mkdir -p \
	"$STAGE/DEBIAN" \
	"$STAGE/usr/bin" \
	"$STAGE/usr/share/applications" \
	"$STAGE/usr/share/icons/hicolor/scalable/apps" \
	"$STAGE/usr/share/pixmaps" \
	"$STAGE/$DOC_DIR" \
	"$DIST_DIR"

# --------------------------------------------------------------------------
# 1. Export the Godot project -> usr/bin/childsplay-modern
# --------------------------------------------------------------------------
if [ "$DO_EXPORT" -eq 1 ]; then
	say "syncing shared assets into the project"
	bash "$PROJECT_DIR/sync-assets.sh"

	if [ ! -f "$PROJECT_DIR/export_presets.cfg" ] || [ "$FORCE_PRESET" -eq 1 ]; then
		say "writing export_presets.cfg (preset '$EXPORT_PRESET', all resources, embedded pck)"
		cat > "$PROJECT_DIR/export_presets.cfg" <<'PRESET'
[preset.0]

name="Linux"
platform="Linux"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="*.json"
exclude_filter="legacy-sources/*"
export_path=""
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=0
binary_format/embed_pck=true
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
binary_format/architecture="x86_64"
ssh_remote_deploy/enabled=false
PRESET
	fi

	say "importing project resources (headless)"
	"$GODOT_BIN" --headless --path "$PROJECT_DIR" --import

	say "exporting release binary for $EXPORT_PRESET"
	"$GODOT_BIN" --headless --path "$PROJECT_DIR" \
		--export-release "$EXPORT_PRESET" "$STAGE/$BIN_PATH"

	[ -s "$STAGE/$BIN_PATH" ] || die "export produced no binary at $STAGE/$BIN_PATH"
else
	warn "--no-export: not running Godot"
	if [ ! -s "$STAGE/$BIN_PATH" ]; then
		warn "no staged binary - writing a NON-FUNCTIONAL placeholder so the"
		warn "packaging pipeline can still be exercised. Do not ship this .deb."
		cat > "$STAGE/$BIN_PATH" <<'STUB'
#!/bin/sh
echo "childsplay-modern: placeholder build - the Godot export step was skipped." >&2
echo "Rebuild on an x86_64 Linux host with Godot 4 'Linux' export templates." >&2
exit 1
STUB
	fi
fi
chmod 755 "$STAGE/$BIN_PATH"

# --------------------------------------------------------------------------
# 2. Desktop entry
# --------------------------------------------------------------------------
say "writing $DESKTOP_PATH"
cat > "$STAGE/$DESKTOP_PATH" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=$APP_NAME
GenericName=Educational Games
Comment=Learning games for children ages 2 to 7
Exec=$PKG_NAME
Icon=$PKG_NAME
Terminal=false
Categories=Education;Game;KidsGame;
Keywords=kids;children;learning;memory;letters;sounds;
StartupNotify=true
StartupWMClass=Childsplay Modern
EOF
chmod 644 "$STAGE/$DESKTOP_PATH"

if command -v desktop-file-validate >/dev/null 2>&1; then
	desktop-file-validate "$STAGE/$DESKTOP_PATH" && say "desktop entry validates"
fi

# --------------------------------------------------------------------------
# 3. Icon
# --------------------------------------------------------------------------
if [ -f "$PROJECT_DIR/icon.svg" ]; then
	install -m 644 "$PROJECT_DIR/icon.svg" "$STAGE/$ICON_PATH"
	install -m 644 "$PROJECT_DIR/icon.svg" "$STAGE/$PIXMAP_PATH"
	say "installed icon -> $ICON_PATH"
else
	warn "desktop-godot/icon.svg missing - package will have no icon"
fi

# --------------------------------------------------------------------------
# 4. copyright / doc
# --------------------------------------------------------------------------
cat > "$STAGE/$DOC_DIR/copyright" <<EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: Childsplay Modern
Source: $HOMEPAGE

Files: *
Copyright: Childsplay-Modern contributors
License: GPL-3.0+
 This program is free software: you can redistribute it and/or modify it
 under the terms of the GNU General Public License as published by the
 Free Software Foundation, either version 3 of the License, or (at your
 option) any later version.
 .
 On Debian systems the full text of the GPL-3 is in
 /usr/share/common-licenses/GPL-3.
EOF
chmod 644 "$STAGE/$DOC_DIR/copyright"

# --------------------------------------------------------------------------
# 5. Debian control + maintainer scripts
# --------------------------------------------------------------------------
INSTALLED_SIZE="$(du -ks "$STAGE/usr" | cut -f1)"
say "writing DEBIAN/control (v$VERSION, ${INSTALLED_SIZE} KiB installed)"
cat > "$STAGE/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $VERSION
Section: education
Priority: optional
Architecture: $ARCH
Maintainer: $MAINTAINER
Installed-Size: $INSTALLED_SIZE
Depends: libc6, libgl1, libx11-6, libxcursor1, libxinerama1, libxrandr2, libxi6
Recommends: libasound2
Homepage: $HOMEPAGE
Description: Childsplay Modern educational activity suite
 A Godot 4 port of the classic Childsplay suite of learning games for
 children between 2 and 7 years old. The launcher opens 19 activities
 spanning memory, letters and words, numbers, sound recognition, jigsaw
 puzzles, drawing-style reveal, and gentle arcade games, with a
 light/dark theme and per-channel sound controls.
EOF

cat > "$STAGE/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
	if command -v update-desktop-database >/dev/null 2>&1; then
		update-desktop-database -q /usr/share/applications || true
	fi
	if command -v gtk-update-icon-cache >/dev/null 2>&1; then
		gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
	fi
fi
exit 0
EOF

cat > "$STAGE/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
	if command -v update-desktop-database >/dev/null 2>&1; then
		update-desktop-database -q /usr/share/applications || true
	fi
	if command -v gtk-update-icon-cache >/dev/null 2>&1; then
		gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
	fi
fi
exit 0
EOF

chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm"
chmod 644 "$STAGE/DEBIAN/control"

# --------------------------------------------------------------------------
# 6. Normalise permissions, then build the .deb
# --------------------------------------------------------------------------
# The staging dirs otherwise inherit the caller's umask (often 0077), which
# would ship /usr as root-only. Force the standard 0755 dirs / 0644 files,
# then restore the executable bits.
say "normalising file modes"
find "$STAGE" -type d -exec chmod 0755 {} +
find "$STAGE" -type f -exec chmod 0644 {} +
chmod 0755 "$STAGE/$BIN_PATH" "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm"

OUT="$DIST_DIR/${PKG_NAME}_${VERSION}_${ARCH}.deb"
say "packaging -> $OUT"
${DEB_WRAP:-} dpkg-deb "${DEB_BUILD_ARGS[@]}" "$STAGE" "$OUT"

say "package contents"
dpkg-deb --info "$OUT"
dpkg-deb --contents "$OUT"

say "done: $OUT"
