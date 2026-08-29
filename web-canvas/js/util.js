// util.js — small shared helpers for the canvas games.

import { theme, DARK } from './theme.js';

export const clamp = (v, lo, hi) => (v < lo ? lo : v > hi ? hi : v);
export const lerp = (a, b, t) => a + (b - a) * t;
export const rand = (lo, hi) => lo + Math.random() * (hi - lo);
export const randInt = (n) => (Math.random() * n) | 0;
export const pick = (arr) => arr[randInt(arr.length)];
export const dist = (ax, ay, bx, by) => Math.hypot(ax - bx, ay - by);

export function shuffle(arr) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = randInt(i + 1);
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

// --- colour helpers (Design Policy §D.4) ------------------------------
function _lum(hex) {
  const m = String(hex).replace('#', '').match(/../g);
  if (!m) return 0;
  const [r, g, b] = m.map((h) => {
    const c = parseInt(h, 16) / 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/** WCAG contrast ratio between two #rrggbb colours (1 … 21). */
export function contrastRatio(a, b) {
  const la = _lum(a);
  const lb = _lum(b);
  return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

/** Mix a #rrggbb colour toward white (amt>0) or black (amt<0), |amt| 0..1. */
export function tint(hex, amt) {
  const m = String(hex).replace('#', '').match(/../g);
  if (!m) return hex;
  const t = amt < 0 ? 0 : 255;
  const k = Math.abs(amt);
  const out = m.map((h) => {
    const v = parseInt(h, 16);
    return Math.round(v + (t - v) * k).toString(16).padStart(2, '0');
  });
  return `#${out.join('')}`;
}

// --- Bag: draw-without-replacement with auto-reshuffle (Design Policy §B) ---
export class Bag {
  constructor(items = []) {
    this._all = items.slice();
    this._pool = [];
    this.filter = null;         // optional (x) => boolean
  }

  _refill() {
    let src = this.filter ? this._all.filter(this.filter) : this._all;
    if (!src.length) src = this._all.slice();
    this._pool = shuffle(src.slice());
  }

  draw() {
    if (!this._pool.length) this._refill();
    return this._pool.pop();
  }

  drawN(n) {
    const out = [];
    for (let i = 0; i < n; i++) {
      if (!this._pool.length) this._refill();
      out.push(this._pool.pop());
    }
    return out;
  }
}

// Session-scoped bag registry. Keys prefixed `<gameId>:` are cleared when
// that game (re)launches; unprefixed keys (e.g. `backgrounds:med`, shared by
// Puzzle + Wipe) persist for the whole session.
const _bags = new Map();

export function bag(key, items) {
  let b = _bags.get(key);
  if (!b) { b = new Bag(items); _bags.set(key, b); }
  return b;
}

export function resetBags(prefix) {
  if (!prefix) { _bags.clear(); return; }
  for (const k of [..._bags.keys()]) if (k.startsWith(prefix)) _bags.delete(k);
}

export function roundRect(ctx, x, y, w, h, r) {
  const rr = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + rr, y);
  ctx.arcTo(x + w, y, x + w, y + h, rr);
  ctx.arcTo(x + w, y + h, x, y + h, rr);
  ctx.arcTo(x, y + h, x, y, rr);
  ctx.arcTo(x, y, x + w, y, rr);
  ctx.closePath();
}

// Draw an image "contain"-fitted (no distortion) inside a box.
export function drawImageFit(ctx, img, x, y, w, h) {
  if (!img || !img.naturalWidth) return;
  const s = Math.min(w / img.naturalWidth, h / img.naturalHeight);
  const dw = img.naturalWidth * s;
  const dh = img.naturalHeight * s;
  ctx.drawImage(img, x + (w - dw) / 2, y + (h - dh) / 2, dw, dh);
}

// --- canvas buttons for the win / game-over overlays -------------------
export function drawButton(ctx, b, hover) {
  roundRect(ctx, b.x, b.y, b.w, b.h, 14);
  ctx.fillStyle = hover ? tint(theme.accent, 0.16) : theme.accent;
  ctx.fill();
  ctx.fillStyle = '#ffffff';
  ctx.font = '600 26px system-ui, sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(b.label, b.x + b.w / 2, b.y + b.h / 2);
}

export const inRect = (b, px, py) =>
  px >= b.x && px <= b.x + b.w && py >= b.y && py <= b.y + b.h;

// Shared "you did it" / "try again" overlay used by every game.
export class Overlay {
  constructor() {
    this.visible = false;
    this.title = '';
    this.buttons = []; // [{ x,y,w,h,label,action }]
    this._hover = -1;
  }

  show(title, buttons) {
    this.title = title;
    this.buttons = buttons;
    this.visible = true;
    this._hover = -1;
    this._anchor = this._center();
  }

  hide() {
    this.visible = false;
  }

  _center() {
    if (!this.buttons.length) return { x: 0, y: 0 };
    let x = 0;
    let y = 0;
    for (const b of this.buttons) { x += b.x + b.w / 2; y += b.y + b.h / 2; }
    return { x: x / this.buttons.length, y: y / this.buttons.length };
  }

  // Re-centre the button row after the world size changed. Games call this
  // from resize() with the same (cx, cy) they passed to buttonRow().
  reflow(cx, cy) {
    if (!this.visible || !this._anchor) return;
    const dx = cx - this._anchor.x;
    const dy = cy - this._anchor.y;
    for (const b of this.buttons) { b.x += dx; b.y += dy; }
    this._anchor = { x: cx, y: cy };
  }

  pointermove(x, y) {
    if (this.visible) this._hover = this.buttons.findIndex((b) => inRect(b, x, y));
  }

  // Returns the action string of a clicked button, or null.
  pointerup(x, y) {
    if (!this.visible) return null;
    const b = this.buttons.find((btn) => inRect(btn, x, y));
    return b ? b.action : null;
  }

  render(ctx, w, h) {
    if (!this.visible) return;
    ctx.fillStyle = theme.overlay_scrim;
    ctx.fillRect(0, 0, w, h);

    // overlay chrome sits on the (always-dark) scrim in both themes
    ctx.fillStyle = DARK.text;
    ctx.font = '700 46px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    for (const [i, line] of this.title.split('\n').entries()) {
      ctx.fillText(line, w / 2, h / 2 - 90 + i * 54);
    }
    this.buttons.forEach((b, i) => drawButton(ctx, b, i === this._hover));
  }
}

// Lay a row of equal buttons out, centred on cx at vertical y.
export function buttonRow(labels, cx, y, bw = 220, bh = 60, gap = 24) {
  const total = labels.length * bw + (labels.length - 1) * gap;
  return labels.map(([label, action], i) => ({
    label,
    action,
    x: cx - total / 2 + i * (bw + gap),
    y,
    w: bw,
    h: bh,
  }));
}
