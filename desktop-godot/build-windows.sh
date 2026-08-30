#!/usr/bin/env bash
#
# build-windows.sh - export the Childsplay Modern Godot 4 project to a
# standalone Windows x86_64 .exe and zip it for release.
#
#   Run from anywhere:  desktop-godot/build-windows.sh [VERSION]
#
# Requirements on the build host:
#   * Godot 4  (godot4 or godot on PATH, or set GODOT_BIN) with the
#     "Windows Desktop" export templates for that exact version installed
#     (the same export-templates .tpz that ships the Linux ones)
#   * python3  (used to zip the result; no separate `zip` needed)
#   * optional: rcedit  (lets Godot stamp the .exe icon/metadata from a
#     Linux host; without it you just get a plain icon)
#
# Flags:
#   --force-preset  rewrite export_presets.cfg (Linux + Windows) first
#   -h | --help     show this help
#
# Output:  dist/childsplay-modern_<version>_windows_x86_64.zip
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$PROJECT_DIR/.." && pwd)"
DIST_DIR="$REPO_DIR/dist"
PRESET="Windows"
BUILD_DIR="${CHILDSPLAY_BUILD_DIR:-${TMPDIR:-/tmp}/childsplay-modern-win}"

FORCE_PRESET=0
for arg in "$@"; do
	case "$arg" in
		--force-preset) FORCE_PRESET=1 ;;
		-h|--help) sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
		-*) echo "unknown flag: $arg" >&2; exit 2 ;;
		*) VERSION="$arg" ;;
	esac
done

if [ -z "${VERSION:-}" ]; then
	VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' "$PROJECT_DIR/project.godot" 2>/dev/null || true)"
fi
VERSION="${VERSION:-0.1.0}"

GODOT_BIN="${GODOT_BIN:-}"
if [ -z "$GODOT_BIN" ]; then
	if command -v godot4 >/dev/null 2>&1; then GODOT_BIN="godot4"
	elif command -v godot >/dev/null 2>&1; then GODOT_BIN="godot"
	fi
fi

say()  { printf '\033[1;36m>> %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mxx %s\033[0m\n' "$*" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || die "python3 not found (used to zip the result)"
[ -n "$GODOT_BIN" ] || die "Godot not found. Install Godot 4 or set GODOT_BIN."
command -v "$GODOT_BIN" >/dev/null 2>&1 || die "GODOT_BIN='$GODOT_BIN' is not executable"

# Ensure export_presets.cfg carries both presets. build-deb.sh writes the
# same pair; this keeps build-windows.sh usable on its own.
if [ "$FORCE_PRESET" -eq 1 ] || ! grep -q 'name="Windows"' "$PROJECT_DIR/export_presets.cfg" 2>/dev/null; then
	say "writing export_presets.cfg (Linux + Windows presets)"
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

[preset.1]

name="Windows"
platform="Windows Desktop"
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

[preset.1.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=0
binary_format/embed_pck=true
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
binary_format/architecture="x86_64"
codesign/enable=false
application/modify_resources=true
application/icon=""
application/console_wrapper_icon=""
application/icon_interpolation=4
application/file_version=""
application/product_version=""
application/company_name="Childsplay-Modern"
application/product_name="Childsplay Modern"
application/file_description="Childsplay Modern educational activity suite"
application/copyright="GPL-3.0-or-later"
application/trademarks=""
application/export_angle=0
application/export_d3d12=0
application/d3d12_agility_sdk_multiarch=true
ssh_remote_deploy/enabled=false
PRESET
fi

say "syncing shared assets into the project"
bash "$PROJECT_DIR/sync-assets.sh"

say "importing project resources (headless)"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --import

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR"
EXE="$BUILD_DIR/childsplay-modern.exe"

say "exporting release .exe for preset '$PRESET'"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "$PRESET" "$EXE"
[ -s "$EXE" ] || die "export produced no .exe at $EXE"

cat > "$BUILD_DIR/README.txt" <<TXT
Childsplay Modern $VERSION - Windows (x86_64)

Run childsplay-modern.exe. No installation needed; everything is bundled.
Windows SmartScreen may warn about an unsigned app the first time -
choose "More info" then "Run anyway".

https://github.com/hakarune/childsplay-modern
GPL-3.0-or-later
TXT

OUT="$DIST_DIR/childsplay-modern_${VERSION}_windows_x86_64.zip"
rm -f "$OUT"
( cd "$BUILD_DIR" && python3 -m zipfile -c "$OUT" childsplay-modern.exe README.txt )

say "done: $OUT ($(du -h "$OUT" | cut -f1))"
python3 -m zipfile -l "$OUT"
