#!/usr/bin/env bash
#
# migrate-assets.sh — build the flat, purpose-named graphics pools that the
# games reference, out of the legacy `assets/graphics/lib/CPData/*Data/…`
# dump (Design Policy §A).
#
#   assets/graphics/pools/
#     backgrounds/   full-scene pictures (paintings, aquarium tanks)
#     animals/       single-subject animal cut-outs
#     ui/            shared chrome (card faces, sponge, bubble, …)
#
# The legacy tree stays in the repo for provenance; the sync scripts now
# curate from pools/ instead of globbing lib/. Re-run only when the source
# set changes; the pool files are committed.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$HERE/../assets/graphics/lib/CPData"
SP="$HERE/../assets/graphics/lib/SPData/themes"
POOL="$HERE/../assets/graphics/pools"

[ -d "$LIB" ] || { echo "error: $LIB not found" >&2; exit 1; }
rm -rf "$POOL"
mkdir -p "$POOL"/{backgrounds,animals,ui,soundpics,icons}
mkdir -p "$POOL"/sprites/{packid,billiards,aquarium}

# --- backgrounds: GPL paintings, difficulty baked into the filename ------
# `<stem>_<tier>.jpg` (Design Policy §A.3); untagged art = eligible at any
# tier. Puzzle / Wipe read the tag off the filename — no data file.
PAINT_SRC="$LIB/WipeData/tileset_1"
declare -A PAINT_TIER=(
  [gogh0]=easy [monet0]=easy [pieck0]=easy [pieck1]=easy [renoir0]=easy
  [gogh1]=med [gogh3]=med [monet1]=med [pieck2]=med [rembrandt0]=med [vermeer1]=med
  [bruegel0]=hard [bruegel1]=hard [monet3]=hard [rembrandt1]=hard [vermeer2]=hard [vermeer3]=hard
)
for p in "${!PAINT_TIER[@]}"; do
  [ -f "$PAINT_SRC/$p.jpg" ] && cp "$PAINT_SRC/$p.jpg" "$POOL/backgrounds/${p}_${PAINT_TIER[$p]}.jpg"
done

# --- backgrounds: aquarium tank scenes, renamed aquarium_1..N ------------
TANK_SRC="$LIB/FishtankData/backgrounds/childsplay"
i=1
for n in 1 2 3 4 5 6; do
  [ -f "$TANK_SRC/$n.jpg" ] && cp "$TANK_SRC/$n.jpg" "$POOL/backgrounds/aquarium_$i.jpg" && i=$((i + 1))
done

# --- animals: the tileset_2 numbered deck (01_cat … 21_frog) ------------
AN_SRC="$LIB/Memory_spData/tileset_2/childsplay"
for f in "$AN_SRC"/[0-9]*_*.png; do
  [ -f "$f" ] && cp "$f" "$POOL/animals/$(basename "$f")"
done

# ...plus a few named animals the numbered deck lacks (used by Flashcards),
# from the Find Sound picture set (first match wins across level folders).
for a in dog horse rooster; do
  f="$(find "$LIB/FindsoundData/Images" -name "$a.png" -print -quit 2>/dev/null || true)"
  [ -n "$f" ] && cp "$f" "$POOL/animals/$a.png"
done

# --- ui: card faces, sponge, bubble, sound-card face -----------------
cp "$AN_SRC/CP_cardfront.png"                 "$POOL/ui/card_front.png"
cp "$AN_SRC/CP_cardback.png"                  "$POOL/ui/card_back.png"
cp "$LIB/WipeData/sponge.png"                 "$POOL/ui/sponge.png"
cp "$LIB/FishtankData/backgrounds/childsplay/blub0.png" "$POOL/ui/bubble.png"
cp "$LIB/soundbut.png"                        "$POOL/ui/soundbut.png"

# --- soundpics: the Find Sound / Sound Memory picture set (deduped) ----
for f in "$LIB/FindsoundData/Images/"level*/*.png; do
  [ -f "$f" ] && cp -n "$f" "$POOL/soundpics/$(basename "$f")"
done

# --- sprites/packid: player frames, wall + fruit tiles, ghosts --------
cp "$LIB/PackidData/"pac_*.png "$LIB/PackidData/brick.png" \
   "$LIB/PackidData/kers.png" "$LIB/PackidData/appel.png" \
   "$LIB/PackidData/banaan.png" "$LIB/PackidData/citroen.png" \
   "$LIB/PackidData/peer.png"  "$POOL/sprites/packid/"

# --- sprites/billiards: balls, pocket, cue --------------------------
cp "$LIB/BilliardData/ball1.png" "$LIB/BilliardData/ball2.png" \
   "$LIB/BilliardData/hole.png"  "$LIB/BilliardData/stick.png" "$POOL/sprites/billiards/"

# --- sprites/aquarium: 2-frame fish swim cycles ---------------------
# The pool stem IS the fish name (hyphenated) — the game derives the
# spoken/label name from it (`_` ← `-`) and gen-voice.sh bakes a
# v_<name>.ogg to match. Adding a fish = drop <name>_0.png / <name>_1.png.
FT="$LIB/FishtankData"
declare -A FISH=(
  [shark1]=shark [manta]=manta-ray [eel]=eel [discus2]=discus
  [QueenAngel]=angelfish [butfish]=butterfly-fish [blueking2]=blue-tang
  [collaris]=tang [six_barred]=wrasse [cichlid1]=cichlid [newf1]=goldfish
  [f01]=emperor-angelfish [f04]=moorish-idol [f06]=bass [f09]=pomfret [f13]=snapper
)
for src in "${!FISH[@]}"; do
  name="${FISH[$src]}"
  [ -f "$FT/${src}_0.png" ] && cp "$FT/${src}_0.png" "$POOL/sprites/aquarium/${name}_0.png"
  [ -f "$FT/${src}_1.png" ] && cp "$FT/${src}_1.png" "$POOL/sprites/aquarium/${name}_1.png"
done

# --- icons: one per game id (renamed from the legacy menuicons) ------
declare -A ICONMAP=(
  [packid]=childsplay/menuicons/packid.icon.png
  [fallingletter]=childsplay/menuicons/fallingletters.icon.png
  [soundmemory]=childsplay/menuicons/soundmemory.icon.png
  [memory]=childsplay/menuicons/memory_sp.icon.png
  [billiards]=childsplay/menuicons/billiard.icon.png
  [findsound]=childsplay/menuicons/findsound.icon.png
  [puzzle]=childsplay/menuicons/puzzle.icon.png
  [aquarium]=childsplay/menuicons/fishtank.icon.png
  [pong]=childsplay/menuicons/pong.icon.png
  [findit]=childsplay/menuicons/findit_sp.icon.png
  [fourrow]=childsplay/menuicons/fourrow.icon.png
  [flashcards]=childsplay/menuicons/flashcards.icon.png
  [blockbreaker]=childsplay/menuicons/BlockBreaker.icon.png
  [simon]=childsplay/menuicons/simon_sp.icon.png
  [electro]=childsplay/menuicons/electro_sp.icon.png
  [tictactoe]=childsplay/menuicons/TicTacToe.icon.png
  [wipe]=childsplay/menuicons/wipe.icon.png
  [ichanger]=childsplay/menuicons/ichanger.icon.png
  [numbers]=childsplay/menuicons/numbers_sp.icon.png
  [synonyms]=seniorplay/menuicons/synonyms.icon.png
  [quiz]=seniorplay/menuicons/quiz_general.icon.png
)
for id in "${!ICONMAP[@]}"; do
  src="$SP/${ICONMAP[$id]}"
  [ -f "$src" ] && cp "$src" "$POOL/icons/$id.png"
done

echo "pools built:"
for d in backgrounds animals ui soundpics icons sprites/packid sprites/billiards sprites/aquarium; do
  printf '  %-20s %s files\n' "$d" "$(find "$POOL/$d" -type f 2>/dev/null | wc -l)"
done
