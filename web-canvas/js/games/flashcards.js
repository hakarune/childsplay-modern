// flashcards.js — picture + word cards. Tap the speaker to hear the word.
//
// English is spoken by the browser's built-in text-to-speech
// (speechSynthesis). German / Dutch / French / Spanish play the recorded
// Childsplay clips we ship, and fall back to TTS in that language if a
// clip is missing. If neither is available the card still shows the
// picture + word — it just stays quiet.

import { Scene, VIEW_W, VIEW_H, img, loadImage, loadSound, playSound } from '../engine.js';
import { roundRect, drawImageFit, inRect } from '../util.js';
import { say } from '../tts.js';

const DECK = [
  { word: 'bear', img: 'animals/03_bear' },
  { word: 'cow', img: 'animals/06_cow' },
  { word: 'dog', img: 'animals/dog' },
  { word: 'elephant', img: 'animals/16_elephant' },
  { word: 'fox', img: 'animals/14_fox' },
  { word: 'frog', img: 'animals/21_frog' },
  { word: 'hippopotamus', img: 'animals/04_hippopotamus' },
  { word: 'horse', img: 'animals/horse' },
  { word: 'lion', img: 'animals/17_lion' },
  { word: 'pig', img: 'animals/02_pig' },
  { word: 'penguin', img: 'animals/05_penguin' },
  { word: 'rooster', img: 'animals/rooster' },
];

const LANGS = [
  { code: 'en', label: 'English', bcp: 'en-US' },
  { code: 'de', label: 'Deutsch', bcp: 'de-DE' },
  { code: 'nl', label: 'Nederlands', bcp: 'nl-NL' },
  { code: 'fr', label: 'Français', bcp: 'fr-FR' },
  { code: 'es', label: 'Español', bcp: 'es-ES' },
];

export default class FlashcardsGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._i = 0;
    this._lang = 0;
    this._unlocked = false;
    for (const c of DECK) loadImage(c.img);
  }

  enter() { this._buttons(); }
  resize() { this._buttons(); }

  _buttons() {
    const cy = VIEW_H - 128;
    this._prevBtn = { x: 70, y: 250, w: 90, h: 220, act: 'prev' };
    this._nextBtn = { x: VIEW_W - 160, y: 250, w: 90, h: 220, act: 'next' };
    this._sayBtn = { x: VIEW_W / 2 - 130, y: VIEW_H - 210, w: 260, h: 60, act: 'say' };
    const cw = 150, gap = 12;
    const total = LANGS.length * cw + (LANGS.length - 1) * gap;
    this._langBtns = LANGS.map((l, k) => ({
      x: (VIEW_W - total) / 2 + k * (cw + gap), y: cy, w: cw, h: 46, act: `lang:${k}`, label: l.label,
    }));
  }

  _say() {
    this._unlocked = true;
    const card = DECK[this._i];
    const L = LANGS[this._lang];
    // English: baked clip → live TTS (say() handles the fallback chain).
    if (L.code === 'en') return say(card.word, { lang: L.bcp, rate: 0.85 });
    // de/nl/fr/es: the recorded Childsplay clip, else TTS in that language.
    loadSound(`flashcards/${L.code}/${card.word}.ogg`).then((a) => {
      if (a && (a.duration > 0 || a.readyState >= 2)) playSound(`flashcards/${L.code}/${card.word}.ogg`, { channel: 'voice' });
      else say(card.word, { lang: L.bcp, rate: 0.82 });
    });
  }

  _go(delta) {
    this._i = (this._i + delta + DECK.length) % DECK.length;
    this._say();
  }

  pointermove() {}

  pointerup(x, y) {
    for (const b of [this._prevBtn, this._nextBtn, this._sayBtn, ...this._langBtns]) {
      if (!inRect(b, x, y)) continue;
      if (b.act === 'prev') this._go(-1);
      else if (b.act === 'next') this._go(1);
      else if (b.act === 'say') this._say();
      else if (b.act.startsWith('lang:')) { this._lang = +b.act.split(':')[1]; this._say(); }
      return;
    }
    // tapping the picture also speaks it
    if (inRect({ x: VIEW_W / 2 - 260, y: 90, w: 520, h: 380 }, x, y)) this._say();
  }

  keydown(e) {
    if (e.key === 'ArrowLeft') this._go(-1);
    else if (e.key === 'ArrowRight') this._go(1);
    else if (e.key === ' ' || e.key === 'Enter') this._say();
  }

  render(ctx) {
    ctx.fillStyle = '#1b2333';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    // card
    const cw = 520, ch = 470, cx = VIEW_W / 2 - cw / 2, cyy = 78;
    roundRect(ctx, cx, cyy, cw, ch, 28);
    ctx.fillStyle = '#eef2f7';
    ctx.fill();

    const card = DECK[this._i];
    drawImageFit(ctx, img(card.img), cx + 30, cyy + 26, cw - 60, ch - 150);

    ctx.fillStyle = '#1b2333';
    ctx.font = '700 62px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(card.word, VIEW_W / 2, cyy + ch - 62);

    // nav arrows
    for (const [b, glyph] of [[this._prevBtn, '‹'], [this._nextBtn, '›']]) {
      roundRect(ctx, b.x, b.y, b.w, b.h, 16);
      ctx.fillStyle = '#2b3856';
      ctx.fill();
      ctx.fillStyle = '#eef2f7';
      ctx.font = '700 80px system-ui, sans-serif';
      ctx.fillText(glyph, b.x + b.w / 2, b.y + b.h / 2);
    }

    // speak button
    const sb = this._sayBtn;
    roundRect(ctx, sb.x, sb.y, sb.w, sb.h, 16);
    ctx.fillStyle = '#4c7dff';
    ctx.fill();
    ctx.fillStyle = '#fff';
    ctx.font = '600 26px system-ui, sans-serif';
    ctx.fillText('🔊  say it', sb.x + sb.w / 2, sb.y + sb.h / 2 + 1);

    // language chips
    this._langBtns.forEach((b, k) => {
      roundRect(ctx, b.x, b.y, b.w, b.h, 12);
      ctx.fillStyle = k === this._lang ? '#4c7dff' : '#2b3856';
      ctx.fill();
      ctx.fillStyle = '#fff';
      ctx.font = '600 20px system-ui, sans-serif';
      ctx.fillText(b.label, b.x + b.w / 2, b.y + b.h / 2 + 1);
    });

    // progress dots
    const dots = DECK.length, dw = 16;
    for (let k = 0; k < dots; k++) {
      ctx.beginPath();
      ctx.arc(VIEW_W / 2 - (dots * dw) / 2 + k * dw + dw / 2, VIEW_H - 44, 5, 0, Math.PI * 2);
      ctx.fillStyle = k === this._i ? '#ffd93d' : 'rgba(255,255,255,0.28)';
      ctx.fill();
    }

    ctx.fillStyle = '#9fb4d8';
    ctx.font = '500 20px system-ui, sans-serif';
    ctx.fillText('tap the picture or "say it" to hear the word', VIEW_W / 2, 52);
  }
}
