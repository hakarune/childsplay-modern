// fourrow.js — Connect Four against the computer. You are red and go
// first; drop a disc into a column, get four in a row.

import { Scene, VIEW_W, VIEW_H, playSound } from '../engine.js';
import { clamp, Overlay, buttonRow } from '../util.js';

const COLS = 7, ROWS = 6;
const HUD = 64;
const RED = 1, YEL = 2;

const LEVELS = [
  { name: 'Easy', smart: 0.35 },
  { name: 'Tricky', smart: 0.75 },
  { name: 'Sharp', smart: 1.0 },
];

const SND_DROP = 'sfx/pick.wav';
const SND_WIN = 'sfx/fourrow_win.ogg';
const SND_LOSS = 'sfx/fourrow_loss.ogg';

export default class FourRowGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._overlay = new Overlay();
    this._level = 0;
    this._startLevel(0);
  }

  _startLevel(n) {
    this._level = Math.max(0, Math.min(n, LEVELS.length - 1));
    this._grid = Array.from({ length: ROWS }, () => Array(COLS).fill(0));
    this._turn = RED;
    this._over = false;
    this._winLine = null;
    this._drop = null;              // { col, row, y, vy, who } falling disc
    this._hoverCol = -1;
    this._overlay.hide();
    this._geo();
  }

  _geo() {
    const cell = Math.min(96, (VIEW_H - HUD - 40) / ROWS, (VIEW_W - 80) / COLS);
    this._cell = cell;
    this._bx = (VIEW_W - cell * COLS) / 2;
    this._by = HUD + (VIEW_H - HUD - cell * ROWS) / 2;
    this._r = cell * 0.4;
  }
  resize() { this._geo(); }

  _colX(c) { return this._bx + c * this._cell + this._cell / 2; }
  _rowY(r) { return this._by + r * this._cell + this._cell / 2; }
  _lowest(c) { for (let r = ROWS - 1; r >= 0; r--) if (!this._grid[r][c]) return r; return -1; }

  update(dt) {
    if (this._aiTimer != null && !this._drop && !this._over) {
      this._aiTimer -= dt;
      if (this._aiTimer <= 0) { this._aiTimer = null; this._aiMove(); }
    }
    if (!this._drop) return;
    const d = this._drop;
    d.vy += 2600 * dt;
    d.y += d.vy * dt;
    const restY = this._rowY(d.row);
    if (d.y >= restY) {
      d.y = restY;
      this._grid[d.row][d.col] = d.who;
      const who = d.who;
      this._drop = null;
      playSound(SND_DROP);
      const line = this._four(who);
      if (line) return this._end(who, line);
      if (this._grid[0].every((v) => v)) return this._end(0, null);
      this._turn = who === RED ? YEL : RED;
      if (this._turn === YEL) this._aiTimer = 0.45;
    }
  }

  // --- AI ---
  _aiMove() {
    const smart = LEVELS[this._level].smart;
    const cols = [...Array(COLS).keys()].filter((c) => this._lowest(c) >= 0);
    if (!cols.length) return;
    if (Math.random() < smart) {
      const win = cols.find((c) => this._wouldWin(c, YEL));
      if (win != null) return this._place(win, YEL);
      const block = cols.find((c) => this._wouldWin(c, RED));
      if (block != null) return this._place(block, YEL);
    }
    const weight = cols.map((c) => 4 - Math.abs(c - 3) + Math.random() * 2);
    const best = cols[weight.indexOf(Math.max(...weight))];
    this._place(best, YEL);
  }

  _wouldWin(c, who) {
    const r = this._lowest(c);
    if (r < 0) return false;
    this._grid[r][c] = who;
    const w = !!this._four(who);
    this._grid[r][c] = 0;
    return w;
  }

  _place(col, who) {
    const row = this._lowest(col);
    if (row < 0 || this._drop || this._over) return;
    this._drop = { col, row, y: this._by - this._cell / 2, vy: 0, who };
  }

  // --- win detection ---
  _four(who) {
    const g = this._grid;
    const dirs = [[0, 1], [1, 0], [1, 1], [1, -1]];
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        if (g[r][c] !== who) continue;
        for (const [dr, dc] of dirs) {
          const cells = [[r, c]];
          for (let k = 1; k < 4; k++) {
            const nr = r + dr * k, nc = c + dc * k;
            if (nr < 0 || nr >= ROWS || nc < 0 || nc >= COLS || g[nr][nc] !== who) break;
            cells.push([nr, nc]);
          }
          if (cells.length === 4) return cells;
        }
      }
    }
    return null;
  }

  _end(who, line) {
    this._over = true;
    this._winLine = line;
    const youWon = who === RED;
    playSound(youWon ? SND_WIN : SND_LOSS, { channel: 'music' });
    const last = this._level >= LEVELS.length - 1;
    const rows = [['Play Again', 'replay'], ['Menu', 'menu']];
    if (youWon && !last) rows.unshift(['Next Level', 'next']);
    const msg = who === 0 ? "It's a draw!" : youWon ? 'You got four!' : 'Computer wins!';
    this._overlay.show(msg, buttonRow(rows, VIEW_W / 2, VIEW_H / 2 + 20, 190));
  }

  // --- input ---
  pointermove(x, y) {
    this._overlay.pointermove(x, y);
    this._hoverCol = clamp(Math.floor((x - this._bx) / this._cell), -1, COLS - 1);
    if (x < this._bx || x > this._bx + this._cell * COLS) this._hoverCol = -1;
  }

  pointerup(x, y) {
    if (this._overlay.visible) {
      const act = this._overlay.pointerup(x, y);
      if (act === 'next') this._startLevel(this._level + 1);
      else if (act === 'replay') this._startLevel(this._level);
      else if (act === 'menu') this._exit();
      return;
    }
    if (this._over || this._drop || this._turn !== RED) return;
    const c = Math.floor((x - this._bx) / this._cell);
    if (c >= 0 && c < COLS && this._lowest(c) >= 0) this._place(c, RED);
  }

  render(ctx) {
    ctx.fillStyle = '#141b2e';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    const { _bx: bx, _by: by, _cell: cell, _r: r } = this;

    // ghost / hover disc
    if (this._hoverCol >= 0 && this._turn === RED && !this._over && !this._drop && this._lowest(this._hoverCol) >= 0) {
      ctx.globalAlpha = 0.35;
      ctx.fillStyle = '#ff5a5a';
      ctx.beginPath();
      ctx.arc(this._colX(this._hoverCol), by - cell / 2, r, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalAlpha = 1;
    }

    // board
    ctx.fillStyle = '#2f57c4';
    ctx.fillRect(bx - 8, by - 8, cell * COLS + 16, cell * ROWS + 16);
    for (let rr = 0; rr < ROWS; rr++) {
      for (let cc = 0; cc < COLS; cc++) {
        const v = this._grid[rr][cc];
        ctx.beginPath();
        ctx.arc(this._colX(cc), this._rowY(rr), r, 0, Math.PI * 2);
        ctx.fillStyle = v === RED ? '#ff5a5a' : v === YEL ? '#ffd93d' : '#0e1526';
        ctx.fill();
      }
    }

    if (this._drop) {
      ctx.beginPath();
      ctx.arc(this._colX(this._drop.col), this._drop.y, r, 0, Math.PI * 2);
      ctx.fillStyle = this._drop.who === RED ? '#ff5a5a' : '#ffd93d';
      ctx.fill();
    }

    if (this._winLine) {
      ctx.strokeStyle = '#7be0a0';
      ctx.lineWidth = 8;
      ctx.lineCap = 'round';
      const [a, b] = [this._winLine[0], this._winLine[3]];
      ctx.beginPath();
      ctx.moveTo(this._colX(a[1]), this._rowY(a[0]));
      ctx.lineTo(this._colX(b[1]), this._rowY(b[0]));
      ctx.stroke();
    }

    // HUD
    ctx.fillStyle = 'rgba(16,21,32,0.6)';
    ctx.fillRect(0, 0, VIEW_W, HUD);
    ctx.fillStyle = '#eef2f7';
    ctx.font = '600 24px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(this._over ? 'game over' : this._turn === RED ? 'your turn (red)' : 'computer thinking…', VIEW_W / 2, HUD / 2);
    ctx.textAlign = 'right';
    ctx.fillText(`Level ${this._level + 1}/${LEVELS.length} – ${LEVELS[this._level].name}`, VIEW_W - 20, HUD / 2);

    this._overlay.render(ctx, VIEW_W, VIEW_H);
  }
}
