// synonyms.js — "Word Maker" (legacy `synonyms`, adapted for young English
// readers). You are given a starting letter; tap the on-screen keyboard
// (or type) to build words that begin with it. Real words from a bundled
// ~1200-word kid dictionary (assets/data/wordlist.json) score. Each level
// gives you two hints. Five letters, 3 → 5 words.

import { Scene, VIEW_W, VIEW_H, playSound, assetURL } from '../engine.js';
import {
  clamp, roundRect, inRect, Overlay, buttonRow,
  hudSpeakButton, hudSpeakHit, speakHud,
} from '../util.js';
import { theme } from '../theme.js';
import { say } from '../tts.js';

const HUD = 56;

// Fallback if assets/data/wordlist.json can't be loaded.
const FALLBACK_WORDS = [
  'sun', 'sit', 'sea', 'six', 'sky', 'sock', 'sing', 'star', 'stop', 'snake', 'sheep', 'spider',
  'bat', 'bed', 'bee', 'big', 'bus', 'bug', 'box', 'boy', 'bird', 'blue', 'boat', 'book', 'ball', 'bear',
  'cat', 'cap', 'car', 'cow', 'cup', 'can', 'cake', 'coat', 'cave', 'clap', 'crab', 'clock', 'cloud',
  'top', 'tap', 'ten', 'toe', 'toy', 'tree', 'time', 'tail', 'tent', 'train', 'truck', 'tiger',
  'pan', 'pen', 'pig', 'pot', 'pup', 'pin', 'park', 'pink', 'play', 'pond', 'pear', 'plane', 'plant',
];

const LEVELS = [
  { letter: 's', target: 3 },
  { letter: 'b', target: 4 },
  { letter: 'c', target: 4 },
  { letter: 't', target: 5 },
  { letter: 'p', target: 5 },
];

const HINTS_PER_LEVEL = 2;
const KB_ROWS = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];

const SND_KEY = 'sfx/pick.wav';
const SND_GOOD = 'sfx/good.ogg';
const SND_WRONG = 'sfx/wrong.ogg';
const SND_WIN = 'sfx/winner.ogg';

export default class WordMakerGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._overlay = new Overlay();
    this._dict = new Set(FALLBACK_WORDS);
    this._level = 0;
    this._startLevel(0);
    this._loadDict();
  }

  _loadDict() {
    fetch(assetURL('data/wordlist.json'))
      .then((r) => (r.ok ? r.json() : null))
      .then((d) => {
        const words = d && Array.isArray(d.words) ? d.words : null;
        if (words && words.length) this._dict = new Set(words);
      })
      .catch(() => {});
  }

  enter() { this._announce(); }

  _announce() {
    const lv = LEVELS[this._level];
    say(`make words that start with ${lv.letter.toUpperCase()}`);
    setTimeout(() => say('tap letters, then Enter'), 1500);
  }

  _startLevel(n) {
    this._level = clamp(n, 0, LEVELS.length - 1);
    this._word = '';
    this._found = [];
    this._shake = 0;
    this._hintsLeft = HINTS_PER_LEVEL;
    this._hint = null;              // { word, t }
    this._overlay.hide();
    this._geo();
  }

  _geo() {
    const gap = 8;
    const kw = Math.min(96, (VIEW_W - 40 - 9 * gap) / 10);
    const kh = Math.min(64, kw * 0.9);
    const bottom = VIEW_H - 28;
    this._keys = [];
    KB_ROWS.forEach((row, r) => {
      const total = row.length * kw + (row.length - 1) * gap;
      const x0 = (VIEW_W - total) / 2;
      const y = bottom - (KB_ROWS.length + 1 - r) * (kh + gap);
      for (let i = 0; i < row.length; i++) {
        this._keys.push({ ch: row[i], x: x0 + i * (kw + gap), y, w: kw, h: kh });
      }
    });
    // action row: backspace + enter
    const ay = bottom - (kh + gap);
    const aw = (kw * 4 + gap * 3);
    this._delKey = { ch: '\b', label: '⌫', x: VIEW_W / 2 - aw - gap / 2, y: ay, w: aw, h: kh };
    this._okKey = { ch: '\n', label: 'Enter', x: VIEW_W / 2 + gap / 2, y: ay, w: aw, h: kh };
    this._kw = kw;
    // hint pill sits above the tray, right-aligned
    this._hintBtn = { x: VIEW_W / 2 + Math.min(280, VIEW_W / 2 - 60) - 150, y: HUD + 12, w: 150, h: 44 };
  }

  resize() {
    this._geo();
    this._overlay.reflow(VIEW_W / 2, VIEW_H / 2 + 20);
  }

  _type(ch) {
    if (this._overlay.visible) return;
    playSound(SND_KEY, { volume: 0.4 });
    if (this._word.length < 9) this._word += ch.toLowerCase();
  }

  _backspace() {
    if (this._overlay.visible) return;
    this._word = this._word.slice(0, -1);
  }

  _valid(w) {
    const lv = LEVELS[this._level];
    return w.length >= 3 && w[0] === lv.letter && this._dict.has(w);
  }

  _submit() {
    if (this._overlay.visible) return;
    const w = this._word.toLowerCase();
    if (this._valid(w) && !this._found.includes(w)) {
      this._found.push(w);
      this._word = '';
      playSound(SND_GOOD);
      say('that is a word');
      if (this._found.length >= LEVELS[this._level].target) this._levelDone();
    } else {
      this._shake = 0.4;
      playSound(SND_WRONG);
      if (w.length >= 3) say('not a word, try again');
      this._word = '';
    }
  }

  _useHint() {
    if (this._overlay.visible || this._hintsLeft <= 0) return;
    const lv = LEVELS[this._level];
    const pick = [];
    for (const w of this._dict) {
      if (w[0] === lv.letter && w.length >= 3 && w.length <= 6 && !this._found.includes(w)) pick.push(w);
    }
    if (!pick.length) return;
    const word = pick[(Math.random() * pick.length) | 0];
    this._hint = { word, t: 0 };
    this._hintsLeft -= 1;
    say('here is a word you could make');
    setTimeout(() => say(word), 1400);
  }

  _levelDone() {
    const last = this._level >= LEVELS.length - 1;
    if (last) {
      playSound(SND_WIN, { channel: 'music' });
      this._overlay.show('You are a word maker!',
        buttonRow([['Play Again', 'replay'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20));
    } else {
      playSound(SND_WIN, { volume: 0.6, channel: 'music' });
      this._overlay.show(`Level ${this._level + 1} done!`,
        buttonRow([['Next Level', 'next'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20));
    }
  }

  update(dt) {
    if (this._shake > 0) this._shake = Math.max(0, this._shake - dt);
    if (this._hint) { this._hint.t += dt; if (this._hint.t > 4.5) this._hint = null; }
  }

  keydown(e) {
    if (this._overlay.visible) return;
    if (e.key === 'Backspace') { this._backspace(); e.preventDefault?.(); }
    else if (e.key === 'Enter' || e.key === ' ') { this._submit(); e.preventDefault?.(); }
    else if (/^[a-zA-Z]$/.test(e.key)) this._type(e.key);
  }

  pointerup(x, y) {
    if (hudSpeakHit(x, y)) return speakHud();
    if (this._overlay.visible) {
      const act = this._overlay.pointerup(x, y);
      if (act === 'next') { this._startLevel(this._level + 1); this._announce(); }
      else if (act === 'replay') { this._startLevel(this._level); this._announce(); }
      else if (act === 'menu') this._exit();
      return;
    }
    if (inRect(this._hintBtn, x, y)) return this._useHint();
    if (inRect(this._delKey, x, y)) return this._backspace();
    if (inRect(this._okKey, x, y)) return this._submit();
    const k = this._keys.find((kk) => inRect(kk, x, y));
    if (k) this._type(k.ch);
  }

  render(ctx) {
    ctx.fillStyle = theme.bg;
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    const lv = LEVELS[this._level];

    // prompt + word tray
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = theme.text_muted;
    ctx.font = '600 26px system-ui, sans-serif';
    ctx.fillText(`make words that start with  “${lv.letter.toUpperCase()}”`, VIEW_W / 2, HUD + 46);

    const trayW = Math.min(560, VIEW_W - 120);
    const trayX = VIEW_W / 2 - trayW / 2;
    const trayY = HUD + 76;
    const sh = this._shake > 0 ? Math.sin(this._shake * 60) * 6 : 0;
    roundRect(ctx, trayX + sh, trayY, trayW, 74, 14);
    ctx.fillStyle = theme.surface;
    ctx.fill();
    if (this._shake > 0) {
      ctx.strokeStyle = theme.bad;
      ctx.lineWidth = 4;
      ctx.stroke();
    }
    ctx.fillStyle = theme.text;
    ctx.font = '700 44px ui-monospace, monospace';
    ctx.fillText(this._word.toUpperCase() || '…', VIEW_W / 2 + sh, trayY + 38);

    // hint pill
    const hb = this._hintBtn;
    roundRect(ctx, hb.x, hb.y, hb.w, hb.h, 12);
    ctx.fillStyle = this._hintsLeft > 0 ? theme.accent : theme.surface;
    ctx.fill();
    ctx.fillStyle = this._hintsLeft > 0 ? '#fff' : theme.text_muted;
    ctx.font = '600 20px system-ui, sans-serif';
    ctx.fillText(`Hint (${this._hintsLeft})`, hb.x + hb.w / 2, hb.y + hb.h / 2 + 1);

    // active hint
    if (this._hint) {
      const a = clamp(1 - (this._hint.t - 3) / 1.5, 0, 1);
      ctx.globalAlpha = a;
      roundRect(ctx, VIEW_W / 2 - 180, trayY + 84, 360, 44, 12);
      ctx.fillStyle = theme.warn;
      ctx.fill();
      ctx.fillStyle = theme.card_ink;
      ctx.font = '700 24px system-ui, sans-serif';
      ctx.fillText(`try:  ${this._hint.word.toUpperCase()}`, VIEW_W / 2, trayY + 106);
      ctx.globalAlpha = 1;
    }

    // found words
    ctx.font = '600 22px system-ui, sans-serif';
    ctx.fillStyle = theme.good;
    this._found.forEach((w, i) => {
      ctx.fillText(w, VIEW_W / 2, trayY + 146 + i * 30);
    });
    ctx.fillStyle = theme.text_muted;
    ctx.font = '500 18px system-ui, sans-serif';
    ctx.fillText(`${this._found.length} / ${lv.target}`, VIEW_W / 2, trayY + 146 + this._found.length * 30 + 6);

    // keyboard
    const drawKey = (k, big) => {
      roundRect(ctx, k.x, k.y, k.w, k.h, 10);
      ctx.fillStyle = theme.surface;
      ctx.fill();
      ctx.fillStyle = theme.text;
      ctx.font = `600 ${big ? 22 : 26}px system-ui, sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(k.label || k.ch, k.x + k.w / 2, k.y + k.h / 2 + 1);
    };
    for (const k of this._keys) drawKey(k, false);
    drawKey(this._delKey, true);
    drawKey(this._okKey, true);

    // HUD
    ctx.fillStyle = theme.hud;
    ctx.fillRect(0, 0, VIEW_W, HUD);
    ctx.fillStyle = theme.line;
    ctx.fillRect(0, HUD - 1, VIEW_W, 1);
    ctx.fillStyle = theme.hud_text;
    ctx.font = '600 22px system-ui, sans-serif';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    ctx.fillText(`Level ${this._level + 1}/${LEVELS.length}   ·   ${this._found.length}/${lv.target} words`, 200, HUD / 2);
    ctx.textAlign = 'center';
    ctx.fillStyle = theme.hud_muted;
    ctx.fillText('tap letters, then Enter', VIEW_W / 2, HUD / 2);
    hudSpeakButton(ctx, `make words that start with ${lv.letter.toUpperCase()}`, VIEW_W / 2, HUD / 2);

    this._overlay.render(ctx, VIEW_W, VIEW_H);
  }
}
