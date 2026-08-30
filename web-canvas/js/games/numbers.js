// numbers.js — the counting-order memory game. Numbered tiles are
// scattered on the board; study them, press Start, they go blank, then tap
// them in order 1, 2, 3 … from memory. A wrong tap flashes red and peeks
// the whole board for a moment — no progress lost. Six levels, 4 → 9 tiles.

import { Scene, VIEW_W, VIEW_H, playSound } from '../engine.js';
import { clamp, rand, roundRect, shuffle, Overlay, buttonRow, hudSpeakButton, hudSpeakHit, speakHud } from '../util.js';

const HUD = 64;
const R = 42;                       // tile radius

const SND_START = 'sfx/pick.wav';
const SND_GOOD = 'sfx/good.ogg';
const SND_WRONG = 'sfx/wrong.ogg';
const SND_WIN = 'sfx/winner.ogg';

export default class NumbersGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._overlay = new Overlay();
    this._level = 0;
    this._startLevel(0);
  }

  _count() { return 4 + this._level; }      // 4 … 9

  _startLevel(n) {
    this._level = clamp(n, 0, 5);
    this._overlay.hide();
    this._newBoard();
  }

  _newBoard() {
    const count = this._count();
    // scatter non-overlapping normalised positions (0..1 inside the play box)
    const pts = [];
    let guard = 0;
    while (pts.length < count && guard++ < 4000) {
      const p = { nx: rand(0.06, 0.94), ny: rand(0.08, 0.92) };
      if (pts.some((q) => (q.nx - p.nx) ** 2 + (q.ny - p.ny) ** 2 < 0.02)) continue;
      pts.push(p);
    }
    while (pts.length < count) pts.push({ nx: rand(0.06, 0.94), ny: rand(0.08, 0.92) });
    shuffle(pts);
    this._tiles = pts.map((p, i) => ({ n: i + 1, nx: p.nx, ny: p.ny, flash: 0, lit: false }));

    this._phase = 'study';           // study | play | peek
    this._next = 1;                  // next number to tap
    this._peek = 0;
    this._geo();
  }

  _geo() {
    this._box = { x: 60, y: HUD + 34, w: VIEW_W - 120, h: VIEW_H - HUD - 34 - 110 };
    this._startBtn = { x: VIEW_W / 2 - 110, y: VIEW_H - 84, w: 220, h: 60 };
  }

  resize() {
    this._geo();
    this._overlay.reflow(VIEW_W / 2, VIEW_H / 2 + 20);
  }

  _pos(t) {
    const b = this._box;
    return {
      x: b.x + R + t.nx * (b.w - 2 * R),
      y: b.y + R + t.ny * (b.h - 2 * R),
    };
  }

  _begin() {
    if (this._phase !== 'study') return;
    playSound(SND_START);
    this._phase = 'play';
  }

  update(dt) {
    for (const t of this._tiles) if (t.flash > 0) t.flash = Math.max(0, t.flash - dt);
    if (this._peek > 0) {
      this._peek -= dt;
      if (this._peek <= 0 && this._phase === 'peek') this._phase = 'play';
    }
  }

  pointerup(x, y) {
    if (hudSpeakHit(x, y)) return speakHud();
    if (this._overlay.visible) {
      const act = this._overlay.pointerup(x, y);
      if (act === 'next') this._startLevel(this._level + 1);
      else if (act === 'replay') this._startLevel(this._level);
      else if (act === 'menu') this._exit();
      return;
    }

    if (this._phase === 'study') {
      if (x >= this._startBtn.x && x <= this._startBtn.x + this._startBtn.w &&
          y >= this._startBtn.y && y <= this._startBtn.y + this._startBtn.h) this._begin();
      return;
    }
    if (this._phase !== 'play') return;

    const hit = this._tiles.find((t) => {
      const p = this._pos(t);
      return (p.x - x) ** 2 + (p.y - y) ** 2 <= R * R;
    });
    if (!hit || hit.lit) return;

    if (hit.n === this._next) {
      hit.lit = true;
      hit.flash = 0.4;
      playSound(SND_GOOD, { volume: 0.6 });
      this._next += 1;
      if (this._next > this._count()) this._levelDone();
    } else {
      hit.flash = 0.6;
      playSound(SND_WRONG);
      this._phase = 'peek';
      this._peek = 1.2;               // reveal everything briefly
    }
  }

  _levelDone() {
    const last = this._level >= 5;
    if (last) {
      playSound(SND_WIN, { channel: 'music' });
      this._overlay.show('You found every number!',
        buttonRow([['Play Again', 'replay'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20));
    } else {
      playSound(SND_WIN, { volume: 0.6, channel: 'music' });
      this._overlay.show(`Level ${this._level + 1} done!`,
        buttonRow([['Next Level', 'next'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20));
    }
  }

  render(ctx) {
    ctx.fillStyle = '#141b26';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    const showNums = this._phase === 'study' || this._phase === 'peek';

    for (const t of this._tiles) {
      const p = this._pos(t);
      const flashing = t.flash > 0;
      const reveal = showNums || t.lit;
      let fill = '#2b3856';
      if (t.lit) fill = '#26402c';
      if (flashing) fill = t.lit ? '#2e6b3a' : '#5b2b2b';
      ctx.beginPath();
      ctx.arc(p.x, p.y, R, 0, Math.PI * 2);
      ctx.fillStyle = fill;
      ctx.fill();
      ctx.lineWidth = 3;
      ctx.strokeStyle = t.lit ? '#7be0a0' : 'rgba(255,255,255,0.18)';
      ctx.stroke();

      ctx.fillStyle = reveal ? '#eef2f7' : 'rgba(255,255,255,0.28)';
      ctx.font = `700 ${reveal ? 34 : 30}px system-ui, sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(reveal ? String(t.n) : '?', p.x, p.y + 1);
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
    const got = Math.min(this._next - 1, this._count());
    ctx.fillText(`L${this._level + 1}/6   ·   ${got}/${this._count()}`, 24, HUD / 2);
    ctx.textAlign = 'center';
    ctx.fillStyle = '#9fb4d8';
    const msg = this._phase === 'study' ? 'remember where the numbers are, then press Start'
      : this._phase === 'peek' ? 'take another look'
      : `tap number ${this._next}`;
    ctx.fillText(msg, VIEW_W / 2, HUD / 2);
    hudSpeakButton(ctx, msg, VIEW_W / 2, HUD / 2);

    this._overlay.render(ctx, VIEW_W, VIEW_H);
  }
}
