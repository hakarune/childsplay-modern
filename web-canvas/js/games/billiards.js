// billiards.js — 2D pool. Drag from the cue ball to aim and set power;
// release to strike. Sink every colour ball; a scratch just spots the cue.

import { Scene, VIEW_W, VIEW_H, img, playSound } from '../engine.js';
import { clamp, dist, inRect, Overlay, buttonRow } from '../util.js';

const TABLE_MAX_W = 980;
const TABLE_H = 520;
const TABLE_Y = 128;
const R = 16;
const POCKET_R = 34;
const FRICTION = 0.6;       // velocity retained per second
const REST = 0.86;          // wall restitution
const STOP = 6;
const MAX_V = 1500;
const POWER_K = 4.2;
const MAX_PULL = 260;
const SUBSTEPS = 4;

const COLORS = ['#ffcf3f', '#3f6fff', '#ff5a5a', '#a05bff', '#ff9838',
  '#31b06a', '#8a5a2b', '#e14b8a', '#33c2d6', '#c9d13a'];

const LEVELS = [
  { name: 'Warm-up', targets: 3 },
  { name: 'Rack',    targets: 6 },
  { name: 'Full',    targets: 10 },
];

const SND_CUE = 'sfx/sndh.wav';
const SND_CLICK = 'sfx/sndt.wav';
const SND_POCKET = 'sfx/pick.wav';
const SND_WIN = 'sfx/winner.ogg';

export default class BilliardsGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._overlay = new Overlay();
    this._clickCd = 0;
    this._level = 0;
    this._geo();
    this._startLevel(0);
  }

  // Table + pockets + spot positions for the current world width. The table
  // is centred and shrinks to keep a margin on narrow worlds.
  _geo() {
    const w = Math.min(TABLE_MAX_W, VIEW_W - 150);
    const T = { x: Math.round((VIEW_W - w) / 2), y: TABLE_Y, w, h: TABLE_H };
    this._T = T;
    this._pockets = [
      { x: T.x, y: T.y }, { x: T.x + T.w / 2, y: T.y }, { x: T.x + T.w, y: T.y },
      { x: T.x, y: T.y + T.h }, { x: T.x + T.w / 2, y: T.y + T.h }, { x: T.x + T.w, y: T.y + T.h },
    ];
    this._head = { x: T.x + T.w * 0.26, y: T.y + T.h / 2 };
    this._foot = { x: T.x + T.w * 0.70, y: T.y + T.h / 2 };
  }

  resize() {
    const oldX = this._T ? this._T.x : null;
    this._geo();
    if (oldX != null && this._balls) {
      const dx = this._T.x - oldX;
      for (const b of this._balls) b.x += dx;
    }
    this._overlay.reflow(VIEW_W / 2, VIEW_H / 2 + 20);
  }

  _startLevel(n) {
    this._level = Math.max(0, Math.min(n, LEVELS.length - 1));
    const count = LEVELS[this._level].targets;
    this._shots = 0;
    this._over = false;
    this._aim = null;
    this._overlay.hide();
    this._geo();

    this._cue = { x: this._head.x, y: this._head.y, vx: 0, vy: 0, cue: true, potted: false };
    this._balls = [this._cue];

    let row = 0, col = 0, per = 1;
    for (let i = 0; i < count; i++) {
      this._balls.push({
        x: this._foot.x + row * (R * 2 + 1) * 0.92 + (Math.random() - 0.5) * 2,
        y: this._foot.y + (col - row / 2) * (R * 2 + 1) + (Math.random() - 0.5) * 2,
        vx: 0, vy: 0, cue: false, potted: false, color: COLORS[i % COLORS.length],
      });
      if (++col >= per) { row++; per++; col = 0; }
    }
    this._left = count;
  }

  _moving() {
    return this._balls.some((b) => !b.potted && Math.hypot(b.vx, b.vy) > STOP);
  }
  _canShoot() {
    return !this._over && !this._moving();
  }

  // --- physics ---
  update(dt) {
    if (this._clickCd > 0) this._clickCd -= dt;
    if (this._over) return;

    const h = dt / SUBSTEPS;
    for (let s = 0; s < SUBSTEPS; s++) this._physics(h);

    for (const b of this._balls) {
      if (b.potted) continue;
      const sp = Math.hypot(b.vx, b.vy);
      if (sp > 0 && sp < STOP) { b.vx = 0; b.vy = 0; }
    }
  }

  _physics(h) {
    const damp = Math.pow(FRICTION, h);
    for (const b of this._balls) {
      if (b.potted) continue;
      b.vx *= damp; b.vy *= damp;
      const sp = Math.hypot(b.vx, b.vy);
      if (sp > MAX_V) { b.vx *= MAX_V / sp; b.vy *= MAX_V / sp; }
      b.x += b.vx * h;
      b.y += b.vy * h;
      this._pocketsAndWalls(b);
    }
    // ball-ball
    for (let i = 0; i < this._balls.length; i++) {
      const a = this._balls[i];
      if (a.potted) continue;
      for (let j = i + 1; j < this._balls.length; j++) {
        const c = this._balls[j];
        if (c.potted) continue;
        const dx = c.x - a.x, dy = c.y - a.y;
        const d = Math.hypot(dx, dy) || 0.0001;
        if (d < R * 2) {
          const nx = dx / d, ny = dy / d;
          const overlap = R * 2 - d;
          a.x -= nx * overlap / 2; a.y -= ny * overlap / 2;
          c.x += nx * overlap / 2; c.y += ny * overlap / 2;
          const rel = (c.vx - a.vx) * nx + (c.vy - a.vy) * ny;
          if (rel < 0) {
            a.vx += rel * nx; a.vy += rel * ny;
            c.vx -= rel * nx; c.vy -= rel * ny;
            if (this._clickCd <= 0) { playSound(SND_CLICK, { volume: 0.6 }); this._clickCd = 0.05; }
          }
        }
      }
    }
  }

  _pocketsAndWalls(b) {
    const T = this._T;
    for (const p of this._pockets) {
      if (dist(b.x, b.y, p.x, p.y) < POCKET_R) {
        if (b.cue) {
          playSound(SND_POCKET);
          b.x = this._head.x; b.y = this._head.y; b.vx = 0; b.vy = 0;
        } else {
          b.potted = true; b.vx = 0; b.vy = 0;
          this._left--;
          playSound(SND_POCKET);
          if (this._left <= 0) this._win();
        }
        return;
      }
    }
    // Skip cushion bounce while near a pocket mouth (forgiving pots).
    const nearPocket = this._pockets.some((p) => dist(b.x, b.y, p.x, p.y) < POCKET_R * 1.8);
    if (nearPocket) return;

    if (b.x - R < T.x) { b.x = T.x + R; b.vx = Math.abs(b.vx) * REST; }
    else if (b.x + R > T.x + T.w) { b.x = T.x + T.w - R; b.vx = -Math.abs(b.vx) * REST; }
    if (b.y - R < T.y) { b.y = T.y + R; b.vy = Math.abs(b.vy) * REST; }
    else if (b.y + R > T.y + T.h) { b.y = T.y + T.h - R; b.vy = -Math.abs(b.vy) * REST; }
  }

  _win() {
    this._over = true;
    playSound(SND_WIN, { channel: 'music' });
    const last = this._level >= LEVELS.length - 1;
    const rows = [['Replay', 'replay'], ['Menu', 'menu']];
    if (!last) rows.unshift(['Next Level', 'next']);
    this._overlay.show(`Nice shooting!\n${this._shots} shot${this._shots === 1 ? '' : 's'}`,
      buttonRow(rows, VIEW_W / 2, VIEW_H / 2 + 20, 190));
  }

  // --- input: drag to aim ---
  pointerdown(x, y) {
    if (this._overlay.visible || !this._canShoot()) return;
    this._aim = { x, y };
  }

  pointermove(x, y) {
    this._overlay.pointermove(x, y);
    if (this._aim) this._aim = { x, y };
  }

  pointerup(x, y) {
    if (this._overlay.visible) {
      const act = this._overlay.pointerup(x, y);
      if (act === 'next') this._startLevel(this._level + 1);
      else if (act === 'replay') this._startLevel(this._level);
      else if (act === 'menu') this._exit();
      return;
    }
    if (!this._aim || !this._canShoot()) { this._aim = null; return; }
    const dx = this._aim.x - this._cue.x;
    const dy = this._aim.y - this._cue.y;
    const d = Math.hypot(dx, dy);
    this._aim = null;
    if (d < 8) return;
    const power = clamp(d, 0, MAX_PULL) * POWER_K;
    this._cue.vx = (dx / d) * power;
    this._cue.vy = (dy / d) * power;
    this._shots++;
    playSound(SND_CUE);
  }

  render(ctx) {
    ctx.fillStyle = '#12201b';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    // rail + felt
    const T = this._T;
    ctx.fillStyle = '#5c3a20';
    ctx.fillRect(T.x - 18, T.y - 18, T.w + 36, T.h + 36);
    ctx.fillStyle = '#1f7a48';
    ctx.fillRect(T.x, T.y, T.w, T.h);

    for (const p of this._pockets) {
      ctx.fillStyle = '#07120c';
      ctx.beginPath();
      ctx.arc(p.x, p.y, POCKET_R * 0.8, 0, Math.PI * 2);
      ctx.fill();
    }

    // aim line
    if (this._aim && this._canShoot()) {
      const dx = this._aim.x - this._cue.x;
      const dy = this._aim.y - this._cue.y;
      const d = Math.hypot(dx, dy) || 1;
      const p = clamp(d, 0, MAX_PULL) / MAX_PULL;
      ctx.strokeStyle = `rgba(${255 * p + 60 * (1 - p)},${230 * (1 - p) + 90 * p},${90},0.9)`;
      ctx.lineWidth = 5;
      ctx.setLineDash([12, 10]);
      ctx.beginPath();
      ctx.moveTo(this._cue.x, this._cue.y);
      ctx.lineTo(this._cue.x + (dx / d) * (70 + p * 200), this._cue.y + (dy / d) * (70 + p * 200));
      ctx.stroke();
      ctx.setLineDash([]);
    }

    const cueImg = img('sprites/billiards/ball1');
    for (const b of this._balls) {
      if (b.potted) continue;
      if (b.cue) {
        if (cueImg && cueImg.naturalWidth) ctx.drawImage(cueImg, b.x - R, b.y - R, R * 2, R * 2);
        else { ctx.fillStyle = '#f4f4f4'; ctx.beginPath(); ctx.arc(b.x, b.y, R, 0, 7); ctx.fill(); }
      } else {
        ctx.fillStyle = b.color;
        ctx.beginPath();
        ctx.arc(b.x, b.y, R, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = 'rgba(255,255,255,0.35)';
        ctx.beginPath();
        ctx.arc(b.x - R * 0.3, b.y - R * 0.3, R * 0.35, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    // HUD
    ctx.fillStyle = 'rgba(16,21,32,0.6)';
    ctx.fillRect(0, 0, VIEW_W, 60);
    ctx.fillStyle = '#eef2f7';
    ctx.font = '600 24px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(`Shots ${this._shots}    Balls left ${this._left}`, VIEW_W / 2, 30);
    ctx.textAlign = 'right';
    ctx.fillText(`Level ${this._level + 1}/${LEVELS.length}  -  ${LEVELS[this._level].name}`, VIEW_W - 24, 30);
    if (!this._canShoot() && !this._over) {
      ctx.textAlign = 'left';
      ctx.fillStyle = '#9fb4d8';
      ctx.fillText('rolling…', 220, 30);
    }

    this._overlay.render(ctx, VIEW_W, VIEW_H);
  }
}
