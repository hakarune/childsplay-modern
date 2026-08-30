#!/usr/bin/env bash
#
# sync-assets.sh - (re)build web-canvas/assets/ as a small, web-sized
# subset of the shared ../assets/ pool (itself extracted from
# legacy-sources/). The full pool is ~50 MB; the web target only ships
# what the launcher and the five games actually use (~3 MB), flattened
# into friendly paths.
#
# Run after cloning or whenever ../assets/ changes. The result is checked
# in so `web-canvas/` deploys as-is, but this script is the source of
# truth for what belongs there.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/../assets"
DST="$HERE/assets"

[ -d "$SRC" ] || { echo "error: $SRC not found" >&2; exit 1; }

G="$SRC/graphics/lib/CPData"
POOLS="$SRC/graphics/pools"
ICONS="$SRC/graphics/lib/SPData/themes/childsplay/menuicons"
SICONS="$SRC/graphics/lib/SPData/themes/seniorplay/menuicons"
A="$SRC/audio/lib/CPData"

rm -rf "$DST"
mkdir -p "$DST"/{icons,fonts,backgrounds,animals,ui,packid,billiards,aquarium,soundmemory/img,soundmemory/snd,sfx,voice}
mkdir -p "$DST"/flashcards/{de,nl,fr,es}

# --- flat purpose-named graphics pools (Design Policy §A) -------------
cp "$POOLS/backgrounds/"* "$DST/backgrounds/"
cp "$POOLS/animals/"*     "$DST/animals/"
cp "$POOLS/ui/"*          "$DST/ui/"

# --- baked voice pack (Design Policy §E) — instructions & names as audio --
cp "$SRC/audio/voice/"*.ogg "$DST/voice/" 2>/dev/null || echo "  (no voice pack — run tools/gen-voice.sh)"

# --- launcher icons (renamed to our game ids) ---------------------------
cp "$ICONS/packid.icon.png"         "$DST/icons/packid.png"
cp "$ICONS/fallingletters.icon.png" "$DST/icons/fallingletter.png"
cp "$ICONS/soundmemory.icon.png"    "$DST/icons/soundmemory.png"
cp "$ICONS/memory_sp.icon.png"      "$DST/icons/memory.png"
cp "$ICONS/billiard.icon.png"       "$DST/icons/billiards.png"
cp "$ICONS/findsound.icon.png"      "$DST/icons/findsound.png"
cp "$ICONS/puzzle.icon.png"         "$DST/icons/puzzle.png"
cp "$ICONS/fishtank.icon.png"       "$DST/icons/aquarium.png"
cp "$ICONS/pong.icon.png"           "$DST/icons/pong.png"
cp "$ICONS/findit_sp.icon.png"      "$DST/icons/findit.png"
cp "$ICONS/fourrow.icon.png"        "$DST/icons/fourrow.png"
cp "$ICONS/flashcards.icon.png"     "$DST/icons/flashcards.png"
cp "$ICONS/BlockBreaker.icon.png"   "$DST/icons/blockbreaker.png"
cp "$ICONS/simon_sp.icon.png"      "$DST/icons/simon.png"
cp "$ICONS/electro_sp.icon.png"    "$DST/icons/electro.png"
cp "$ICONS/TicTacToe.icon.png"     "$DST/icons/tictactoe.png"
cp "$ICONS/wipe.icon.png"          "$DST/icons/wipe.png"
cp "$ICONS/ichanger.icon.png"      "$DST/icons/ichanger.png"
cp "$ICONS/numbers_sp.icon.png"    "$DST/icons/numbers.png"
cp "$SICONS/synonyms.icon.png"     "$DST/icons/synonyms.png"

# --- UI font -----------------------------------------------------------
cp "$SRC/fonts/DejaVuSansCondensed-Bold.ttf" "$DST/fonts/"

# --- Aquarium: fish swim frames (backgrounds + bubble come from pools) --
FT="$G/FishtankData"
for n in shark1 manta eel discus2 QueenAngel butfish blueking2 collaris \
         six_barred cichlid1 newf1 f01 f04 f06 f09 f13; do
  cp "$FT/${n}_0.png" "$DST/aquarium/${n}_0.png"
  cp "$FT/${n}_1.png" "$DST/aquarium/${n}_1.png"
done

# --- Packid: sprites, wall + cherry tiles, fruit "ghosts" ------------
cp "$G/PackidData/"pac_*.png "$G/PackidData/brick.png" \
   "$G/PackidData/kers.png" "$G/PackidData/appel.png" \
   "$G/PackidData/banaan.png" "$G/PackidData/citroen.png" \
   "$G/PackidData/peer.png" "$DST/packid/"

# --- Billiards: balls, pocket, cue ---------------------------------
cp "$G/BilliardData/ball1.png" "$G/BilliardData/ball2.png" \
   "$G/BilliardData/hole.png" "$G/BilliardData/stick.png" "$DST/billiards/"

# --- Sound Memory: reveal pictures + the sound clips -----------------
# Some names repeat across level folders; first one wins.
for f in "$G/FindsoundData/Images/"level*/*.png; do
  cp -n "$f" "$DST/soundmemory/img/"
done
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
