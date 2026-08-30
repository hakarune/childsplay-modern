#!/usr/bin/env bash
#
# sync-assets.sh - (re)build web-canvas/assets/ from the shared ../assets/.
#
# Graphics come entirely from the flat, purpose-named pools built by
# tools/migrate-assets.sh (Design Policy §A) — this script no longer
# touches the legacy `assets/graphics/lib/` tree. Audio still comes from
# ../assets/audio/lib/ until an audio-pool migration lands.
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
A="$SRC/audio/lib/CPData"

[ -d "$POOLS" ] || { echo "error: $POOLS not found — run tools/migrate-assets.sh" >&2; exit 1; }

rm -rf "$DST"
mkdir -p "$DST"/{icons,fonts,backgrounds,animals,ui,soundpics,sfx,voice,data}
mkdir -p "$DST"/sprites/{packid,billiards,aquarium}
mkdir -p "$DST"/soundmemory/snd
mkdir -p "$DST"/flashcards/{de,nl,fr,es}

# --- graphics: straight from the pools (Design Policy §A) ------------
cp "$POOLS/backgrounds/"*       "$DST/backgrounds/"
cp "$POOLS/animals/"*           "$DST/animals/"
cp "$POOLS/ui/"*                "$DST/ui/"
cp "$POOLS/soundpics/"*         "$DST/soundpics/"
cp "$POOLS/icons/"*             "$DST/icons/"
cp "$SRC/data/"*.json           "$DST/data/" 2>/dev/null || true
cp "$POOLS/sprites/packid/"*    "$DST/sprites/packid/"
cp "$POOLS/sprites/billiards/"* "$DST/sprites/billiards/"
cp "$POOLS/sprites/aquarium/"*  "$DST/sprites/aquarium/"

# --- baked voice pack (Design Policy §E) — instructions & names as audio --
cp "$SRC/audio/voice/"*.ogg "$DST/voice/" 2>/dev/null || echo "  (no voice pack — run tools/gen-voice.sh)"

# --- UI font ---------------------------------------------------------
cp "$SRC/fonts/DejaVuSansCondensed-Bold.ttf" "$DST/fonts/"

# --- Sound Memory / Find Sound: the sound clips --------------------
cp "$A/SoundmemoryData/Sounds/"*.ogg "$DST/soundmemory/snd/"

# --- shared sound effects ------------------------------------------
cp "$A/good.ogg" "$A/wrong.ogg" "$A/wahoo.wav" "$A/bummer.wav" \
   "$A/dealcard1.wav" "$A/volumecheck.wav" "$A/button_hover.wav" \
   "$A/PackidData/eat.wav" "$A/PackidData/waka.wav" "$A/PackidData/finlevel.wav" \
   "$A/PongData/winner.ogg" "$A/PongData/bump.wav" "$A/PongData/pick.wav" \
   "$A/BilliardData/sndh.wav" "$A/BilliardData/sndt.wav" \
   "$A/FishtankData/sounds/blub0.wav" "$A/FishtankData/sounds/poolsplash.wav" \
   "$A/PongData/goal.wav" \
   "$DST/sfx/"
cp "$A/FishtankData/sounds/glockenschmoutz.ogg" "$DST/sfx/aqua_ambient.ogg"
cp "$A/FourrowData/won.ogg"  "$DST/sfx/fourrow_win.ogg"
cp "$A/FourrowData/loss.ogg" "$DST/sfx/fourrow_loss.ogg"

# --- Flashcards: recorded animal-name clips (de / nl / fr / es) -------
for lang in de nl fr es; do
  for w in bear cow dog elephant fox frog hippopotamus horse lion pig penguin rooster; do
    src="$SRC/audio/alphabet-sounds/alphabet-sounds_$lang/FlashCardsSounds/$lang/$w.ogg"
    [ -f "$src" ] && cp "$src" "$DST/flashcards/$lang/$w.ogg"
  done
done

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
