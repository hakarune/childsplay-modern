#!/usr/bin/env bash
#
# gen-voice.sh — bake the spoken lines into audio files so the games never
# depend on the OS / browser having a speech engine (Design Policy §E).
#
# Each phrase a game may pass to `say()` becomes assets/audio/voice/<slug>.ogg.
# The <slug> is computed the SAME way here, in web-canvas/js/tts.js and in
# desktop-godot GameContext.gd, so a runtime lookup by phrase finds the clip.
# At runtime the baked clip plays first; live TTS and then silence are the
# fallbacks.
#
# Per clip, best first:
#   1. an original human recording, if we have one   (HUMAN_SRC map below)
#   2. a synthesiser, chosen with  TTS=<engine>  (default: auto):
#        piper   — offline neural, best quality      (set PIPER_MODEL / PATH)
#        google  — Google Translate TTS, natural, needs network + curl.
#                  Unofficial endpoint; fine for a one-time bake of short
#                  lines. GTTS_LANG (default en) picks en / en-GB / en-AU / …
#        espeak  — offline, robotic, always available last resort
#      auto = piper if a model is present, else espeak.
#
# A piper or google run re-bakes the synthetic clips (that is the point);
# espeak keeps whatever already exists unless FORCE=1. Human-sourced clips
# are never overwritten by a synthesiser — use FORCE=1 to swap a new one
# in. Re-run whenever a spoken string changes; commit the .ogg files, then
# re-run both sync-assets.sh.
#
#   TTS=google tools/gen-voice.sh            # natural voice, no install
#   PIPER_MODEL=~/piper/en_US-lessac-medium.onnx tools/gen-voice.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/../assets/audio/voice"
EN_GB="$HERE/../assets/audio/alphabet-sounds/alphabet-sounds_en_GB/AlphabetSounds/en_GB"
mkdir -p "$OUT"

command -v ffmpeg >/dev/null || { echo "need ffmpeg"; exit 1; }

PIPER_MODEL="${PIPER_MODEL:-$HOME/.local/share/piper/en_US-lessac-medium.onnx}"
GTTS_LANG="${GTTS_LANG:-en}"
have_piper() { command -v piper >/dev/null 2>&1 && [ -f "$PIPER_MODEL" ]; }

TTS="${TTS:-auto}"
[ "$TTS" = auto ] && { have_piper && TTS=piper || TTS=espeak; }
case "$TTS" in
  piper)  have_piper || { echo "TTS=piper but no piper binary / PIPER_MODEL"; exit 1; }
          ENGINE="piper ($(basename "$PIPER_MODEL" .onnx))" ;;
  google) command -v curl >/dev/null || { echo "TTS=google needs curl"; exit 1; }
          ENGINE="Google Translate TTS (tl=$GTTS_LANG)" ;;
  espeak) command -v espeak-ng >/dev/null || { echo "TTS=espeak needs espeak-ng"; exit 1; }
          ENGINE="espeak-ng (robotic — try TTS=google or TTS=piper)" ;;
  *) echo "TTS must be one of: auto piper google espeak"; exit 1 ;;
esac

# slug: lowercase, drop everything but a-z 0-9, collapse to single dashes,
# trim, cap length. MUST match tts.js `slug()` and GameContext.gd `_slug()`.
slug() {
  local s
  s="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | LC_ALL=C sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  printf '%s' "${s:0:48}"
}

# slug -> original human recording. Letters + digits come from the GPL
# en_GB AlphabetSounds pack (files are named by codepoint: U0061 = 'a').
# Set NO_HUMAN=1 to ignore these and synthesise everything for a uniform
# first pass — then add HUMAN_SRC entries and re-run to swap real
# recordings back in selectively.
declare -A HUMAN_SRC=()
if [ "${NO_HUMAN:-0}" != "1" ]; then
  for n in 0 1 2 3 4 5 6 7 8 9; do
    HUMAN_SRC["$n"]="$(printf '%s/U%04x.ogg' "$EN_GB" $((48 + n)))"
  done
  for c in {a..z}; do
    HUMAN_SRC["$c"]="$(printf '%s/U%04x.ogg' "$EN_GB" "'$c")"
  done
fi

encode() {  # $1 = input audio  ->  $2 = v_<slug>.ogg
  ffmpeg -y -loglevel error -i "$1" -ac 1 -ar 22050 -c:a libvorbis -q:a 4 "$2"
}

synth() {   # $1 = text  ->  $2 = audio file (encode() re-encodes to ogg)
  case "$TTS" in
    piper)
      printf '%s\n' "$1" | piper --model "$PIPER_MODEL" --output_file "$2" >/dev/null 2>&1 ;;
    google)
      local i
      for i in 1 2 3; do
        curl -sS -f -A 'Mozilla/5.0' -G 'https://translate.google.com/translate_tts' \
          --data-urlencode 'ie=UTF-8' --data-urlencode 'client=tw-ob' \
          --data-urlencode "tl=$GTTS_LANG" --data-urlencode "q=$1" \
          -o "$2" && return 0
        sleep 3
      done
      echo "  !! google TTS failed: $1" >&2; return 1 ;;
    espeak)
      # slower, a touch higher, small word gap — friendlier for young ears
      espeak-ng -v en-us -s 150 -p 55 -g 4 -w "$2" "$1" ;;
  esac
}

say_line() {
  local text="$1" sl human tmp exists
  sl="$(slug "$text")"
  [ -n "$sl" ] || return 0
  human="${HUMAN_SRC[$sl]:-}"
  [ -f "$OUT/v_$sl.ogg" ] && exists=1 || exists=0

  # An existing clip is kept unless FORCE=1 — so a plain re-run just fills
  # in new / missing phrases, no churn. FORCE=1 re-bakes the whole pack
  # with the chosen TTS= engine (and re-pulls HUMAN_SRC). Neither TTS
  # output nor libvorbis is byte-reproducible, so keeping is the default.
  if [ "$exists" = 1 ] && [ "${FORCE:-0}" != "1" ]; then
    printf '  %-40s v_%s.ogg   (kept)\n' "$text" "$sl"
    return 0
  fi

  if [ -n "$human" ] && [ -f "$human" ]; then
    encode "$human" "$OUT/v_$sl.ogg"
    printf '  %-40s v_%s.ogg   (human)\n' "$text" "$sl"
    return 0
  fi

  tmp="$OUT/.v_$sl.wav"
  synth "$text" "$tmp"
  encode "$tmp" "$OUT/v_$sl.ogg"
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
  "match the pictures"
  "match the letters"
  "match the numbers"
  # --- numbers game: tap number N ---
  "tap number 1" "tap number 2" "tap number 3" "tap number 4" "tap number 5"
  "tap number 6" "tap number 7" "tap number 8" "tap number 9"
  # --- Word Maker: starting letters + hint ---
  "make words that start with S"
  "make words that start with B"
  "make words that start with C"
  "make words that start with T"
  "make words that start with P"
  "here is a word you could make"
  "that is a word"
  "not a word, try again"
  # --- Aquarium fish names (Aquarium.gd / aquarium.js SPECIES) ---
  "shark" "manta ray" "eel" "discus" "angelfish" "butterfly fish" "blue tang"
  "tang" "wrasse" "cichlid" "goldfish" "fish"
  "emperor angelfish" "Moorish idol" "bass" "pomfret" "snapper"
  # --- animal-pool names (Flashcards deck + Memory/Image Changer nameFromId) ---
  "bear" "cow" "dog" "elephant" "fox" "frog" "hippopotamus" "horse" "lion"
  "pig" "penguin" "rooster" "cat" "sheep" "panda" "wolf" "monkey"
  "turtle" "chicken" "redbird" "bluebirds" "gnu"
  # bluebaby / greenbaby → friendly names (GameContext.NAME_OVERRIDES / util.js)
  "baby in blue" "baby in green"
  # --- letters & digits: served from the human en_GB pack (HUMAN_SRC) ---
  a b c d e f g h i j k l m n o p q r s t u v w x y z
  0 1 2 3 4 5 6 7 8 9
)

echo "rendering ${#PHRASES[@]} phrases with $ENGINE -> $OUT"
for p in "${PHRASES[@]}"; do
  say_line "$p"
  # be gentle on the unofficial Google endpoint
  [ "$TTS" = google ] && sleep 0.6
done
echo "voice pack: $(find "$OUT" -name '*.ogg' | wc -l) files, $(du -sh "$OUT" | cut -f1)"
