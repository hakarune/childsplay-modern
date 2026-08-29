// util.js — small shared helpers for the canvas games.

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
  ctx.fillStyle = hover ? '#5b8cff' : '#4c7dff';
  ctx.fill();
  ctx.fillStyle = '#fff';
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
  }

  hide() {
    this.visible = false;
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
    ctx.fillStyle = 'rgba(0,0,0,0.6)';
    ctx.fillRect(0, 0, w, h);

    ctx.fillStyle = '#eef2f7';
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
