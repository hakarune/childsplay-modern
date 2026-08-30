// pong.js — bat and ball versus a gentle computer paddle. First to 5.

import { Scene, VIEW_W, VIEW_H, playSound } from '../engine.js';
import { clamp, rand, Overlay, buttonRow } from '../util.js';
import { theme } from '../theme.js';

const HUD = 64;
const PW = 16, PH = 116;          // paddle size
const BR = 12;                    // ball radius
const TARGET = 5;
const BASE = 330, SPEEDUP = 20, MAXV = 620;

const LEVELS = [
  { name: 'Gentle', ai: 52 },
  { name: 'Rally', ai: 78 },
  { name: 'Speedy', ai: 106 },
];

const SND_WALL = 'sfx/bump.wav';
const SND_HIT = 'sfx/pick.wav';
const SND_GOAL = 'sfx/goal.wav';
const SND_WIN = 'sfx/winner.ogg';

export default class PongGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._overlay = new Overlay();
    this._level = 0;
    this._keys = { up: false, down: false };
    this._startLevel(0);
  }

  _startLevel(n) {
    this._level = Math.max(0, Math.min(n, LEVELS.length - 1));
    this._you = 0;
    this._cpu = 0;
    this._over = false;
    this._py = (HUD + VIEW_H) / 2 - PH / 2;   // player paddle top-y
    this._ay = this._py;                       // ai paddle top-y
    this._overlay.hide();
    this._serve(Math.random() < 0.5 ? 1 : -1);
  }

  _serve(dir) {
    this._bx = VIEW_W / 2;
    this._by = (HUD + VIEW_H) / 2;
    const ang = rand(-0.35, 0.35);
    this._bvx = dir * BASE * Math.cos(ang);
    this._bvy = BASE * Math.sin(ang);
    this._servePause = 0.6;
  }

  update(dt) {
    if (this._over) return;
    const top = HUD, bot = VIEW_H;

    // player paddle: keys + pointer target
    const kv = (this._keys.down ? 1 : 0) - (this._keys.up ? 1 : 0);
    if (kv) this._py = clamp(this._py + kv * 420 * dt, top, bot - PH);
    if (this._ptr != null) {
      const want = clamp(this._ptr - PH / 2, top, bot - PH);
      this._py += (want - this._py) * Math.min(1, dt * 14);
    }

    // ai paddle: chase the ball, capped, with a dead zone
    const aiMax = LEVELS[this._level].ai;
    const acx = this._ay + PH / 2;
    if (Math.abs(this._by - acx) > 16) {
      this._ay = clamp(this._ay + Math.sign(this._by - acx) * aiMax * dt, top, bot - PH);
    }

    if (this._servePause > 0) { this._servePause -= dt; return; }

    this._bx += this._bvx * dt;
    this._by += this._bvy * dt;

    // walls
    if (this._by - BR < top) { this._by = top + BR; this._bvy = Math.abs(this._bvy); playSound(SND_WALL); }
    if (this._by + BR > bot) { this._by = bot - BR; this._bvy = -Math.abs(this._bvy); playSound(SND_WALL); }

    // paddles
    const pL = 60, pR = VIEW_W - 60 - PW;
    if (this._bvx < 0 && this._bx - BR < pL + PW && this._bx - BR > pL - 20 &&
        this._by > this._py - BR && this._by < this._py + PH + BR) {
      this._bounce(this._py, 1);
    }
    if (this._bvx > 0 && this._bx + BR > pR && this._bx + BR < pR + PW + 20 &&
        this._by > this._ay - BR && this._by < this._ay + PH + BR) {
      this._bounce(this._ay, -1);
    }

    // goals
    if (this._bx < -BR) { this._cpu++; this._point(1); }
    else if (this._bx > VIEW_W + BR) { this._you++; this._point(-1); }
  }

  _bounce(paddleTop, dir) {
    this._bvx = dir * Math.min(MAXV, Math.abs(this._bvx) + SPEEDUP);
    const rel = (this._by - (paddleTop + PH / 2)) / (PH / 2);
    this._bvy = clamp(this._bvy + rel * 190, -MAXV, MAXV);
    this._bx += dir * 6;
    playSound(SND_HIT);
  }

  _point(serveDir) {
    playSound(SND_GOAL);
    if (this._you >= TARGET || this._cpu >= TARGET) return this._finish();
    this._serve(serveDir);
  }

  _finish() {
    this._over = true;
    playSound(SND_WIN, { channel: 'music' });
    const won = this._you > this._cpu;
    const last = this._level >= LEVELS.length - 1;
    const rows = [['Replay', 'replay'], ['Menu', 'menu']];
    if (won && !last) rows.unshift(['Next Level', 'next']);
    this._overlay.show(
      `${won ? 'You win!' : 'So close!'}\n${this._you} – ${this._cpu}`,
      buttonRow(rows, VIEW_W / 2, VIEW_H / 2 + 20, 190)
    );
  }

  resize() {
    this._py = clamp(this._py, HUD, VIEW_H - PH);
    this._ay = clamp(this._ay, HUD, VIEW_H - PH);
    this._overlay.reflow(VIEW_W / 2, VIEW_H / 2 + 20);
  }

  keydown(e) {
    if (e.key === 'ArrowUp') this._keys.up = true;
    if (e.key === 'ArrowDown') this._keys.down = true;
  }
  keyup(e) {
    if (e.key === 'ArrowUp') this._keys.up = false;
    if (e.key === 'ArrowDown') this._keys.down = false;
  }

  pointermove(x, y) {
    this._overlay.pointermove(x, y);
    if (x < VIEW_W * 0.55) this._ptr = y;
  }
  pointerdown(x, y) { if (x < VIEW_W * 0.55) this._ptr = y; }

  pointerup(x, y) {
    if (!this._overlay.visible) return;
    const act = this._overlay.pointerup(x, y);
    if (act === 'next') this._startLevel(this._level + 1);
    else if (act === 'replay') this._startLevel(this._level);
    else if (act === 'menu') this._exit();
  }

  render(ctx) {
    ctx.fillStyle = theme.bg;
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    // the court is a fixed dark "screen" (a polarised look) in either theme,
    // framed so its edges read against the page
    const bx = 10, bw = VIEW_W - 20, byy = HUD + 8, bh = VIEW_H - HUD - 18;
    ctx.fillStyle = theme.board;
    ctx.fillRect(bx, byy, bw, bh);
    ctx.strokeStyle = theme.line;
    ctx.lineWidth = 3;
    ctx.strokeRect(bx, byy, bw, bh);

    // centre dashes
    ctx.strokeStyle = 'rgba(255,255,255,0.22)';
    ctx.lineWidth = 4;
    ctx.setLineDash([16, 18]);
    ctx.beginPath();
    ctx.moveTo(VIEW_W / 2, byy + 6);
    ctx.lineTo(VIEW_W / 2, byy + bh - 6);
    ctx.stroke();
    ctx.setLineDash([]);

    ctx.fillStyle = '#5be3a0';                 // bright on the dark court, both themes
    ctx.fillRect(60, this._py, PW, PH);
    ctx.fillStyle = '#ffb454';
    ctx.fillRect(VIEW_W - 60 - PW, this._ay, PW, PH);

    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.arc(this._bx, this._by, BR, 0, Math.PI * 2);
    ctx.fill();

    // HUD
    ctx.fillStyle = theme.hud;
    ctx.fillRect(0, 0, VIEW_W, HUD);
    ctx.fillStyle = theme.line;
    ctx.fillRect(0, HUD - 1, VIEW_W, 1);
    ctx.fillStyle = theme.hud_text;
    ctx.font = '700 32px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(`${this._you}   –   ${this._cpu}`, VIEW_W / 2, HUD / 2);
    ctx.font = '500 20px system-ui, sans-serif';
    ctx.textAlign = 'right';
    ctx.fillText(`first to ${TARGET}  ·  Level ${this._level + 1}/${LEVELS.length} – ${LEVELS[this._level].name}`, VIEW_W - 20, HUD / 2);

    this._overlay.render(ctx, VIEW_W, VIEW_H);
  }
}
