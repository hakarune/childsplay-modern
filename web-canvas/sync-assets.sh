#!/usr/bin/env bash
#
# sync-assets.sh - (re)build web-canvas/assets/ from the shared ../assets/.
#
# Graphics come entirely from the flat, purpose-named pools built by
# tools/migrate-assets.sh; audio from the pools built by
# tools/migrate-audio.sh (Design Policy §A). This script no longer touches
# the legacy `assets/graphics/lib/`, `assets/audio/lib/` or
# `assets/audio/alphabet-sounds/` trees — they are provenance only.
#
# Run after cloning or whenever ../assets/ changes. The result is checked
# in so `web-canvas/` deploys as-is.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/../assets"
DST="$HERE/assets"

[ -d "$SRC" ] || { echo "error: $SRC not found" >&2; exit 1; }

POOLS="$SRC/graphics/pools"
APOOL="$SRC/audio"

[ -d "$POOLS" ]        || { echo "error: $POOLS not found — run tools/migrate-assets.sh" >&2; exit 1; }
[ -d "$APOOL/sfx" ]    || { echo "error: $APOOL/sfx not found — run tools/migrate-audio.sh" >&2; exit 1; }

rm -rf "$DST"
mkdir -p "$DST"/{icons,fonts,backgrounds,animals,ui,soundpics,sfx,voice,data}
mkdir -p "$DST"/sprites/{packid,billiards,aquarium}
mkdir -p "$DST"/soundmemory/snd
mkdir -p "$DST"/flashcards

# --- graphics: straight from the pools (Design Policy §A) ------------
cp "$POOLS/backgrounds/"*       "$DST/backgrounds/"
cp "$POOLS/animals/"*           "$DST/animals/"
cp "$POOLS/ui/"*                "$DST/ui/"
cp "$POOLS/soundpics/"*         "$DST/soundpics/"
cp "$POOLS/icons/"*             "$DST/icons/"
cp "$SRC/data/"*.json           "$DST/data/" 2>/dev/null || true
[ -d "$SRC/data/quiz" ] && { mkdir -p "$DST/data/quiz"; cp "$SRC/data/quiz/"*.json "$DST/data/quiz/" 2>/dev/null || true; }
cp "$POOLS/sprites/packid/"*    "$DST/sprites/packid/"
cp "$POOLS/sprites/billiards/"* "$DST/sprites/billiards/"
cp "$POOLS/sprites/aquarium/"*  "$DST/sprites/aquarium/"

# --- alternate-art overlays (Design Policy §C.4), if any exist -------
# assets/graphics/themes/<style>/<pool>/<name> -> web-canvas/assets/themes/…
# manifest.json then carries `themes/<style>/<pool>/<name>` keys and
# engine.resolveImage() prefers them when that art style is selected.
if [ -d "$SRC/graphics/themes" ]; then
  mkdir -p "$DST/themes"
  cp -R "$SRC/graphics/themes/." "$DST/themes/"
  echo "  overlay art: $(find "$DST/themes" -type f | wc -l) files under themes/"
fi

# --- baked voice pack (Design Policy §E) — instructions & names as audio --
cp "$SRC/audio/voice/"*.ogg "$DST/voice/" 2>/dev/null || echo "  (no voice pack — run tools/gen-voice.sh)"

# --- UI font ---------------------------------------------------------
cp "$SRC/fonts/DejaVuSansCondensed-Bold.ttf" "$DST/fonts/"

# --- audio: straight from the pools (tools/migrate-audio.sh) ---------
# sfx/ and flashcards/ keep their pool names 1:1 (flashcards are flat,
# <word>_<lang>.ogg); the shared named-clip set lands under
# soundmemory/snd/ where findsound.js + soundmemory.js expect it.
cp "$APOOL/sfx/"*                 "$DST/sfx/"
cp "$APOOL/soundmemory/"*.ogg     "$DST/soundmemory/snd/"
cp "$APOOL/flashcards/"*.ogg      "$DST/flashcards/"

# --- image manifest: stem -> best available file (svg > png > jpg > …) ---
# engine.resolveImage() reads this so a game can reference `backgrounds/castle`
# with no extension and get the highest-priority file that exists (Policy §C.2).
python3 - "$DST" > "$DST/manifest.json" <<'PY'
import os, sys, json
dst = sys.argv[1]
PRIO = {".svg": 0, ".png": 1, ".jpg": 2, ".jpeg": 3, ".webp": 4}
best = {}
for root, _dirs, files in os.walk(dst):
    for f in files:
        stem, ext = os.path.splitext(f)
        ext = ext.lower()
        if ext not in PRIO:
            continue
        rel = os.path.relpath(os.path.join(root, f), dst).replace(os.sep, "/")
        key = os.path.splitext(rel)[0]
        cur = best.get(key)
        if cur is None or PRIO[ext] < PRIO[os.path.splitext(cur)[1].lower()]:
            best[key] = rel
print(json.dumps(best, separators=(",", ":"), sort_keys=True))
PY

echo "web assets rebuilt: $(find "$DST" -type f | wc -l) files, $(du -sh "$DST" | cut -f1)"
