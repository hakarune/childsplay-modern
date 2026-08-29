// puzzle.js — drag the pieces of a painting back into the frame.
//
// Levels 1-3 are regular grids (2x2 / 3x3 / 4x4). Levels 4-6 are cut into
// rectangles of *different sizes* by recursive random splits, so there's
// no grid to lean on.

import { Scene, VIEW_W, VIEW_H, loadImage, playSound } from '../engine.js';
import { roundRect, clamp, rand, shuffle, Overlay, buttonRow } from '../util.js';

const LEVELS = [
  { img: 'renoir0',  name: '2 x 2',       kind: 'grid', cols: 2, rows: 2 },
  { img: 'monet0',   name: '3 x 3',       kind: 'grid', cols: 3, rows: 3 },
  { img: 'bruegel0', name: '4 x 4',       kind: 'grid', cols: 4, rows: 4 },
  { img: 'gogh0',    name: 'Odd shapes',  kind: 'free', pieces: 6,  min: 0.17 },
  { img: 'pieck0',   name: 'More shapes', kind: 'free', pieces: 9,  min: 0.135 },
  { img: 'vermeer1', name: 'Puzzler',     kind: 'free', pieces: 12, min: 0.11 },
];

const SND_SNAP = 'sfx/pick.wav';
const SND_WIN = 'sfx/winner.ogg';
const SNAP = 42;

// Recursively split the unit square into ~`count` rectangles, never
// smaller than `min` on a side, splitting the biggest regions first (and
// trying the next-biggest if one won't split). Returns [{x,y,w,h}] in
// 0..1 space.
function freeRects(count, min) {
  const rects = [{ x: 0, y: 0, w: 1, h: 1 }];
  let fails = 0;
  while (rects.length < count && fails < 80) {
    rects.sort((a, b) => b.w * b.h - a.w * a.h);
    let done = false;
    for (let k = 0; k < Math.min(3, rects.length) && !done; k++) {
      const r = rects[k];
      const horiz = r.w >= r.h;
      const along = horiz ? r.w : r.h;
      if (along < min * 2) continue;
      const cut = along * rand(0.36, 0.64);
      if (cut < min || along - cut < min) continue;
      const a = horiz
        ? { x: r.x, y: r.y, w: cut, h: r.h }
        : { x: r.x, y: r.y, w: r.w, h: cut };
      const b = horiz
        ? { x: r.x + cut, y: r.y, w: r.w - cut, h: r.h }
        : { x: r.x, y: r.y + cut, w: r.w, h: r.h - cut };
      rects.splice(k, 1, a, b);
      done = true;
    }
    if (!done) fails++;
  }
  return rects;
}

function gridRects(cols, rows) {
  const out = [];
  for (let r = 0; r < rows; r++)
    for (let c = 0; c < cols; c++)
      out.push({ x: c / cols, y: r / rows, w: 1 / cols, h: 1 / rows });
  return out;
}

export default class PuzzleGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._overlay = new Overlay();
    this._level = 0;
    this._startLevel(0);
  }

  _startLevel(n) {
    this._level = Math.max(0, Math.min(n, LEVELS.length - 1));
    this._image = null;
    this._pieces = [];
    this._drag = null;
    this._placed = 0;
    this._overlay.hide();

    const lv = LEVELS[this._level];
    loadImage(`puzzle/${lv.img}.jpg`).then((im) => {
      if (this._level !== LEVELS.indexOf(lv)) return; // stale
      this._image = im;
      this._build(lv);
    });
  }

  _build(lv) {
    const im = this._image;
    const aspect = (im.naturalWidth || 4) / (im.naturalHeight || 3);

    // Frame on the left; pieces scatter on the right.
    let fw = 660;
    let fh = fw / aspect;
    if (fh > 520) { fh = 520; fw = fh * aspect; }
    this._frame = { x: 56, y: 96 + (600 - fh) / 2, w: fw, h: fh };

    const norm = lv.kind === 'grid'
      ? gridRects(lv.cols, lv.rows)
      : freeRects(lv.pieces, lv.min);

    const f = this._frame;
    const scatterX = f.x + f.w + 46;
    this._pieces = norm.map((nr) => {
      const home = { x: f.x + nr.x * f.w, y: f.y + nr.y * f.h, w: nr.w * f.w, h: nr.h * f.h };
      return {
        nr, home,
        px: rand(scatterX, VIEW_W - 30 - home.w),
        py: rand(96, VIEW_H - 30 - home.h),
        placed: false,
      };
    });
    shuffle(this._pieces); // random draw order
  }

  // --- input ---
  _topPieceAt(x, y) {
    for (let i = this._pieces.length - 1; i >= 0; i--) {
      const p = this._pieces[i];
      if (!p.placed && x >= p.px && x <= p.px + p.home.w && y >= p.py && y <= p.py + p.home.h) return p;
    }
    return null;
  }

  pointerdown(x, y) {
    if (this._overlay.visible || !this._image) return;
    const p = this._topPieceAt(x, y);
    if (!p) return;
    this._drag = { p, ox: x - p.px, oy: y - p.py };
    this._pieces.splice(this._pieces.indexOf(p), 1);
    this._pieces.push(p); // bring to front
  }

  pointermove(x, y) {
    this._overlay.pointermove(x, y);
    if (!this._drag) return;
    const p = this._drag.p;
    p.px = clamp(x - this._drag.ox, 0, VIEW_W - p.home.w);
    p.py = clamp(y - this._drag.oy, 0, VIEW_H - p.home.h);
  }

  pointerup(x, y) {
    if (this._overlay.visible) {
      const act = this._overlay.pointerup(x, y);
      if (act === 'next') this._startLevel(this._level + 1);
      else if (act === 'replay') this._startLevel(this._level);
      else if (act === 'menu') this._exit();
      return;
    }
    if (!this._drag) return;
    const p = this._drag.p;
    this._drag = null;
    if (Math.hypot(p.px - p.home.x, p.py - p.home.y) < SNAP) {
      p.px = p.home.x;
      p.py = p.home.y;
      p.placed = true;
      this._placed++;
      playSound(SND_SNAP);
      if (this._placed === this._pieces.length) this._win();
    }
  }

  _win() {
    playSound(SND_WIN);
    const last = this._level >= LEVELS.length - 1;
    const rows = [['Replay', 'replay'], ['Menu', 'menu']];
    if (!last) rows.unshift(['Next Level', 'next']);
    this._overlay.show('Picture complete!', buttonRow(rows, VIEW_W / 2, VIEW_H / 2 + 20, 190));
  }

  render(ctx) {
    ctx.fillStyle = '#20242e';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    // HUD
    ctx.fillStyle = 'rgba(16,21,32,0.6)';
    ctx.fillRect(0, 0, VIEW_W, 70);
    ctx.fillStyle = '#eef2f7';
    ctx.font = '600 24px system-ui, sans-serif';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    ctx.fillText(`Pieces ${this._placed}/${this._pieces.length}`, 220, 35);
    ctx.textAlign = 'right';
    ctx.fillText(`Level ${this._level + 1}/${LEVELS.length}  -  ${LEVELS[this._level].name}`, VIEW_W - 24, 35);

    if (!this._image) {
      ctx.textAlign = 'center';
      ctx.fillStyle = '#9fb4d8';
      ctx.font = '400 26px system-ui, sans-serif';
      ctx.fillText('loading picture…', VIEW_W / 2, VIEW_H / 2);
      return;
    }

    const f = this._frame;
    const im = this._image;

    // faint whole-picture ghost + frame + per-piece home outlines
    ctx.save();
    ctx.globalAlpha = 0.14;
    ctx.drawImage(im, f.x, f.y, f.w, f.h);
    ctx.restore();
    ctx.strokeStyle = '#5a6f9c';
    ctx.lineWidth = 3;
    ctx.strokeRect(f.x, f.y, f.w, f.h);
    ctx.strokeStyle = 'rgba(120,140,180,0.35)';
    ctx.lineWidth = 1;
    for (const p of this._pieces) ctx.strokeRect(p.home.x, p.home.y, p.home.w, p.home.h);

    // pieces (placed first, then loose ones on top)
    const order = [...this._pieces.filter((p) => p.placed), ...this._pieces.filter((p) => !p.placed)];
    for (const p of order) {
      const s = p.nr;
      ctx.drawImage(
        im,
        s.x * im.naturalWidth, s.y * im.naturalHeight, s.w * im.naturalWidth, s.h * im.naturalHeight,
        p.px, p.py, p.home.w, p.home.h
      );
      ctx.strokeStyle = p.placed ? 'rgba(255,255,255,0.15)' : 'rgba(0,0,0,0.55)';
      ctx.lineWidth = p.placed ? 1 : 2;
      ctx.strokeRect(p.px, p.py, p.home.w, p.home.h);
    }

    this._overlay.render(ctx, VIEW_W, VIEW_H);
  }
}
