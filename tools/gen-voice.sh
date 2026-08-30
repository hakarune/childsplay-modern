#!/usr/bin/env bash
#
# gen-voice.sh — bake the spoken lines into audio files so the games never
# depend on the OS / browser having a speech engine (Design Policy §E).
#
# Every phrase a game may pass to `say()` is rendered here with espeak-ng
# and encoded to OGG Vorbis at assets/audio/voice/<slug>.ogg. The <slug>
# is computed the SAME way in tools/gen-voice.sh, web-canvas/js/tts.js and
# desktop-godot GameContext.gd, so a runtime lookup by phrase finds the
# clip. If a clip is missing, the runtime falls back to live TTS, then to
# silence.
#
# Re-run whenever a spoken string changes; commit the .ogg files.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/../assets/audio/voice"
mkdir -p "$OUT"

command -v espeak-ng >/dev/null || { echo "need espeak-ng (pkg install espeak-ng)"; exit 1; }
command -v ffmpeg    >/dev/null || { echo "need ffmpeg"; exit 1; }

# slug: lowercase, drop everything but a-z 0-9, collapse to single dashes,
# trim, cap length. MUST match tts.js `slug()` and GameContext.gd `_slug()`.
slug() {
  local s
  s="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | LC_ALL=C sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  printf '%s' "${s:0:48}"
}

say_line() {
  local text="$1" sl
  sl="$(slug "$text")"
  [ -n "$sl" ] || return 0
  local tmp="$OUT/.v_$sl.wav"
  # slower, a touch higher, small word gap — friendlier for young ears
  espeak-ng -v en-us -s 150 -p 55 -g 4 -w "$tmp" "$text"
  ffmpeg -y -loglevel error -i "$tmp" -ac 1 -ar 22050 -c:a libvorbis -q:a 3 "$OUT/v_$sl.ogg"
  rm -f "$tmp"
  printf '  %-40s v_%s.ogg\n' "$text" "$sl"
}

PHRASES=(
  # --- instruction lines (HUD 🔊 button) ---
  "find what is different on the right picture"
  "drag a wire from each picture to its name"
  "drag to wipe the cover away"
  "tap or press space to launch"
  "slide to move the paddle"
  "press Start, then repeat the sequence"
  "watch and listen"
  "your turn, tap the colours in order"
  "your turn, you are X"
  "computer thinking"
  "game over"
  "your turn"
  "red's turn"
  "yellow's turn"
  "blue's turn"
  "orange's turn"
  "remember the pictures, then press Start"
  "remember the pictures"
  "which picture changed"
  "watch closely"
  "nice"
  "remember where the numbers are, then press Start"
  "take another look"
  "tap letters, then Enter"
  "remember the pictures"
  # --- numbers game: tap number N ---
  "tap number 1" "tap number 2" "tap number 3" "tap number 4" "tap number 5"
  "tap number 6" "tap number 7" "tap number 8" "tap number 9"
  # --- Word Maker: starting letters ---
  "make words that start with S"
  "make words that start with B"
  "make words that start with C"
  "make words that start with T"
  "make words that start with P"
  # --- animals (Aquarium fish + Flashcards deck) ---
  "shark" "manta ray" "eel" "discus" "angelfish" "butterfly fish" "blue tang"
  "tang" "wrasse" "cichlid" "goldfish" "fish"
  "bear" "cow" "dog" "elephant" "fox" "frog" "hippopotamus" "horse" "lion"
  "pig" "penguin" "rooster" "cat" "sheep" "panda" "wolf" "monkey"
)

echo "rendering ${#PHRASES[@]} phrases -> $OUT"
for p in "${PHRASES[@]}"; do say_line "$p"; done
echo "voice pack: $(find "$OUT" -name '*.ogg' | wc -l) files, $(du -sh "$OUT" | cut -f1)"
