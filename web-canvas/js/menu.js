// menu.js — the MainMenu state: a kiosk grid of big icon tiles.

import { Scene, VIEW_W, VIEW_H, img } from './engine.js';
import { MENU } from './games/index.js';
import { roundRect, drawImageFit, inRect } from './util.js';

const PAD = 64;
const TITLE_H = 150;
const GAP = 36;

export class MainMenu extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._onSelect = opts.onSelect || (() => {});
    this._tiles = [];
    this._hover = -1;
    this._press = -1;
    this._t = 0;
  }

  enter() {
    this._layout();
  }

  resize() {
    this._layout();
  }

  _layout() {
    const cols = MENU.length <= 3 ? MENU.length : MENU.length <= 8 ? 3 : 4;
    const rows = Math.ceil(MENU.length / cols);
    const availW = VIEW_W - PAD * 2;
    const availH = VIEW_H - TITLE_H - PAD;
    const tileW = (availW - GAP * (cols - 1)) / cols;
    const tileH = Math.min(tileW * 0.82, (availH - GAP * (rows - 1)) / rows);
    const gridW = cols * tileW + (cols - 1) * GAP;
    const gridH = rows * tileH + (rows - 1) * GAP;
    const sx = (VIEW_W - gridW) / 2;
    const sy = TITLE_H + (availH - gridH) / 2;

    this._tiles = MENU.map((g, i) => ({
      game: g,
      x: sx + (i % cols) * (tileW + GAP),
      y: sy + Math.floor(i / cols) * (tileH + GAP),
      w: tileW,
      h: tileH,
    }));
  }

  update(dt) {
    this._t += dt;
  }

  _hit(x, y) {
    return this._tiles.findIndex((t) => inRect(t, x, y));
  }

  pointermove(x, y) { this._hover = this._hit(x, y); }
  pointerdown(x, y) { this._press = this._hit(x, y); }

  pointerup(x, y) {
    const i = this._hit(x, y);
    if (i >= 0 && i === this._press) this._onSelect(this._tiles[i].game.id);
    this._press = -1;
  }

  render(ctx) {
    ctx.fillStyle = '#1b2333';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = '#eef2f7';
    ctx.font = '700 60px system-ui, "Segoe UI", Roboto, sans-serif';
    ctx.fillText('Childsplay', VIEW_W / 2, TITLE_H / 2 - 4);
    ctx.fillStyle = '#9fb4d8';
    ctx.font = '400 24px system-ui, sans-serif';
    ctx.fillText('pick a game', VIEW_W / 2, TITLE_H / 2 + 40);

    this._tiles.forEach((t, i) => {
      const pressed = i === this._press;
      const hovered = i === this._hover && !pressed;
      const k = pressed ? 4 : 0;

      roundRect(ctx, t.x + k, t.y + k, t.w - k * 2, t.h - k * 2, 24);
      ctx.fillStyle = pressed ? '#3a63d0' : hovered ? '#41567d' : '#2b3856';
      ctx.fill();

      const box = Math.min(t.w, t.h) * 0.52;
      const icon = img(t.game.icon);
      if (icon && icon.naturalWidth) {
        drawImageFit(ctx, icon, t.x + t.w / 2 - box / 2, t.y + t.h * 0.14, box, box);
      } else {
        ctx.fillStyle = '#5a6f9c';
        roundRect(ctx, t.x + t.w / 2 - box / 2, t.y + t.h * 0.14, box, box, 16);
        ctx.fill();
      }

      ctx.fillStyle = '#ffffff';
      ctx.font = `600 ${Math.round(t.h * 0.16)}px system-ui, sans-serif`;
      ctx.fillText(t.game.name, t.x + t.w / 2, t.y + t.h - t.h * 0.16);
    });
  }
}
