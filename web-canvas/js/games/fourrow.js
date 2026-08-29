// fourrow.js — Connect Four. Solo vs the computer (3 skill levels), or a
// local "pass & play" 2-player game (Design Policy §K). Player 1 is red and
// goes first; drop a disc into a column, get four in a line.

import { Scene, VIEW_W, VIEW_H, playSound } from '../engine.js';
import { clamp, Overlay, buttonRow, hudSpeakButton, hudSpeakHit, speakHud } from '../util.js';
import { theme, DARK } from '../theme.js';

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
const KEY_2P = 'cp:fourrow:2p';

export default class FourRowGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._overlay = new Overlay();
    this._level = 0;
    try { this._twoP = localStorage.getItem(KEY_2P) === '1'; } catch { this._twoP = false; }
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
    this._moves = 0;
    this._aiTimer = null;
    this._overlay.hide();
    this._geo();
  }

  _geo() {
    const cell = Math.min(96, (VIEW_H - HUD - 40) / ROWS, (VIEW_W - 80) / COLS);
    this._cell = cell;
    this._bx = (VIEW_W - cell * COLS) / 2;
    this._by = HUD + (VIEW_H - HUD - cell * ROWS) / 2;
    this._r = cell * 0.4;
    this._modeBtn = { x: VIEW_W - 92, y: 14, w: 76, h: 36 };
  }
  resize() { this._geo(); }

  _colX(c) { return this._bx + c * this._cell + this._cell / 2; }
  _rowY(r) { return this._by + r * this._cell + this._cell / 2; }
  _lowest(c) { for (let r = ROWS - 1; r >= 0; r--) if (!this._grid[r][c]) return r; return -1; }

  _setTwoP(on) {
    this._twoP = on;
    try { localStorage.setItem(KEY_2P, on ? '1' : '0'); } catch { /* */ }
    this._startLevel(this._level);
  }

  update(dt) {
    if (!this._twoP && this._aiTimer != null && !this._drop && !this._over) {
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
      this._moves += 1;
      playSound(SND_DROP);
      const line = this._four(who);
      if (line) return this._end(who, line);
      if (this._grid[0].every((v) => v)) return this._end(0, null);
      this._turn = who === RED ? YEL : RED;
      if (!this._twoP && this._turn === YEL) this._aiTimer = 0.45;
    }
  }

  // --- AI (solo only) ---
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
    const p1Won = who === RED;
    playSound(who === 0 ? SND_LOSS : (this._twoP || p1Won) ? SND_WIN : SND_LOSS, { channel: 'music' });
    const last = this._level >= LEVELS.length - 1;
    const rows = [['Play Again', 'replay'], ['Menu', 'menu']];
    if (!this._twoP && p1Won && !last) rows.unshift(['Next Level', 'next']);
    let msg;
    if (who === 0) msg = "It's a draw!";
    else if (this._twoP) msg = who === RED ? 'Red wins!' : 'Yellow wins!';
    else msg = p1Won ? 'You got four!' : 'Computer wins!';
    this._overlay.show(msg, buttonRow(rows, VIEW_W / 2, VIEW_H / 2 + 20, 190));
  }

  // --- input ---
  pointermove(x, y) {
    this._overlay.pointermove(x, y);
    this._hoverCol = clamp(Math.floor((x - this._bx) / this._cell), -1, COLS - 1);
    if (x < this._bx || x > this._bx + this._cell * COLS) this._hoverCol = -1;
  }

  pointerup(x, y) {
    if (hudSpeakHit(x, y)) return speakHud();
    if (this._overlay.visible) {
      const act = this._overlay.pointerup(x, y);
      if (act === 'next') this._startLevel(this._level + 1);
      else if (act === 'replay') this._startLevel(this._level);
      else if (act === 'menu') this._exit();
      return;
    }
    // mode toggle — only before the first move of a game
    if (this._moves === 0 && !this._drop &&
        x >= this._modeBtn.x && x <= this._modeBtn.x + this._modeBtn.w &&
        y >= this._modeBtn.y && y <= this._modeBtn.y + this._modeBtn.h) {
      return this._setTwoP(!this._twoP);
    }
    if (this._over || this._drop) return;
    if (!this._twoP && this._turn !== RED) return;   // solo: wait for the AI
    const c = Math.floor((x - this._bx) / this._cell);
    if (c >= 0 && c < COLS && this._lowest(c) >= 0) this._place(c, this._turn);
  }

  render(ctx) {
    ctx.fillStyle = theme.bg;
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    const { _bx: bx, _by: by, _cell: cell, _r: r } = this;
    const discColour = (v) => (v === RED ? theme.p1 : v === YEL ? theme.p2 : theme.bg);

    // ghost / hover disc
    const canHover = !this._over && !this._drop && (this._twoP || this._turn === RED);
    if (this._hoverCol >= 0 && canHover && this._lowest(this._hoverCol) >= 0) {
      ctx.globalAlpha = 0.35;
      ctx.fillStyle = discColour(this._turn);
      ctx.beginPath();
      ctx.arc(this._colX(this._hoverCol), by - cell / 2, r, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalAlpha = 1;
    }

    // board
    ctx.fillStyle = theme.surface_alt;
    ctx.fillRect(bx - 8, by - 8, cell * COLS + 16, cell * ROWS + 16);
    for (let rr = 0; rr < ROWS; rr++) {
      for (let cc = 0; cc < COLS; cc++) {
        ctx.beginPath();
        ctx.arc(this._colX(cc), this._rowY(rr), r, 0, Math.PI * 2);
        ctx.fillStyle = discColour(this._grid[rr][cc]);
        ctx.fill();
      }
    }

    if (this._drop) {
      ctx.beginPath();
      ctx.arc(this._colX(this._drop.col), this._drop.y, r, 0, Math.PI * 2);
      ctx.fillStyle = discColour(this._drop.who);
      ctx.fill();
    }

    if (this._winLine) {
      ctx.strokeStyle = theme.good;
      ctx.lineWidth = 8;
      ctx.lineCap = 'round';
      const [a, b] = [this._winLine[0], this._winLine[3]];
      ctx.beginPath();
      ctx.moveTo(this._colX(a[1]), this._rowY(a[0]));
      ctx.lineTo(this._colX(b[1]), this._rowY(b[0]));
      ctx.stroke();
    }

    // HUD (dark chrome strip, light text in both themes)
    ctx.fillStyle = 'rgba(14,19,28,0.82)';
    ctx.fillRect(0, 0, VIEW_W, HUD);
    ctx.fillStyle = DARK.text;
    ctx.font = '600 22px system-ui, sans-serif';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    ctx.fillText(this._twoP ? '2 players' : `Level ${this._level + 1}/${LEVELS.length} – ${LEVELS[this._level].name}`, 24, HUD / 2);
    ctx.textAlign = 'center';
    const _msg = this._over ? 'game over'
      : this._twoP ? (this._turn === RED ? "red's turn" : "yellow's turn")
      : this._turn === RED ? 'your turn (red)' : 'computer thinking…';
    ctx.fillText(_msg, VIEW_W / 2, HUD / 2);
    hudSpeakButton(ctx, _msg, VIEW_W / 2, HUD / 2);

    // mode pill (only tappable before the first move)
    const mb = this._modeBtn;
    ctx.fillStyle = this._moves === 0 ? theme.accent : 'rgba(255,255,255,0.12)';
    ctx.beginPath();
    if (ctx.roundRect) ctx.roundRect(mb.x, mb.y, mb.w, mb.h, 10);
    else ctx.rect(mb.x, mb.y, mb.w, mb.h);
    ctx.fill();
    ctx.fillStyle = '#ffffff';
    ctx.font = '600 18px system-ui, sans-serif';
    ctx.fillText(this._twoP ? '2P' : '1P', mb.x + mb.w / 2, HUD / 2);

    this._overlay.render(ctx, VIEW_W, VIEW_H);
  }
}
