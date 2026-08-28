// menu.js — the main dashboard scene.
//
// Draws a tile per activity from the minigame registry and reports the
// chosen id back through the onSelect callback supplied by main.js.

import { Scene, VIEW_W, VIEW_H } from './engine.js';
import { MINIGAMES } from './minigames/index.js';

const COLS = 3;
const TILE_W = 320;
const TILE_H = 180;
const GAP = 40;

export class MenuScene extends Scene {
  constructor({ onSelect }) {
    super();
    this._onSelect = onSelect;
    this._tiles = [];
    this._hover = -1;
  }

  enter() {
    const rows = Math.ceil(MINIGAMES.length / COLS);
    const gridW = COLS * TILE_W + (COLS - 1) * GAP;
    const gridH = rows * TILE_H + (rows - 1) * GAP;
    const startX = (VIEW_W - gridW) / 2;
    const startY = (VIEW_H - gridH) / 2 + 40;

    this._tiles = MINIGAMES.map((game, i) => {
      const col = i % COLS;
      const row = Math.floor(i / COLS);
      return {
        game,
        x: startX + col * (TILE_W + GAP),
        y: startY + row * (TILE_H + GAP),
        w: TILE_W,
        h: TILE_H,
      };
    });
  }

  _hitTest(x, y) {
    return this._tiles.findIndex(
      (t) => x >= t.x && x <= t.x + t.w && y >= t.y && y <= t.y + t.h
    );
  }

  pointermove(x, y) {
    this._hover = this._hitTest(x, y);
  }

  pointerup(x, y) {
    const i = this._hitTest(x, y);
    if (i >= 0) this._onSelect(this._tiles[i].game.id);
  }

  render(ctx) {
    ctx.fillStyle = '#222b3d';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    ctx.fillStyle = '#eef2f7';
    ctx.font = '600 56px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('Childsplay-Modern', VIEW_W / 2, 90);

    this._tiles.forEach((t, i) => {
      ctx.fillStyle = i === this._hover ? '#4c7dff' : '#33405a';
      roundRect(ctx, t.x, t.y, t.w, t.h, 18);
      ctx.fill();

      ctx.fillStyle = '#ffffff';
      ctx.font = '600 34px system-ui, sans-serif';
      ctx.fillText(t.game.name, t.x + t.w / 2, t.y + t.h / 2);
    });
  }
}

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

export { roundRect };
