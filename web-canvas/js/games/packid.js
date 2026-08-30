// packid.js — gentle maze muncher. Steer with arrows or swipes, eat every
// cherry, dodge the wandering fruit. A bump just resets your spot.

import { Scene, VIEW_W, VIEW_H, img, playSound } from '../engine.js';
import { roundRect, inRect, Overlay, buttonRow, hudSpeakButton, hudSpeakHit, speakHud } from '../util.js';
import { theme } from '../theme.js';

const TILE = 40;
const HUD_H = 64;

const LEVELS = [
  { name: 'Sunny',  cols: 15, rows: 11, ghosts: 1, pac: 132, ghost: 74 },
  { name: 'Breezy', cols: 19, rows: 13, ghosts: 2, pac: 140, ghost: 84 },
  { name: 'Zippy',  cols: 23, rows: 13, ghosts: 2, pac: 150, ghost: 96 },
];

const DIRS = [[1, 0], [-1, 0], [0, 1], [0, -1]];
const GHOST_PICS = ['sprites/packid/appel', 'sprites/packid/banaan', 'sprites/packid/citroen'];
const key = (c) => `${c.x},${c.y}`;

const SND_EAT = 'sfx/waka.wav';
const SND_BUMP = 'sfx/bump.wav';
const SND_WIN = 'sfx/finlevel.wav';

export default class PackidGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._overlay = new Overlay();
    this._level = 0;
    this._startLevel(0);
  }

  _startLevel(n) {
    this._level = Math.max(0, Math.min(n, LEVELS.length - 1));
    const lv = LEVELS[this._level];
    this._cols = lv.cols;
    this._rows = lv.rows;
    this._score = 0;
    this._oops = 0;
    this._resetT = 0;
    this._overlay.hide();

    // pillar maze: border + a wall every 3rd col on even rows
    this._wall = [];
    for (let y = 0; y < this._rows; y++) {
      const line = [];
      for (let x = 0; x < this._cols; x++) {
        const border = x === 0 || y === 0 || x === this._cols - 1 || y === this._rows - 1;
        const pillar = x % 3 === 2 && y % 2 === 0;
        line.push(border || pillar);
      }
      this._wall.push(line);
    }

    this._pStart = this._nearestOpen((this._cols / 2) | 0, this._rows - 2);
    this._gStarts = [];
    for (let i = 0; i < lv.ghosts; i++) {
      this._gStarts.push(this._nearestOpen(((this._cols / 2) | 0) + (i - 1) * 2, 1 + i * 2));
    }

    // cherries on every open cell except spawns
    this._dots = [];
    const taken = new Set([key(this._pStart), ...this._gStarts.map(key)]);
    for (let y = 0; y < this._rows; y++) {
      this._dots.push([]);
      for (let x = 0; x < this._cols; x++) {
        this._dots[y].push(!this._wall[y][x] && !taken.has(`${x},${y}`));
      }
    }
    this._dotsLeft = this._dots.flat().filter(Boolean).length;

    this._geo();

    this._pac = this._actor(this._pStart, lv.pac);
    this._pac.want = null;
    this._pac.mouth = 0;
    this._ghosts = this._gStarts.map((s, i) => {
      const g = this._actor(s, lv.ghost);
      g.pic = GHOST_PICS[i % GHOST_PICS.length];
      return g;
    });
  }

  _geo() {
    const mw = this._cols * TILE;
    const mh = this._rows * TILE;
    this._ox = (VIEW_W - mw) / 2;
    this._oy = HUD_H + (VIEW_H - HUD_H - mh) / 2;
  }

  _actor(cell, speed) {
    return {
      x: cell.x, y: cell.y,           // grid coords
      dir: [0, 0], speed,
      moving: false, t: 0, dur: 0,
      fx: cell.x, fy: cell.y,          // interpolated grid-space position
    };
  }

  _isWall(x, y) {
    return x < 0 || y < 0 || x >= this._cols || y >= this._rows || this._wall[y][x];
  }

  _nearestOpen(tx, ty) {
    if (!this._isWall(tx, ty)) return { x: tx, y: ty };
    for (let r = 1; r < Math.max(this._cols, this._rows); r++) {
      for (let dy = -r; dy <= r; dy++) {
        for (let dx = -r; dx <= r; dx++) {
          if (!this._isWall(tx + dx, ty + dy)) return { x: tx + dx, y: ty + dy };
        }
      }
    }
    return { x: 1, y: 1 };
  }

  // --- movement ---
  _startMove(a, dir) {
    if (dir[0] === 0 && dir[1] === 0) return false;
    const nx = a.x + dir[0];
    const ny = a.y + dir[1];
    if (this._isWall(nx, ny)) return false;
    a.dir = dir;
    a.tx = nx; a.ty = ny;
    a.t = 0;
    a.dur = TILE / a.speed;
    a.moving = true;
    return true;
  }

  _stepActor(a, dt, chooseNext) {
    if (a.moving) {
      a.t += dt;
      const k = Math.min(a.t / a.dur, 1);
      a.fx = a.x + (a.tx - a.x) * k;
      a.fy = a.y + (a.ty - a.y) * k;
      if (k >= 1) {
        a.x = a.tx; a.y = a.ty;
        a.fx = a.x; a.fy = a.y;
        a.moving = false;
        chooseNext();
      }
    } else {
      chooseNext();
    }
  }

  _pacNext() {
    if (this._pac.want && this._startMove(this._pac, this._pac.want)) return;
    if (!this._startMove(this._pac, this._pac.dir)) this._pac.dir = [0, 0];
  }

  _ghostNext(g) {
    const opts = DIRS.filter(
      (d) => !(d[0] === -g.dir[0] && d[1] === -g.dir[1]) && !this._isWall(g.x + d[0], g.y + d[1])
    );
    let choice = null;
    if (opts.length) {
      const straight = opts.find((d) => d[0] === g.dir[0] && d[1] === g.dir[1]);
      choice = straight && Math.random() < 0.6 ? straight : opts[(Math.random() * opts.length) | 0];
    } else if (!this._isWall(g.x - g.dir[0], g.y - g.dir[1])) {
      choice = [-g.dir[0], -g.dir[1]];
    }
    if (choice) this._startMove(g, choice);
  }

  update(dt) {
    if (this._overlay.visible) return;

    if (this._resetT > 0) {
      this._resetT -= dt;
      if (this._resetT <= 0) this._respawn();
      return;
    }

    this._stepActor(this._pac, dt, () => {
      this._pacNext();
      const { x, y } = this._pac;
      if (this._dots[y] && this._dots[y][x]) {
        this._dots[y][x] = false;
        this._dotsLeft--;
        this._score++;
        playSound(SND_EAT, { volume: 0.6 });
        if (this._dotsLeft === 0) this._win();
      }
    });
    if (this._pac.moving) this._pac.mouth = (this._pac.mouth + dt * 8) % 2;

    for (const g of this._ghosts) this._stepActor(g, dt, () => this._ghostNext(g));

    for (const g of this._ghosts) {
      if (Math.hypot(this._pac.fx - g.fx, this._pac.fy - g.fy) < 0.7) {
        this._caught();
        break;
      }
    }
  }

  _caught() {
    this._resetT = 0.9;
    this._oops++;
    playSound(SND_BUMP);
  }

  _respawn() {
    Object.assign(this._pac, this._actor(this._pStart, this._pac.speed));
    this._pac.want = null;
    this._ghosts.forEach((g, i) => {
      const pic = g.pic;
      Object.assign(g, this._actor(this._gStarts[i], g.speed));
      g.pic = pic;
    });
  }

  _win() {
    playSound(SND_WIN, { channel: 'music' });
    const last = this._level >= LEVELS.length - 1;
    const rows = [['Replay', 'replay'], ['Menu', 'menu']];
    if (!last) rows.unshift(['Next Level', 'next']);
    this._overlay.show(`Yummy!\nscore ${this._score}   oops ${this._oops}`,
      buttonRow(rows, VIEW_W / 2, VIEW_H / 2 + 20, 190));
  }

  // --- input ---
  keydown(e) {
    const map = { ArrowRight: [1, 0], ArrowLeft: [-1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] };
    if (map[e.key]) { this._pac.want = map[e.key]; e.preventDefault(); }
  }

  pointerdown(x, y) {
    this._sw = { x, y };
  }

  pointermove(x, y) { this._overlay.pointermove(x, y); }

  pointerup(x, y) {
    if (hudSpeakHit(x, y)) return speakHud();
    if (this._overlay.visible) {
      const act = this._overlay.pointerup(x, y);
      if (act === 'next') this._startLevel(this._level + 1);
      else if (act === 'replay') this._startLevel(this._level);
      else if (act === 'menu') this._exit();
      return;
    }
    if (!this._sw) return;
    const dx = x - this._sw.x;
    const dy = y - this._sw.y;
    this._sw = null;
    if (Math.hypot(dx, dy) < 28) return;
    this._pac.want = Math.abs(dx) > Math.abs(dy)
      ? [Math.sign(dx), 0]
      : [0, Math.sign(dy)];
  }

  render(ctx) {
    ctx.fillStyle = theme.bg;
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    const brick = img('sprites/packid/brick');
    const kers = img('sprites/packid/kers');
    ctx.save();
    ctx.translate(this._ox, this._oy);

    for (let y = 0; y < this._rows; y++) {
      for (let x = 0; x < this._cols; x++) {
        if (this._wall[y][x]) {
          if (brick) ctx.drawImage(brick, x * TILE, y * TILE, TILE, TILE);
          else { ctx.fillStyle = theme.accent; ctx.fillRect(x * TILE, y * TILE, TILE, TILE); }
        } else if (this._dots[y][x]) {
          if (kers) ctx.drawImage(kers, x * TILE + TILE * 0.28, y * TILE + TILE * 0.28, TILE * 0.44, TILE * 0.44);
          else { ctx.fillStyle = theme.bad; ctx.beginPath(); ctx.arc(x * TILE + TILE / 2, y * TILE + TILE / 2, 5, 0, 7); ctx.fill(); }
        }
      }
    }

    // ghosts
    for (const g of this._ghosts) {
      const gi = img(g.pic);
      const px = g.fx * TILE + TILE / 2;
      const py = g.fy * TILE + TILE / 2;
      if (gi) ctx.drawImage(gi, px - TILE * 0.42, py - TILE * 0.42, TILE * 0.84, TILE * 0.84);
      else { ctx.fillStyle = '#ff884d'; ctx.beginPath(); ctx.arc(px, py, TILE * 0.4, 0, 7); ctx.fill(); }
    }

    // pac
    const caught = this._resetT > 0;
    let sprite = 'sprites/packid/pac_sad';
    if (!caught) {
      const d = this._pac.dir;
      const face = d[0] > 0 ? 'r' : d[0] < 0 ? 'l' : d[1] < 0 ? 'u' : d[1] > 0 ? 'd' : 'r';
      sprite = `packid/pac_${face}${this._pac.mouth >= 1 ? '_c' : ''}.png`;
    }
    const pi = img(sprite);
    const ppx = this._pac.fx * TILE + TILE / 2;
    const ppy = this._pac.fy * TILE + TILE / 2;
    if (pi) ctx.drawImage(pi, ppx - TILE * 0.44, ppy - TILE * 0.44, TILE * 0.88, TILE * 0.88);
    else { ctx.fillStyle = '#ffd93d'; ctx.beginPath(); ctx.arc(ppx, ppy, TILE * 0.42, 0, 7); ctx.fill(); }

    ctx.restore();

    // HUD
    ctx.fillStyle = theme.hud;
    ctx.fillRect(0, 0, VIEW_W, HUD_H);
    ctx.fillStyle = theme.line;
    ctx.fillRect(0, HUD_H - 1, VIEW_W, 1);
    ctx.fillStyle = theme.hud_text;
    ctx.font = '600 24px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(`Score ${this._score}    Cherries left ${this._dotsLeft}    Oops ${this._oops}`, VIEW_W / 2, HUD_H / 2);
    ctx.textAlign = 'right';
    ctx.fillText(`Level ${this._level + 1}/${LEVELS.length}`, VIEW_W - 24, HUD_H / 2);

    this._overlay.render(ctx, VIEW_W, VIEW_H);
  }
}
