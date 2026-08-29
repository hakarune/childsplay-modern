// ichanger.js — Image Changer. Study the row of pictures, press Start, the
// cards flip down and back — and one picture has changed. Tap the card
// that changed. Four levels: 3 cards, 3 cards + shuffle, 4 cards, 4 cards
// + shuffle. Three rounds per level.

import { Scene, VIEW_W, VIEW_H, img, loadImage, playSound } from '../engine.js';
import { clamp, roundRect, shuffle, inRect, Overlay, buttonRow } from '../util.js';

const HUD = 56;
const ROUNDS = 3;

const LEVELS = [
  { cards: 3, shuffle: false },
  { cards: 3, shuffle: true },
  { cards: 4, shuffle: false },
  { cards: 4, shuffle: true },
];

const DECK = [
  '01_cat', '02_pig', '03_bear', '04_hippopotamus', '05_penguin', '06_cow',
  '07_sheep', '08_turtle', '09_panda', '10_chicken', '11_redbird', '12_wolf',
  '13_monkey', '14_fox', '16_elephant', '17_lion', '21_frog',
];
const src = (id) => `memory/${id}.png`;

const SND_FLIP = 'sfx/dealcard1.wav';
const SND_START = 'sfx/pick.wav';
const SND_GOOD = 'sfx/good.ogg';
const SND_WRONG = 'sfx/wrong.ogg';
const SND_WIN = 'sfx/winner.ogg';

export default class ImageChangerGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._overlay = new Overlay();
    this._level = 0;
    this._startLevel(0);
  }

  _startLevel(n) {
    this._level = clamp(n, 0, LEVELS.length - 1);
    this._round = 0;
    this._overlay.hide();
    this._newRound();
  }

  _newRound() {
    const lv = LEVELS[this._level];
    const ids = shuffle(DECK.slice()).slice(0, lv.cards);
    for (const id of ids) loadImage(src(id));
    this._cards = ids.map((id) => ({ id, flip: 0, changed: false, wrong: 0, right: 0 }));
    this._phase = 'study';
    this._t = 0;
    this._changed = false;
    this._changedId = null;
    this._resultAdvance = null;
    this._geo();
  }

  _geo() {
    const n = this._cards ? this._cards.length : 3;
    const gap = 26;
    const cw = clamp((VIEW_W - 120 - gap * (n - 1)) / n, 120, 260);
    const ch = Math.min(cw * 1.32, VIEW_H - HUD - 190);
    const totalW = n * cw + gap * (n - 1);
    const x0 = (VIEW_W - totalW) / 2;
    const y0 = HUD + 40 + (VIEW_H - HUD - 40 - ch - 90) / 2;
    this._cards.forEach((c, i) => {
      c.x = x0 + i * (cw + gap);
      c.y = y0;
      c.w = cw;
      c.h = ch;
    });
    this._startBtn = { x: VIEW_W / 2 - 110, y: y0 + ch + 34, w: 220, h: 62 };
  }

  resize() {
    if (this._cards) this._geo();
    this._overlay.reflow(VIEW_W / 2, VIEW_H / 2 + 20);
  }

  _begin() {
    if (this._phase !== 'study') return;
    playSound(SND_START);
    this._phase = 'hide';
    this._t = 0;
  }

  _applyChange() {
    const lv = LEVELS[this._level];
    if (lv.shuffle) shuffle(this._cards);
    const used = new Set(this._cards.map((c) => c.id));
    const fresh = DECK.filter((id) => !used.has(id));
    const nid = fresh[(Math.random() * fresh.length) | 0];
    const target = this._cards[(Math.random() * this._cards.length) | 0];
    target.id = nid;
    target.changed = true;
    this._changedId = target;
    loadImage(src(nid));
    this._geo();                    // re-place after a possible shuffle
  }

  update(dt) {
    this._t += dt;
    for (const c of this._cards) {
      if (c.wrong > 0) c.wrong = Math.max(0, c.wrong - dt);
      if (c.right > 0) c.right = Math.max(0, c.right - dt);
    }

    if (this._resultAdvance != null) {
      this._resultAdvance -= dt;
      if (this._resultAdvance <= 0) {
        this._resultAdvance = null;
        if (this._round >= ROUNDS) this._levelDone();
        else { this._changed = false; this._newRound(); }
      }
    }

    if (this._phase === 'hide') {
      const f = clamp(this._t / 0.5, 0, 1);
      for (const c of this._cards) c.flip = f;
      if (this._t > 0.5 && !this._changed) {
        this._changed = true;
        this._applyChange();
      }
      if (this._t > 1.1) { this._phase = 'reveal'; this._t = 0; }
    } else if (this._phase === 'reveal') {
      const f = clamp(1 - this._t / 0.5, 0, 1);
      for (const c of this._cards) c.flip = f;
      if (this._t > 0.55) { this._phase = 'guess'; for (const c of this._cards) c.flip = 0; }
    }
  }

  pointerup(x, y) {
    if (this._overlay.visible) {
      const act = this._overlay.pointerup(x, y);
      if (act === 'next') this._startLevel(this._level + 1);
      else if (act === 'replay') this._startLevel(this._level);
      else if (act === 'menu') this._exit();
      return;
    }

    if (this._phase === 'study') {
      if (inRect(this._startBtn, x, y)) this._begin();
      return;
    }
    if (this._phase !== 'guess') return;

    const hit = this._cards.find((c) => inRect(c, x, y));
    if (!hit) return;

    if (hit.changed) {
      hit.right = 1;
      playSound(SND_GOOD);
      this._phase = 'result';
      this._t = 0;
      this._round += 1;
      this._resultAdvance = 0.9;      // advanced in update()
    } else {
      hit.wrong = 0.6;
      playSound(SND_WRONG);
      // reveal the correct one
      if (this._changedId) this._changedId.right = 0.6;
    }
  }

  _levelDone() {
    const last = this._level >= LEVELS.length - 1;
    if (last) {
      playSound(SND_WIN, { channel: 'music' });
      this._overlay.show('You spotted every change!',
        buttonRow([['Play Again', 'replay'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20));
    } else {
      playSound(SND_WIN, { volume: 0.6, channel: 'music' });
      this._overlay.show(`Level ${this._level + 1} done!`,
        buttonRow([['Next Level', 'next'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20));
    }
  }

  render(ctx) {
    ctx.fillStyle = '#151b26';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    for (const c of this._cards) {
      const faceUp = c.flip < 0.5;
      const sx = Math.abs(1 - 2 * c.flip);       // horizontal squash for the flip
      const cx = c.x + c.w / 2;
      ctx.save();
      ctx.translate(cx, 0);
      ctx.scale(sx || 0.001, 1);
      ctx.translate(-cx, 0);

      roundRect(ctx, c.x, c.y, c.w, c.h, 16);
      ctx.fillStyle = faceUp ? '#eef2f7' : '#33507f';
      ctx.fill();

      if (faceUp) {
        const im = img(src(c.id));
        if (im && im.naturalWidth) {
          const pad = 14;
          const s = Math.min((c.w - pad * 2) / im.naturalWidth, (c.h - pad * 2) / im.naturalHeight);
          const dw = im.naturalWidth * s;
          const dh = im.naturalHeight * s;
          ctx.drawImage(im, cx - dw / 2, c.y + (c.h - dh) / 2, dw, dh);
        }
      } else {
        ctx.fillStyle = 'rgba(255,255,255,0.25)';
        ctx.font = '700 40px system-ui, sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('?', cx, c.y + c.h / 2);
      }

      if (c.wrong > 0) {
        ctx.strokeStyle = `rgba(255,90,90,${clamp(c.wrong / 0.6, 0, 1)})`;
        ctx.lineWidth = 6;
        roundRect(ctx, c.x + 3, c.y + 3, c.w - 6, c.h - 6, 14);
        ctx.stroke();
      }
      if (c.right > 0) {
        ctx.strokeStyle = `rgba(123,224,160,${clamp(c.right, 0, 1)})`;
        ctx.lineWidth = 7;
        roundRect(ctx, c.x + 3, c.y + 3, c.w - 6, c.h - 6, 14);
        ctx.stroke();
      }
      ctx.restore();
    }

    if (this._phase === 'study' && !this._overlay.visible) {
      const b = this._startBtn;
      ctx.fillStyle = '#4c7dff';
      roundRect(ctx, b.x, b.y, b.w, b.h, 14);
      ctx.fill();
      ctx.fillStyle = '#fff';
      ctx.font = '700 26px system-ui, sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('Start', b.x + b.w / 2, b.y + b.h / 2 + 1);
    }

    // HUD
    ctx.fillStyle = 'rgba(16,21,32,0.6)';
    ctx.fillRect(0, 0, VIEW_W, HUD);
    ctx.fillStyle = '#eef2f7';
    ctx.font = '600 22px system-ui, sans-serif';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    ctx.fillText(`Level ${this._level + 1}/${LEVELS.length}   ·   round ${Math.min(this._round + 1, ROUNDS)}/${ROUNDS}`, 200, HUD / 2);
    ctx.textAlign = 'center';
    ctx.fillStyle = '#9fb4d8';
    const msg = this._phase === 'study' ? 'remember the pictures, then press Start'
      : this._phase === 'guess' ? 'which picture changed?'
      : this._phase === 'result' ? 'nice!'
      : 'watch closely…';
    ctx.fillText(msg, VIEW_W / 2, HUD / 2);

    this._overlay.render(ctx, VIEW_W, VIEW_H);
  }
}
