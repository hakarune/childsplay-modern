#!/usr/bin/env bash
#
# sync-assets.sh — mirror the shared root assets/ into desktop-godot/assets/.
#
# The Godot 4 engine can only see resources under its own project root
# (res://). The canonical art/audio lives in ../assets/ and is shared with
# the web target, so this script copies it in. desktop-godot/assets/ is
# git-ignored; run this after cloning and whenever ../assets/ changes.
#
# (A symlink would be simpler but the project's storage is a FUSE mount
#  that does not support them.)
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/../assets"
DST="$HERE/assets"

[ -d "$SRC" ] || { echo "error: $SRC not found" >&2; exit 1; }

mkdir -p "$DST"
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete \
    --exclude '.godot/' --exclude '*.import' \
    "$SRC/" "$DST/"
else
  rm -rf "$DST"
  mkdir -p "$DST"
  cp -r "$SRC/." "$DST/"
fi

echo "synced $(find "$DST" -type f | wc -l) files -> desktop-godot/assets/"
