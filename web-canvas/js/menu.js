// menu.js — the MainMenu state: a paginated kiosk grid of big square icon
// tiles. Follows Design Policy §F (square tiles, uniform icon margin, state
// deltas that don't rely on a border, responsive columns + pagination).

import { Scene, VIEW_W, VIEW_H, img } from './engine.js';
import { MENU } from './games/index.js';
import { roundRect, drawImageFit, inRect, tint } from './util.js';
import { theme } from './theme.js';

const PAD = 44;
const TITLE_H = 112;
const PAGER_H = 46;
const GAP = 22;
const TARGET_TILE = 260;   // §F.3.1
const MIN_ICON = 96;       // §F.1.4
const MAX_TILE = 300;

export class MainMenu extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._onSelect = opts.onSelect || (() => {});
    this._tiles = [];
    this._hover = -1;
    this._press = -1;
    this._page = 0;
    this._pages = 1;
    this._perPage = MENU.length;
    this._swipeX = null;
    this._t = 0;
  }

  enter() { this._layout(); }
  resize() { this._layout(); }

  _layout() {
    const availW = VIEW_W - PAD * 2;
    const availH = VIEW_H - TITLE_H - PAD - PAGER_H;

    const cols = Math.max(2, Math.min(5, Math.floor(VIEW_W / TARGET_TILE)));
    const widthEdge = (availW - GAP * (cols - 1)) / cols;
    // cap the tile so at least ~2 rows are visible, and by an absolute max
    let edge = Math.min(widthEdge, MAX_TILE, availH * 0.46);
    edge = Math.max(edge, MIN_ICON + 44);        // room for icon + label band

    const rowsPerPage = Math.max(1, Math.floor((availH + GAP) / (edge + GAP)));
    this._perPage = cols * rowsPerPage;
    this._pages = Math.max(1, Math.ceil(MENU.length / this._perPage));
    this._page = Math.min(this._page, this._pages - 1);

    const start = this._page * this._perPage;
    const shown = MENU.slice(start, start + this._perPage);
    const rows = Math.ceil(shown.length / cols);

    const gridW = cols * edge + (cols - 1) * GAP;
    const gridH = rows * edge + (rows - 1) * GAP;
    const sx = (VIEW_W - gridW) / 2;
    const sy = TITLE_H + Math.max(0, (availH - gridH) / 2);

    this._edge = edge;
    this._tiles = shown.map((g, i) => ({
      game: g,
      x: sx + (i % cols) * (edge + GAP),
      y: sy + Math.floor(i / cols) * (edge + GAP),
      w: edge,
      h: edge,
    }));

    const cy = TITLE_H + availH / 2;
    this._prevBtn = { x: 6, y: cy - 34, w: 46, h: 68, act: 'prev' };
    this._nextBtn = { x: VIEW_W - 52, y: cy - 34, w: 46, h: 68, act: 'next' };
  }

  update(dt) { this._t += dt; }

  _hit(x, y) { return this._tiles.findIndex((t) => inRect(t, x, y)); }

  _turn(delta) {
    const p = Math.min(this._pages - 1, Math.max(0, this._page + delta));
    if (p !== this._page) { this._page = p; this._hover = this._press = -1; this._layout(); }
  }

  pointermove(x, y) { this._hover = this._hit(x, y); }

  pointerdown(x, y) {
    this._press = this._hit(x, y);
    this._swipeX = x;
  }

  pointerup(x, y) {
    if (this._pages > 1) {
      if (inRect(this._prevBtn, x, y)) return this._turn(-1);
      if (inRect(this._nextBtn, x, y)) return this._turn(1);
      if (this._swipeX != null && this._press < 0) {
        const dx = x - this._swipeX;
        if (dx > 70) return this._turn(-1);
        if (dx < -70) return this._turn(1);
      }
    }
    const i = this._hit(x, y);
    if (i >= 0 && i === this._press) this._onSelect(this._tiles[i].game.id);
    this._press = -1;
    this._swipeX = null;
  }

  keydown(e) {
    if (e.key === 'ArrowLeft') this._turn(-1);
    else if (e.key === 'ArrowRight') this._turn(1);
  }

  render(ctx) {
    ctx.fillStyle = theme.bg;
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = theme.text;
    ctx.font = '700 58px system-ui, "Segoe UI", Roboto, sans-serif';
    ctx.fillText('Childsplay', VIEW_W / 2, TITLE_H / 2 - 4);
    ctx.fillStyle = theme.text_muted;
    ctx.font = '400 23px system-ui, sans-serif';
    ctx.fillText('pick a game', VIEW_W / 2, TITLE_H / 2 + 38);

    const iconMargin = Math.max(12, Math.min(28, this._edge * 0.10));

    this._tiles.forEach((t, i) => {
      const pressed = i === this._press;
      const hovered = i === this._hover && !pressed;
      const shrink = pressed ? 4 : 0;
      const x = t.x + shrink;
      const y = t.y + shrink;
      const w = t.w - shrink * 2;
      const h = t.h - shrink * 2;

      roundRect(ctx, x, y, w, h, 22);
      ctx.fillStyle = pressed ? theme.accent
        : hovered ? theme.surface_alt
        : theme.surface;
      ctx.fill();
      if (hovered) {
        ctx.lineWidth = 3;
        ctx.strokeStyle = theme.accent;
        ctx.stroke();
      }

      // icon — square, uniform margin, label band reserved at the bottom
      const labelBand = Math.max(30, h * 0.20);
      const iconBox = Math.min(w, h - labelBand) - iconMargin * 2;
      const icon = img(t.game.icon);
      const ix = x + (w - iconBox) / 2;
      const iy = y + iconMargin;
      if (icon && icon.naturalWidth) {
        drawImageFit(ctx, icon, ix, iy, iconBox, iconBox);
      } else {
        ctx.fillStyle = tint(theme.surface, theme.mode === 'light' ? -0.12 : 0.14);
        roundRect(ctx, ix, iy, iconBox, iconBox, 16);
        ctx.fill();
      }

      // label on a scrim band inside the tile
      const bandY = y + h - labelBand;
      const g = ctx.createLinearGradient(0, bandY, 0, y + h);
      g.addColorStop(0, 'rgba(0,0,0,0)');
      g.addColorStop(1, pressed ? 'rgba(0,0,0,0.28)' : 'rgba(0,0,0,0.34)');
      ctx.fillStyle = g;
      ctx.fillRect(x, bandY, w, labelBand);
      ctx.fillStyle = pressed ? '#ffffff' : theme.text;
      ctx.font = `600 ${Math.round(labelBand * 0.5)}px system-ui, sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(t.game.name, x + w / 2, bandY + labelBand * 0.56);
    });

    // pager
    if (this._pages > 1) {
      for (const [b, glyph] of [[this._prevBtn, '‹'], [this._nextBtn, '›']]) {
        const dim = (b.act === 'prev' && this._page === 0) || (b.act === 'next' && this._page === this._pages - 1);
        roundRect(ctx, b.x, b.y, b.w, b.h, 12);
        ctx.fillStyle = theme.surface;
        ctx.globalAlpha = dim ? 0.35 : 1;
        ctx.fill();
        ctx.fillStyle = theme.text;
        ctx.font = '700 44px system-ui, sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(glyph, b.x + b.w / 2, b.y + b.h / 2);
        ctx.globalAlpha = 1;
      }
      const dw = 18;
      const y0 = VIEW_H - PAGER_H / 2;
      for (let p = 0; p < this._pages; p++) {
        ctx.beginPath();
        ctx.arc(VIEW_W / 2 - (this._pages * dw) / 2 + p * dw + dw / 2, y0, 6, 0, Math.PI * 2);
        ctx.fillStyle = p === this._page ? theme.accent : theme.text_muted;
        ctx.fill();
      }
    }
  }
}
