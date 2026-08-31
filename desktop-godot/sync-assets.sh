#!/usr/bin/env bash
#
# sync-assets.sh — mirror the CURATED shared assets into desktop-godot/assets/.
#
# The Godot 4 engine can only see resources under its own project root
# (res://). The canonical art/audio lives in ../assets/ and is shared with
# the web target, so this script copies it in. desktop-godot/assets/ is
# git-ignored; run this after cloning and whenever ../assets/ changes.
#
# ../assets/ is the hand-maintained source of truth; only the curated
# pools are mirrored into res:// (Design Policy §A):
#   graphics: ../assets/graphics/{pools,themes}
#   audio:    ../assets/audio/{sfx,voice,soundmemory,flashcards}
#   plus fonts/ and data/.
# (A symlink would be simpler but the project's storage is a FUSE mount
#  that does not support them.)
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/../assets"
DST="$HERE/assets"

[ -d "$SRC" ] || { echo "error: $SRC not found" >&2; exit 1; }
[ -d "$SRC/graphics/pools" ] || { echo "error: $SRC/graphics/pools not found" >&2; exit 1; }
[ -d "$SRC/audio/sfx" ]      || { echo "error: $SRC/audio/sfx not found" >&2; exit 1; }

# The subtrees to mirror, relative to $SRC. Anything under $DST that is not
# on this list is deleted (see the prune step below).
SUBTREES=(
  graphics/pools
  graphics/themes
  audio/sfx
  audio/voice
  audio/soundmemory
  audio/flashcards
  fonts
  data
)

_have_rsync() { command -v rsync >/dev/null 2>&1; }

# --- prune: drop anything in $DST that is not one of the mirrored -------
#     subtrees (clears legacy files left by an older, broader sync).
if [ -d "$DST" ]; then
  find "$DST" -mindepth 1 -maxdepth 1 -not -name 'graphics' -not -name 'audio' \
       -not -name 'fonts' -not -name 'data' -exec rm -rf {} +
  find "$DST/graphics" -mindepth 1 -maxdepth 1 \
       -not -name 'pools' -not -name 'themes' -exec rm -rf {} + 2>/dev/null || true
  find "$DST/audio" -mindepth 1 -maxdepth 1 \
       -not -name 'sfx' -not -name 'voice' -not -name 'soundmemory' \
       -not -name 'flashcards' -exec rm -rf {} + 2>/dev/null || true
fi

for sub in "${SUBTREES[@]}"; do
  src="$SRC/$sub"
  dst="$DST/$sub"
  [ -d "$src" ] || { echo "  skip (absent): $sub"; continue; }
  mkdir -p "$dst"
  if _have_rsync; then
    # Incremental: unchanged files keep their mtime, so Godot skips re-import.
    rsync -a --delete --exclude '.godot/' --exclude '*.import' "$src/" "$dst/"
  else
    rm -rf "$dst"; mkdir -p "$dst"; cp -r "$src/." "$dst/"
  fi
done

echo "synced $(find "$DST" -type f ! -name '*.import' | wc -l) files -> desktop-godot/assets/"
