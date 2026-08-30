// blockbreaker.js — a gentle Breakout. Slide the paddle, bounce the ball,
// clear every brick. Losing the ball costs a life, not the game; run out
// and you just replay the wall. Six walls, then you win.

import { Scene, VIEW_W, VIEW_H, playSound } from '../engine.js';
import { clamp, Overlay, buttonRow, hudSpeakButton, hudSpeakHit, speakHud } from '../util.js';
import { theme } from '../theme.js';

const HUD = 64;
const SIDE = 44;                 // left/right margin of the brick field
const COLS = 11;
const BRICK_H = 28;
const BRICK_TOP = HUD + 42;
const PAD_W = 150;
const PAD_H = 16;
const PAD_Y_OFF = 58;           // paddle distance from the bottom
const BALL_R = 9;
const BASE_SPEED = 430;
const SPEED_PER_LEVEL = 28;
const MAX_BOUNCE = 62 * (Math.PI / 180);   // paddle-edge deflection
const MIN_BOUNCE = 19 * (Math.PI / 180);   // never leave the paddle vertical
const MIN_VX_FRAC = 0.18;       // after a brick/wall hit, keep a real sideways sweep
const MIN_VY_FRAC = 0.26;       // ...and a real climb, so it can't hug a surface
const LIVES = 3;
const SUBSTEPS = 3;

// Brick palette. '#' is a tough brick (two hits); '.' is a gap.
const TINTS = {
  r: '#ff6b6b', o: '#ff9838', y: '#ffd93d', g: '#5fce6b',
  b: '#4d96ff', p: '#b980f0', c: '#33c2d6',
};
const TOUGH = '#8a94a6';
const TOUGH_HIT = '#5b6270';

// 11-wide wall layouts, top row first. Each string is exactly COLS chars.
const LEVELS = [
  ['ggggggggggg',
   'ooooooooooo'],
  ['o.o.o.o.o.o',
   'rrrrrrrrrrr',
   'o.o.o.o.o.o'],
  ['bbbbbbbbbbb',
   'ccccccccccc',
   'bbbbbbbbbbb'],
  ['.....y.....',
   '....yoy....',
   '...yo#oy...',
   '..yo#g#oy..'],
  ['#.#.#.#.#.#',
   'ggggggggggg',
   'ppppppppppp'],
  ['##.......##',
   '#o#.....#o#',
   '#o#.....#o#',
   '##.......##',
   '.#########.'],
];

const SND_LAUNCH = 'sfx/sndh.wav';
const SND_WALL = 'sfx/bump.wav';
const SND_PAD = 'sfx/sndt.wav';
const SND_BRICK = 'sfx/pick.wav';
const SND_LOSE = 'sfx/bummer.wav';
const SND_CLEAR = 'sfx/finlevel.wav';
const SND_WIN = 'sfx/winner.ogg';

export default class BlockBreakerGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._overlay = new Overlay();
    this._level = 0;
    this._keys = { left: false, right: false };
    this._startLevel(0);
  }

  _startLevel(n) {
    this._level = clamp(n, 0, LEVELS.length - 1);
    this._lives = LIVES;
    this._over = false;
    this._won = false;
    this._overlay.hide();
    this._geo();
    this._buildBricks();
    this._resetBall();
  }

  // --- layout for the current world size --------------------------------
  _geo() {
    this._fieldW = VIEW_W - SIDE * 2;
    this._brickW = this._fieldW / COLS;
    this._padY = VIEW_H - PAD_Y_OFF;
    if (this._padX == null) this._padX = (VIEW_W - PAD_W) / 2;
    this._padX = clamp(this._padX, 0, VIEW_W - PAD_W);
  }

  _buildBricks() {
    const rows = LEVELS[this._level];
    this._bricks = [];
    rows.forEach((row, r) => {
      for (let c = 0; c < COLS; c++) {
        const ch = row[c] || '.';
        if (ch === '.') continue;
        const tough = ch === '#';
        this._bricks.push({
          c, r, tough,
          hp: tough ? 2 : 1,
          color: tough ? TOUGH : (TINTS[ch] || theme.text_muted),
          alive: true,
        });
      }
    });
  }

  _brickRect(b) {
    const x = SIDE + b.c * this._brickW;
    const y = BRICK_TOP + b.r * (BRICK_H + 6);
    return { x: x + 3, y: y + 3, w: this._brickW - 6, h: BRICK_H };
  }

  _resetBall() {
    this._stuck = true;
    this._speed = BASE_SPEED + this._level * SPEED_PER_LEVEL;
    this._bx = this._padX + PAD_W / 2;
    this._by = this._padY - BALL_R - 1;
    this._bvx = 0;
    this._bvy = 0;
  }

  _launch() {
    if (!this._stuck || this._over) return;
    this._stuck = false;
    const ang = (-60 + Math.random() * 120) * (Math.PI / 180); // fan upward
    this._bvx = Math.sin(ang) * this._speed;
    this._bvy = -Math.abs(Math.cos(ang) * this._speed);
    playSound(SND_LAUNCH);
  }

  resize() {
    this._geo();
    if (this._stuck) this._resetBall();
    this._overlay.reflow(VIEW_W / 2, VIEW_H / 2 + 20);
  }

  // --- input -----------------------------------------------------------
  keydown(e) {
    if (e.key === 'ArrowLeft') this._keys.left = true;
    else if (e.key === 'ArrowRight') this._keys.right = true;
    else if (e.key === ' ' || e.key === 'Enter') this._launch();
  }
  keyup(e) {
    if (e.key === 'ArrowLeft') this._keys.left = false;
    else if (e.key === 'ArrowRight') this._keys.right = false;
  }

  pointerdown(x, y) { this._aimPaddle(x); this._ptr = x; }
  pointermove(x, y) {
    this._overlay.pointermove(x, y);
    if (this._ptr != null) this._aimPaddle(x);
  }
  pointerup(x, y) {
    if (hudSpeakHit(x, y)) return speakHud();
    this._ptr = null;
    if (this._overlay.visible) {
      const act = this._overlay.pointerup(x, y);
      if (act === 'next') this._startLevel(this._level + 1);
      else if (act === 'replay') this._startLevel(this._level);
      else if (act === 'menu') this._exit();
      return;
    }
    this._launch();
  }

  _aimPaddle(x) {
    this._padX = clamp(x - PAD_W / 2, 0, VIEW_W - PAD_W);
  }

  // --- simulation ----------------------------------------------------
  update(dt) {
    if (this._over) return;

    const kv = (this._keys.right ? 1 : 0) - (this._keys.left ? 1 : 0);
    if (kv) this._padX = clamp(this._padX + kv * 620 * dt, 0, VIEW_W - PAD_W);

    if (this._stuck) {
      this._bx = this._padX + PAD_W / 2;
      this._by = this._padY - BALL_R - 1;
      return;
    }

    const h = dt / SUBSTEPS;
    for (let s = 0; s < SUBSTEPS && !this._over; s++) this._step(h);
  }

  _step(h) {
    this._bx += this._bvx * h;
    this._by += this._bvy * h;

    // walls
    if (this._bx - BALL_R < 0) { this._bx = BALL_R; this._bvx = Math.abs(this._bvx); playSound(SND_WALL); }
    else if (this._bx + BALL_R > VIEW_W) { this._bx = VIEW_W - BALL_R; this._bvx = -Math.abs(this._bvx); playSound(SND_WALL); }
    if (this._by - BALL_R < HUD) { this._by = HUD + BALL_R; this._bvy = Math.abs(this._bvy); playSound(SND_WALL); }

    // paddle — deflection is set purely by where the ball lands on it
    if (this._bvy > 0 &&
        this._by + BALL_R >= this._padY && this._by - BALL_R <= this._padY + PAD_H &&
        this._bx >= this._padX - BALL_R && this._bx <= this._padX + PAD_W + BALL_R) {
      this._by = this._padY - BALL_R;
      const rel = clamp((this._bx - (this._padX + PAD_W / 2)) / (PAD_W / 2), -1, 1);
      let ang = rel * MAX_BOUNCE;
      if (Math.abs(ang) < MIN_BOUNCE) {
        // near-centre hit: keep sweeping the way we were already going so
        // the ball can't settle into a stationary near-vertical bounce
        const dir = Math.abs(rel) > 0.05 ? Math.sign(rel) : (this._bvx >= 0 ? 1 : -1);
        ang = dir * MIN_BOUNCE;
      }
      this._bvx = Math.sin(ang) * this._speed;
      this._bvy = -Math.cos(ang) * this._speed;
      playSound(SND_PAD);
    }

    // bricks — reflect off the first one hit this step
    for (const b of this._bricks) {
      if (!b.alive) continue;
      const r = this._brickRect(b);
      const cx = clamp(this._bx, r.x, r.x + r.w);
      const cy = clamp(this._by, r.y, r.y + r.h);
      const dx = this._bx - cx;
      const dy = this._by - cy;
      if (dx * dx + dy * dy > BALL_R * BALL_R) continue;

      if (Math.abs(dx) > Math.abs(dy)) {
        this._bvx = dx >= 0 ? Math.abs(this._bvx) : -Math.abs(this._bvx);
        this._bx += this._bvx >= 0 ? (BALL_R - Math.abs(dx)) : -(BALL_R - Math.abs(dx));
      } else {
        this._bvy = dy >= 0 ? Math.abs(this._bvy) : -Math.abs(this._bvy);
        this._by += this._bvy >= 0 ? (BALL_R - Math.abs(dy)) : -(BALL_R - Math.abs(dy));
      }

      this._clampAngle();

      b.hp -= 1;
      if (b.hp <= 0) {
        b.alive = false;
        playSound(SND_BRICK);
      } else {
        b.color = TOUGH_HIT;
        playSound(SND_PAD, { volume: 0.6 });
      }
      if (!this._bricks.some((x) => x.alive)) this._clearLevel();
      break;
    }

    // lost the ball
    if (this._by - BALL_R > VIEW_H) this._loseBall();
  }

  // After a brick reflection, keep both components meaningful (never let
  // the ball settle into a near-vertical or near-horizontal loop) and
  // restore the exact speed.
  _clampAngle() {
    const sx = this._bvx < 0 ? -1 : 1;
    const sy = this._bvy < 0 ? -1 : 1;
    let vx = Math.abs(this._bvx);
    let vy = Math.abs(this._bvy);
    vx = Math.max(vx, this._speed * MIN_VX_FRAC);
    vy = Math.max(vy, this._speed * MIN_VY_FRAC);
    const k = this._speed / (Math.hypot(vx, vy) || 1);
    this._bvx = sx * vx * k;
    this._bvy = sy * vy * k;
  }

  _loseBall() {
    this._lives -= 1;
    if (this._lives > 0) {
      playSound(SND_LOSE);
      this._resetBall();
    } else {
      this._over = true;
      playSound(SND_LOSE);
      this._overlay.show(
        'Out of balls!\nhave another go',
        buttonRow([['Try Again', 'replay'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20),
      );
    }
  }

  _clearLevel() {
    this._over = true;
    const last = this._level >= LEVELS.length - 1;
    if (last) {
      this._won = true;
      playSound(SND_WIN, { channel: 'music' });
      this._overlay.show(
        'You cleared every wall!',
        buttonRow([['Play Again', 'replay'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20),
      );
    } else {
      playSound(SND_CLEAR, { channel: 'music' });
      this._overlay.show(
        `Wall ${this._level + 1} cleared!`,
        buttonRow([['Next Wall', 'next'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20),
      );
    }
  }

  // --- render --------------------------------------------------------
  render(ctx) {
    ctx.fillStyle = theme.bg;
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    // play field is a fixed dark panel, framed against the page
    const fx = 8, fw = VIEW_W - 16, fy = HUD + 6, fh = VIEW_H - HUD - 14;
    ctx.fillStyle = theme.board;
    ctx.fillRect(fx, fy, fw, fh);
    ctx.strokeStyle = theme.line;
    ctx.lineWidth = 3;
    ctx.strokeRect(fx, fy, fw, fh);

    for (const b of this._bricks) {
      if (!b.alive) continue;
      const r = this._brickRect(b);
      ctx.fillStyle = b.color;
      ctx.fillRect(r.x, r.y, r.w, r.h);
      ctx.fillStyle = 'rgba(255,255,255,0.18)';
      ctx.fillRect(r.x, r.y, r.w, 4);
      if (b.tough && b.hp > 1) {
        ctx.strokeStyle = 'rgba(255,255,255,0.5)';
        ctx.lineWidth = 2;
        ctx.strokeRect(r.x + 3, r.y + 3, r.w - 6, r.h - 6);
      }
    }

    // paddle
    ctx.fillStyle = '#ffd93d';
    ctx.beginPath();
    if (ctx.roundRect) ctx.roundRect(this._padX, this._padY, PAD_W, PAD_H, 8);
    else ctx.rect(this._padX, this._padY, PAD_W, PAD_H);
    ctx.fill();

    // ball — bright on the dark field in either theme
    ctx.fillStyle = '#ff6b6b';
    ctx.beginPath();
    ctx.arc(this._bx, this._by, BALL_R, 0, Math.PI * 2);
    ctx.fill();

    // HUD
    ctx.fillStyle = theme.hud;
    ctx.fillRect(0, 0, VIEW_W, HUD);
    ctx.fillStyle = theme.line;
    ctx.fillRect(0, HUD - 1, VIEW_W, 1);
    ctx.fillStyle = theme.hud_text;
    ctx.font = '600 22px system-ui, sans-serif';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    const left = this._bricks.filter((b) => b.alive).length;
    ctx.fillText(`Wall ${this._level + 1}/${LEVELS.length}   ·   bricks left ${left}`, 200, HUD / 2);
    ctx.textAlign = 'center';
    ctx.fillStyle = theme.hud_muted;
    const _msg = this._stuck ? 'tap or press space to launch' : 'slide to move the paddle';
    ctx.fillText(_msg, VIEW_W / 2, HUD / 2);
    hudSpeakButton(ctx, _msg, VIEW_W / 2, HUD / 2);
    ctx.textAlign = 'right';
    ctx.fillStyle = theme.bad;
    ctx.font = '600 20px system-ui, sans-serif';
    ctx.fillText('●'.repeat(this._lives) + '○'.repeat(LIVES - this._lives), VIEW_W - 20, HUD / 2);

    this._overlay.render(ctx, VIEW_W, VIEW_H);
  }
}
