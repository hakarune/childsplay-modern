// memory-menu.js — the "Memory" tile opens this: a picker for the memory
// variants. Picking one hands the id + options back to main.js's launcher.
//
//   Pictures / lowercase / UPPERCASE / Numbers  -> memory.js (variant)
//   Sounds                                       -> soundmemory.js

import { Scene, VIEW_W, VIEW_H } from '../engine.js';
import { roundRect, inRect } from '../util.js';

const TITLE_H = 150;
const PAD = 70;
const GAP = 32;

const VARIANTS = [
  { key: 'pictures', label: 'Pictures', sample: '🐾', game: 'memory', opts: { variant: 'pictures' } },
  { key: 'lower',    label: 'lowercase', sample: 'a b', game: 'memory', opts: { variant: 'lower' } },
  { key: 'upper',    label: 'UPPERCASE', sample: 'A B', game: 'memory', opts: { variant: 'upper' } },
  { key: 'numbers',  label: 'Numbers',   sample: '1 2', game: 'memory', opts: { variant: 'numbers' } },
  { key: 'sounds',   label: 'Sounds',    sample: '♪',   game: 'soundmemory', opts: {} },
];

export class MemoryMenu extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._onPick = opts.onPick || (() => {});
    this._tiles = [];
    this._hover = -1;
    this._press = -1;
  }

  enter() { this._layout(); }
  resize() { this._layout(); }

  _layout() {
    const cols = 3;
    const rows = Math.ceil(VARIANTS.length / cols);
    const availW = VIEW_W - PAD * 2;
    const availH = VIEW_H - TITLE_H - PAD;
    const tw = (availW - GAP * (cols - 1)) / cols;
    const th = Math.min(tw * 0.78, (availH - GAP * (rows - 1)) / rows);
    const gridW = cols * tw + (cols - 1) * GAP;
    const gridH = rows * th + (rows - 1) * GAP;
    const sx = (VIEW_W - gridW) / 2;
    const sy = TITLE_H + (availH - gridH) / 2;

    this._tiles = VARIANTS.map((v, i) => ({
      v,
      x: sx + (i % cols) * (tw + GAP),
      y: sy + Math.floor(i / cols) * (th + GAP),
      w: tw,
      h: th,
    }));
  }

  _hit(x, y) { return this._tiles.findIndex((t) => inRect(t, x, y)); }

  pointermove(x, y) { this._hover = this._hit(x, y); }
  pointerdown(x, y) { this._press = this._hit(x, y); }

  pointerup(x, y) {
    const i = this._hit(x, y);
    if (i >= 0 && i === this._press) {
      const v = this._tiles[i].v;
      this._onPick(v.game, v.opts);
    }
    this._press = -1;
  }

  render(ctx) {
    ctx.fillStyle = '#1b2333';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = '#eef2f7';
    ctx.font = '700 56px system-ui, sans-serif';
    ctx.fillText('Memory Games', VIEW_W / 2, TITLE_H / 2 - 4);
    ctx.fillStyle = '#9fb4d8';
    ctx.font = '400 24px system-ui, sans-serif';
    ctx.fillText('pick a deck', VIEW_W / 2, TITLE_H / 2 + 40);

    this._tiles.forEach((t, i) => {
      const pressed = i === this._press;
      const hovered = i === this._hover && !pressed;
      const k = pressed ? 4 : 0;
      roundRect(ctx, t.x + k, t.y + k, t.w - k * 2, t.h - k * 2, 24);
      ctx.fillStyle = pressed ? '#3a63d0' : hovered ? '#41567d' : '#2b3856';
      ctx.fill();

      ctx.fillStyle = '#dfe8ff';
      ctx.font = `700 ${Math.round(t.h * 0.34)}px system-ui, sans-serif`;
      ctx.fillText(t.v.sample, t.x + t.w / 2, t.y + t.h * 0.42);

      ctx.fillStyle = '#ffffff';
      ctx.font = `600 ${Math.round(t.h * 0.15)}px system-ui, sans-serif`;
      ctx.fillText(t.v.label, t.x + t.w / 2, t.y + t.h - t.h * 0.16);
    });
  }
}
