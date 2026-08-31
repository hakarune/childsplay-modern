#!/usr/bin/env bash
#
# migrate-audio.sh — build the flat, purpose-named audio pools that the
# games reference, out of the legacy `assets/audio/lib/CPData/…` dump and
# the `assets/audio/alphabet-sounds/` locale packs (Design Policy §A).
#
#   assets/audio/
#     sfx/          one flat folder of effect clips, referenced by bare
#                   filename on both targets (Godot resolves by basename,
#                   web by `sfx/<name>`)
#     soundmemory/  the shared Find Sound / Sound Memory clip set: <id>.ogg
#     flashcards/<word>_<lang>.ogg   recorded animal-name clips (de/nl/fr/es);
#                   flat, language as a filename suffix so every name is
#                   globally unique and adding a language later is just
#                   "drop <word>_ja.ogg files + a JA button"
#     voice/        baked spoken lines — owned by tools/gen-voice.sh, NOT
#                   touched here
#
# The legacy trees (`assets/audio/lib/`, `assets/audio/alphabet-sounds/`)
# stay in the repo for provenance but are NO LONGER synced to either
# target — the twin of `assets/graphics/lib/` after tools/migrate-assets.sh.
# Re-run only when the source set changes; the pool files are committed.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIO="$HERE/../assets/audio"
LIB="$AUDIO/lib/CPData"
ALPHA="$AUDIO/alphabet-sounds"

[ -d "$LIB" ] || { echo "error: $LIB not found" >&2; exit 1; }

rm -rf "$AUDIO/sfx" "$AUDIO/soundmemory" "$AUDIO/flashcards"
mkdir -p "$AUDIO/sfx" "$AUDIO/soundmemory" "$AUDIO/flashcards"

# --- sfx: effect clips ---------------------------------------------------
# dest name = the exact basename the games ask for. Where the two targets
# historically diverged on a name, the canonical (web) name wins and the
# Godot constant was updated to match (FourRow SND_WIN/SND_LOSS, Aquarium
# SND_AMBIENT). `eat.wav` and `waka.wav` are two different Pac-Man chomp
# clips — Godot uses the first, web the second; both are kept.
declare -A SFX=(
  [good.ogg]="good.ogg"
  [wrong.ogg]="wrong.ogg"
  [dealcard1.wav]="dealcard1.wav"
  [bummer.wav]="bummer.wav"
  [wahoo.wav]="wahoo.wav"
  [button_hover.wav]="button_hover.wav"
  [volumecheck.wav]="volumecheck.wav"
  [winner.ogg]="PongData/winner.ogg"
  [bump.wav]="PongData/bump.wav"
  [pick.wav]="PongData/pick.wav"
  [goal.wav]="PongData/goal.wav"
  [sndh.wav]="BilliardData/sndh.wav"
  [sndt.wav]="BilliardData/sndt.wav"
  [blub0.wav]="FishtankData/sounds/blub0.wav"
  [poolsplash.wav]="FishtankData/sounds/poolsplash.wav"
  [eat.wav]="PackidData/eat.wav"
  [waka.wav]="PackidData/waka.wav"
  [finlevel.wav]="PackidData/finlevel.wav"
  [aqua_ambient.ogg]="FishtankData/sounds/glockenschmoutz.ogg"
  [fourrow_win.ogg]="FourrowData/won.ogg"
  [fourrow_loss.ogg]="FourrowData/loss.ogg"
)
for dst in "${!SFX[@]}"; do
  src="$LIB/${SFX[$dst]}"
  [ -f "$src" ] && cp "$src" "$AUDIO/sfx/$dst" || echo "  WARN missing sfx source: ${SFX[$dst]}" >&2
done

# --- soundmemory: the shared named-clip set (Find Sound + Sound Memory + --
#     Falling Letter's "zap"). One flat folder, keyed by the same clean
#     stem the picture uses (see SOUND_RENAME in tools/migrate-assets.sh).
declare -A SOUND_RENAME=(
  [chiken]=chicken [carhorn]=car-horn [duck2]=duck [clarinette]=clarinet
  [didjeridu]=didgeridoo [shenai]=shehnai [police]=police-car
)
for f in "$LIB/SoundmemoryData/Sounds/"*.ogg; do
  [ -f "$f" ] || continue
  legacy="$(basename "$f" .ogg)"
  cp "$f" "$AUDIO/soundmemory/${SOUND_RENAME[$legacy]:-$legacy}.ogg"
done

# --- flashcards: recorded animal names, <word>_<lang>.ogg (flat) -----
# Only the words in the Flashcards DECK (desktop-godot Flashcards.gd /
# web-canvas flashcards.js — the two lists are kept identical). Extend
# DECK_WORDS here in the same commit that extends the DECK. To add a
# language: add its FlashCardsSounds pack under assets/audio/alphabet-sounds/,
# add its code to FLASH_LANGS, re-run, and add the button in both games.
DECK_WORDS=(bear cow dog elephant fox frog hippopotamus horse lion pig penguin rooster)
FLASH_LANGS=(de nl fr es)
for lang in "${FLASH_LANGS[@]}"; do
  src="$ALPHA/alphabet-sounds_$lang/FlashCardsSounds/$lang"
  [ -d "$src" ] || { echo "  WARN missing flashcard set: $lang" >&2; continue; }
  for w in "${DECK_WORDS[@]}"; do
    [ -f "$src/$w.ogg" ] && cp "$src/$w.ogg" "$AUDIO/flashcards/${w}_${lang}.ogg"
  done
done

echo "audio pools built:"
printf '  %-16s %s files\n' "sfx"          "$(find "$AUDIO/sfx" -type f | wc -l)"
printf '  %-16s %s files\n' "soundmemory"  "$(find "$AUDIO/soundmemory" -type f | wc -l)"
printf '  %-16s %s files\n' "flashcards"   "$(find "$AUDIO/flashcards" -type f | wc -l)"
