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
POOL="$HERE/../assets/graphics/pools"

[ -d "$LIB" ] || { echo "error: $LIB not found" >&2; exit 1; }
rm -rf "$POOL"
mkdir -p "$POOL"/{backgrounds,animals,ui}

# --- backgrounds: GPL paintings (a curated, puzzle-friendly subset) -------
PAINT_SRC="$LIB/WipeData/tileset_1"
for p in bruegel0 bruegel1 gogh0 gogh1 gogh3 monet0 monet1 monet3 \
         pieck0 pieck1 pieck2 rembrandt0 rembrandt1 renoir0 \
         vermeer1 vermeer2 vermeer3; do
  [ -f "$PAINT_SRC/$p.jpg" ] && cp "$PAINT_SRC/$p.jpg" "$POOL/backgrounds/$p.jpg"
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

# --- ui: card faces, sponge, bubble ------------------------------------
cp "$AN_SRC/CP_cardfront.png"                 "$POOL/ui/card_front.png"
cp "$AN_SRC/CP_cardback.png"                  "$POOL/ui/card_back.png"
cp "$LIB/WipeData/sponge.png"                 "$POOL/ui/sponge.png"
cp "$LIB/FishtankData/backgrounds/childsplay/blub0.png" "$POOL/ui/bubble.png"

echo "pools built:"
for d in backgrounds animals ui; do
  printf '  %-14s %s files\n' "$d" "$(find "$POOL/$d" -type f | wc -l)"
done
