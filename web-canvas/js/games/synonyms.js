// synonyms.js — "Word Maker" (legacy `synonyms`, adapted for young English
// readers). You are given a starting letter; tap the on-screen keyboard
// (or type) to build words that begin with it. Real words from the built-in
// list score; find enough to clear the level. Five letters, 2 → 6 words.

import { Scene, VIEW_W, VIEW_H, playSound } from '../engine.js';
import { clamp, roundRect, inRect, Overlay, buttonRow } from '../util.js';

const HUD = 56;

// small, kid-friendly word list grouped by the five level letters
const WORDS = new Set([
  // s
  'sun', 'sit', 'sad', 'sea', 'see', 'sock', 'sing', 'snake', 'star', 'stop',
  'six', 'sky', 'soap', 'soup', 'sand', 'seed', 'ship', 'shop', 'snow', 'spin',
  'swim', 'sheep', 'spider', 'sock', 'seal', 'sock', 'song', 'sofa',
  // b
  'bat', 'bad', 'bed', 'bee', 'big', 'bus', 'bug', 'box', 'boy', 'bird',
  'blue', 'boat', 'book', 'ball', 'bell', 'bear', 'bone', 'bump', 'band', 'barn',
  'best', 'bath', 'bake', 'bread', 'brush', 'brown',
  // c
  'cat', 'cap', 'car', 'cow', 'cub', 'cup', 'can', 'cot', 'cake', 'corn',
  'coat', 'cave', 'coin', 'cold', 'clap', 'club', 'crab', 'crow', 'cube', 'camp',
  'card', 'care', 'cart', 'clock', 'cloud', 'chair',
  // t
  'top', 'tap', 'ten', 'toe', 'tub', 'tan', 'tag', 'tin', 'toy', 'tree',
  'time', 'town', 'tail', 'tape', 'team', 'tent', 'test', 'tick', 'tide', 'tiny',
  'toad', 'tool', 'tour', 'trap', 'train', 'truck',
  // p
  'pan', 'pen', 'pig', 'pit', 'pot', 'pup', 'pat', 'paw', 'pin', 'park',
  'pink', 'play', 'plum', 'pond', 'pool', 'pull', 'push', 'pear', 'peas', 'plan',
  'plus', 'prize', 'print', 'path', 'plane', 'plant',
]);

const LEVELS = [
  { letter: 's', target: 2 },
  { letter: 'b', target: 3 },
  { letter: 'c', target: 4 },
  { letter: 't', target: 4 },
  { letter: 'p', target: 5 },
];

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
    this._level = 0;
    this._startLevel(0);
  }

  _startLevel(n) {
    this._level = clamp(n, 0, LEVELS.length - 1);
    this._word = '';
    this._found = [];
    this._shake = 0;
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

  _submit() {
    if (this._overlay.visible) return;
    const w = this._word.toLowerCase();
    const lv = LEVELS[this._level];
    const okWord = w.length >= 3 && w[0] === lv.letter && WORDS.has(w) && !this._found.includes(w);
    if (okWord) {
      this._found.push(w);
      this._word = '';
      playSound(SND_GOOD);
      if (this._found.length >= lv.target) this._levelDone();
    } else {
      this._shake = 0.4;
      playSound(SND_WRONG);
      this._word = '';
    }
  }

  _levelDone() {
    const last = this._level >= LEVELS.length - 1;
    if (last) {
      playSound(SND_WIN);
      this._overlay.show('You are a word maker!',
        buttonRow([['Play Again', 'replay'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20));
    } else {
      playSound(SND_WIN, { volume: 0.6 });
      this._overlay.show(`Level ${this._level + 1} done!`,
        buttonRow([['Next Level', 'next'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20));
    }
  }

  update(dt) {
    if (this._shake > 0) this._shake = Math.max(0, this._shake - dt);
  }

  keydown(e) {
    if (this._overlay.visible) return;
    if (e.key === 'Backspace') { this._backspace(); e.preventDefault?.(); }
    else if (e.key === 'Enter' || e.key === ' ') { this._submit(); e.preventDefault?.(); }
    else if (/^[a-zA-Z]$/.test(e.key)) this._type(e.key);
  }

  pointerup(x, y) {
    if (this._overlay.visible) {
      const act = this._overlay.pointerup(x, y);
      if (act === 'next') this._startLevel(this._level + 1);
      else if (act === 'replay') this._startLevel(this._level);
      else if (act === 'menu') this._exit();
      return;
    }
    if (inRect(this._delKey, x, y)) return this._backspace();
    if (inRect(this._okKey, x, y)) return this._submit();
    const k = this._keys.find((kk) => inRect(kk, x, y));
    if (k) this._type(k.ch);
  }

  render(ctx) {
    ctx.fillStyle = '#141b26';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    const lv = LEVELS[this._level];

    // prompt + word tray
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = '#9fb4d8';
    ctx.font = '600 26px system-ui, sans-serif';
    ctx.fillText(`make words that start with  “${lv.letter.toUpperCase()}”`, VIEW_W / 2, HUD + 46);

    const trayW = Math.min(560, VIEW_W - 120);
    const trayX = VIEW_W / 2 - trayW / 2;
    const trayY = HUD + 76;
    const sh = this._shake > 0 ? Math.sin(this._shake * 60) * 6 : 0;
    roundRect(ctx, trayX + sh, trayY, trayW, 74, 14);
    ctx.fillStyle = this._shake > 0 ? '#5b2b2b' : '#232f45';
    ctx.fill();
    ctx.fillStyle = '#eef2f7';
    ctx.font = '700 44px ui-monospace, monospace';
    ctx.fillText(this._word.toUpperCase() || '…', VIEW_W / 2 + sh, trayY + 38);

    // found words
    ctx.font = '600 22px system-ui, sans-serif';
    ctx.fillStyle = '#7be0a0';
    this._found.forEach((w, i) => {
      ctx.fillText(w, VIEW_W / 2, trayY + 100 + i * 30);
    });
    ctx.fillStyle = '#9fb4d8';
    ctx.font = '500 18px system-ui, sans-serif';
    ctx.fillText(`${this._found.length} / ${lv.target}`, VIEW_W / 2, trayY + 100 + this._found.length * 30 + 6);

    // keyboard
    const drawKey = (k, big) => {
      roundRect(ctx, k.x, k.y, k.w, k.h, 10);
      ctx.fillStyle = '#2b3856';
      ctx.fill();
      ctx.fillStyle = '#eef2f7';
      ctx.font = `600 ${big ? 22 : 26}px system-ui, sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(k.label || k.ch, k.x + k.w / 2, k.y + k.h / 2 + 1);
    };
    for (const k of this._keys) drawKey(k, false);
    drawKey(this._delKey, true);
    drawKey(this._okKey, true);

    // HUD
    ctx.fillStyle = 'rgba(16,21,32,0.6)';
    ctx.fillRect(0, 0, VIEW_W, HUD);
    ctx.fillStyle = '#eef2f7';
    ctx.font = '600 22px system-ui, sans-serif';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    ctx.fillText(`Level ${this._level + 1}/${LEVELS.length}   ·   ${this._found.length}/${lv.target} words`, 200, HUD / 2);
    ctx.textAlign = 'center';
    ctx.fillStyle = '#9fb4d8';
    ctx.fillText('tap letters, then Enter', VIEW_W / 2, HUD / 2);

    this._overlay.render(ctx, VIEW_W, VIEW_H);
  }
}
