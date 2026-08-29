// findit.js — spot the difference. The same picture is shown twice; the
// right copy has a few coloured spots added. Tap them all.

import { Scene, VIEW_W, VIEW_H, img, loadImage, playSound } from '../engine.js';
import { rand, clamp, Overlay, buttonRow } from '../util.js';

const HUD = 64;
const BLOBS = ['#ff5a5a', '#ffd93d', '#6bcb77', '#4d96ff', '#b980f0', '#ff9f45', '#31c2d6'];

const LEVELS = [
  { img: 'renoir0', diffs: 3, r: 30 },
  { img: 'monet0', diffs: 5, r: 25 },
  { img: 'bruegel0', diffs: 6, r: 20 },
];

const SND_GOOD = 'sfx/good.ogg';
const SND_BAD = 'sfx/bump.wav';
const SND_WIN = 'sfx/winner.ogg';

export default class FindItGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._overlay = new Overlay();
    this._level = 0;
    this._miss = null;               // {x, y, t} wrong-tap flash
    this._startLevel(0);
  }

  _startLevel(n) {
    this._level = Math.max(0, Math.min(n, LEVELS.length - 1));
    const lv = LEVELS[this._level];
    this._img = null;
    this._diffs = [];
    this._found = 0;
    this._tries = 0;
    this._miss = null;
    this._overlay.hide();

    loadImage(`puzzle/${lv.img}.jpg`).then((im) => {
      if (LEVELS[this._level] !== lv) return;
      this._img = im;
      this._layout(im, lv);
    });
  }

  _layout(im, lv) {
    const aspect = (im.naturalWidth || 4) / (im.naturalHeight || 3);
    let pw = 560;
    let ph = pw / aspect;
    if (ph > 470) { ph = 470; pw = ph * aspect; }
    const gap = 40;
    const total = pw * 2 + gap;
    const x0 = (VIEW_W - total) / 2;
    const y0 = HUD + (VIEW_H - HUD - ph) / 2;
    this._L = { x: x0, y: y0, w: pw, h: ph };
    this._R = { x: x0 + pw + gap, y: y0, w: pw, h: ph };

    // scatter difference points, spaced apart, away from the edges
    this._diffs = [];
    let guard = 0;
    while (this._diffs.length < lv.diffs && guard++ < 400) {
      const nx = rand(0.1, 0.9);
      const ny = rand(0.12, 0.88);
      if (this._diffs.some((d) => Math.hypot(d.nx - nx, d.ny - ny) < 0.16)) continue;
      this._diffs.push({ nx, ny, color: BLOBS[this._diffs.length % BLOBS.length], found: false });
    }
  }

  update(dt) {
    if (this._miss) { this._miss.t += dt; if (this._miss.t > 0.4) this._miss = null; }
  }

  _panelPoint(panel, x, y) {
    if (x < panel.x || x > panel.x + panel.w || y < panel.y || y > panel.y + panel.h) return null;
    return { nx: (x - panel.x) / panel.w, ny: (y - panel.y) / panel.h };
  }

  pointermove(x, y) { this._overlay.pointermove(x, y); }

  pointerup(x, y) {
    if (this._overlay.visible) {
      const act = this._overlay.pointerup(x, y);
      if (act === 'next') this._startLevel(this._level + 1);
      else if (act === 'replay') this._startLevel(this._level);
      else if (act === 'menu') this._exit();
      return;
    }
    const p = this._panelPoint(this._L, x, y) || this._panelPoint(this._R, x, y);
    if (!p || !this._img) return;
    const tolN = LEVELS[this._level].r / this._R.w * 1.4;
    const hit = this._diffs.find((d) => !d.found && Math.hypot(d.nx - p.nx, d.ny - p.ny) < tolN);
    if (hit) {
      hit.found = true;
      this._found++;
      playSound(SND_GOOD);
      if (this._found === this._diffs.length) this._win();
    } else {
      this._tries++;
      this._miss = { x, y, t: 0 };
      playSound(SND_BAD, { volume: 0.5 });
    }
  }

  _win() {
    playSound(SND_WIN);
    const last = this._level >= LEVELS.length - 1;
    const rows = [['Replay', 'replay'], ['Menu', 'menu']];
    if (!last) rows.unshift(['Next Level', 'next']);
    this._overlay.show(`You spotted them all!\n${this._tries} wrong tap${this._tries === 1 ? '' : 's'}`,
      buttonRow(rows, VIEW_W / 2, VIEW_H / 2 + 20, 190));
  }

  _drawPanel(ctx, panel, withDiffs) {
    ctx.save();
    ctx.beginPath();
    ctx.rect(panel.x, panel.y, panel.w, panel.h);
    ctx.clip();
    ctx.drawImage(this._img, panel.x, panel.y, panel.w, panel.h);
    for (const d of this._diffs) {
      const cx = panel.x + d.nx * panel.w;
      const cy = panel.y + d.ny * panel.h;
      const r = LEVELS[this._level].r;
      if (d.found) {
        ctx.strokeStyle = '#7be0a0';
        ctx.lineWidth = 5;
        ctx.beginPath();
        ctx.arc(cx, cy, r + 4, 0, Math.PI * 2);
        ctx.stroke();
      } else if (withDiffs) {
        ctx.fillStyle = d.color;
        ctx.beginPath();
        ctx.ellipse(cx, cy, r, r * 0.82, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = 'rgba(0,0,0,0.35)';
        ctx.lineWidth = 2;
        ctx.stroke();
      }
    }
    ctx.restore();
    ctx.strokeStyle = '#5a6f9c';
    ctx.lineWidth = 3;
    ctx.strokeRect(panel.x, panel.y, panel.w, panel.h);
  }

  render(ctx) {
    ctx.fillStyle = '#20242e';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    ctx.fillStyle = 'rgba(16,21,32,0.6)';
    ctx.fillRect(0, 0, VIEW_W, HUD);
    ctx.fillStyle = '#eef2f7';
    ctx.font = '600 24px system-ui, sans-serif';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    ctx.fillText(`Found ${this._found}/${this._diffs.length}`, 220, HUD / 2);
    ctx.textAlign = 'right';
    ctx.fillText(`Level ${this._level + 1}/${LEVELS.length}`, VIEW_W - 24, HUD / 2);
    ctx.textAlign = 'center';
    ctx.fillStyle = '#9fb4d8';
    ctx.fillText('find what is different on the right picture', VIEW_W / 2, HUD / 2);

    if (!this._img) {
      ctx.fillStyle = '#9fb4d8';
      ctx.fillText('loading picture…', VIEW_W / 2, VIEW_H / 2);
      return;
    }

    this._drawPanel(ctx, this._L, false);
    this._drawPanel(ctx, this._R, true);

    if (this._miss) {
      ctx.globalAlpha = clamp(1 - this._miss.t / 0.4, 0, 1);
      ctx.strokeStyle = '#ff5a5a';
      ctx.lineWidth = 5;
      const s = 16;
      ctx.beginPath();
      ctx.moveTo(this._miss.x - s, this._miss.y - s);
      ctx.lineTo(this._miss.x + s, this._miss.y + s);
      ctx.moveTo(this._miss.x + s, this._miss.y - s);
      ctx.lineTo(this._miss.x - s, this._miss.y + s);
      ctx.stroke();
      ctx.globalAlpha = 1;
    }

    this._overlay.render(ctx, VIEW_W, VIEW_H);
  }
}
