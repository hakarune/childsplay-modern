// tts.js — the one text-to-speech entry point (Design Policy §E.2).
//
// Gated on the "voice" mute channel. Silent-degrades when the browser has
// no speech engine. Games call `speak(text, { lang })` for the instruction
// button and for any spoken labels.

import { isMuted } from './engine.js';

/** True when a speech engine is present (voices may still be loading). */
export function hasVoice() {
  try {
    return typeof window !== 'undefined' && !!window.speechSynthesis
      && typeof window.SpeechSynthesisUtterance === 'function';
  } catch {
    return false;
  }
}

export function speak(text, { lang = 'en-US', rate = 0.9, pitch = 1.05 } = {}) {
  if (isMuted('voice') || !hasVoice() || !text) return;
  try {
    const S = window.speechSynthesis;
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

export function stopSpeaking() {
  try { window.speechSynthesis && window.speechSynthesis.cancel(); } catch { /* */ }
}
