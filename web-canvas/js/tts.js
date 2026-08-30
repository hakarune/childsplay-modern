// tts.js — the one "say this" entry point (Design Policy §E).
//
// The spoken lines are BAKED into audio files at assets/voice/<slug>.ogg by
// tools/gen-voice.sh, so a child hears the instruction even if the browser
// has no speech engine. Order of preference per phrase:
//   1. the baked clip  (voice/<slug>.ogg)
//   2. live speechSynthesis  (covers phrases with no clip, other languages)
//   3. silence
// Everything here respects the "voice" mute channel.

import { isMuted, loadSound, playSound } from './engine.js';

/** Phrase → clip filename stem. MUST match tools/gen-voice.sh `slug()` and
 *  desktop-godot GameContext.gd `_slug()`. */
export function slug(text) {
  return String(text)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48);
}

const _clip = new Map();   // slug -> boolean (a playable baked clip exists)

function _live(text, lang, rate, pitch) {
  if (isMuted('voice')) return;
  try {
    const S = window.speechSynthesis;
    if (!S) return;
    S.cancel();
    const u = new SpeechSynthesisUtterance(String(text));
    u.lang = lang;
    u.rate = rate;
    u.pitch = pitch;
    S.speak(u);
  } catch {
    /* silent */
  }
}

export function say(text, { lang = 'en-US', rate = 0.9, pitch = 1.05 } = {}) {
  if (isMuted('voice') || !text) return;
  const s = slug(text);
  if (!s) return;

  if (_clip.get(s) === false) { _live(text, lang, rate, pitch); return; }

  const path = `voice/v_${s}.ogg`;
  loadSound(path).then((a) => {
    const ok = !!(a && (a.duration > 0 || a.readyState >= 2));
    _clip.set(s, ok);
    if (ok) playSound(path, { channel: 'voice' });
    else _live(text, lang, rate, pitch);
  });
}

// back-compat alias — existing callers use `speak`
export const speak = say;

// We ship baked clips for every instruction line, so a speaker button is
// always worth showing; a phrase with no clip still falls back to live TTS.
export function hasVoice() { return true; }

export function stopSpeaking() {
  try { window.speechSynthesis && window.speechSynthesis.cancel(); } catch { /* */ }
}
