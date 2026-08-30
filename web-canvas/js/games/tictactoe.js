// tictactoe.js — noughts and crosses versus the computer. Three levels of
// opponent: Easy (random), Medium (win / block / centre), Hard (perfect
// minimax). You are X and move first. Beat Easy and Medium to advance;
// hold the perfect computer to a draw to finish.

import { Scene, VIEW_W, VIEW_H, playSound } from '../engine.js';
import { clamp, Overlay, buttonRow, hudSpeakButton, hudSpeakHit, speakHud } from '../util.js';

const HUD = 64;
const X = 1;
const O = 2;

const LEVELS = [
  { name: 'Easy', ai: 'random' },
  { name: 'Medium', ai: 'heuristic' },
  { name: 'Hard', ai: 'perfect' },
];

const LINES = [
  [0, 1, 2], [3, 4, 5], [6, 7, 8],
  [0, 3, 6], [1, 4, 7], [2, 5, 8],
  [0, 4, 8], [2, 4, 6],
];

const SND_MARK = 'sfx/pick.wav';
const SND_AI = 'sfx/dealcard1.wav';
const SND_WIN = 'sfx/winner.ogg';
const SND_LOSE = 'sfx/bummer.wav';
const SND_DRAW = 'sfx/wrong.ogg';
const KEY_2P = 'cp:tictactoe:2p';

function winner(b) {
  for (const [a, c, d] of LINES) {
    if (b[a] && b[a] === b[c] && b[a] === b[d]) return { who: b[a], line: [a, c, d] };
  }
  if (b.every((v) => v)) return { who: 0, line: null };  // draw
  return null;
}

function minimax(b, turn, me) {
  const w = winner(b);
  if (w) {
    if (w.who === 0) return 0;
    return w.who === me ? 10 : -10;
  }
  let best = turn === me ? -999 : 999;
  for (let i = 0; i < 9; i++) {
    if (b[i]) continue;
    b[i] = turn;
    const s = minimax(b, turn === X ? O : X, me);
    b[i] = 0;
    best = turn === me ? Math.max(best, s) : Math.min(best, s);
  }
  return best;
}

export default class TicTacToeGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._overlay = new Overlay();
    this._level = 0;
    try { this._twoP = localStorage.getItem(KEY_2P) === '1'; } catch { this._twoP = false; }
    this._startLevel(0);
  }

  _startLevel(n) {
    this._level = clamp(n, 0, LEVELS.length - 1);
    this._board = Array(9).fill(0);
    this._turn = X;                 // player 1 (X) always starts
    this._done = null;              // { who, line }
    this._aiWait = 0;
    this._moves = 0;
    this._modeBtn = { x: VIEW_W - 92, y: 14, w: 76, h: 36 };
    this._overlay.hide();
    this._geo();
  }

  _setTwoP(on) {
    this._twoP = on;
    try { localStorage.setItem(KEY_2P, on ? '1' : '0'); } catch { /* */ }
    this._startLevel(this._level);
  }

  _geo() {
    const s = Math.min(VIEW_W * 0.6, VIEW_H - HUD - 90);
    this._grid = { x: (VIEW_W - s) / 2, y: HUD + 30 + (VIEW_H - HUD - 30 - s) / 2, s };
    this._cell = s / 3;
  }

  resize() {
    this._geo();
    this._overlay.reflow(VIEW_W / 2, VIEW_H / 2 + 20);
  }

  // --- AI ---
  _emptyCells() {
    const e = [];
    for (let i = 0; i < 9; i++) if (!this._board[i]) e.push(i);
    return e;
  }

  _aiMove() {
    const b = this._board;
    const empty = this._emptyCells();
    if (!empty.length) return;
    const kind = LEVELS[this._level].ai;
    let pick;

    if (kind === 'random') {
      pick = empty[(Math.random() * empty.length) | 0];
    } else if (kind === 'heuristic') {
      pick = this._findLine(O) ?? this._findLine(X) ??
        (b[4] ? null : 4) ??
        this._firstOf([0, 2, 6, 8], empty) ??
        this._firstOf([1, 3, 5, 7], empty) ??
        empty[0];
    } else {
      let bestScore = -999;
      let bestMoves = [];
      for (const i of empty) {
        b[i] = O;
        const sc = minimax(b, X, O);
        b[i] = 0;
        if (sc > bestScore) { bestScore = sc; bestMoves = [i]; }
        else if (sc === bestScore) bestMoves.push(i);
      }
      pick = bestMoves[(Math.random() * bestMoves.length) | 0];
    }

    b[pick] = O;
    playSound(SND_AI, { volume: 0.6 });
    this._turn = X;
    this._checkEnd();
  }

  _firstOf(cells, empty) {
    for (const c of cells) if (empty.includes(c)) return c;
    return null;
  }

  // returns a cell that completes a line for `who`, else null
  _findLine(who) {
    for (const [a, b, c] of LINES) {
      const trio = [this._board[a], this._board[b], this._board[c]];
      const cells = [a, b, c];
      const mine = trio.filter((v) => v === who).length;
      const empty = trio.filter((v) => v === 0).length;
      if (mine === 2 && empty === 1) return cells[trio.indexOf(0)];
    }
    return null;
  }

  _checkEnd() {
    const w = winner(this._board);
    if (!w) return;
    this._done = w;
    const last = this._level >= LEVELS.length - 1;

    if (this._twoP && w.who !== 0) {
      playSound(SND_WIN, { channel: 'music' });
      this._overlay.show(w.who === X ? 'Blue wins!' : 'Orange wins!',
        buttonRow([['Play Again', 'replay'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20));
    } else if (w.who === X) {
      // player won
      playSound(SND_WIN, { channel: 'music' });
      if (last) {
        this._overlay.show('You beat the champion!',
          buttonRow([['Play Again', 'replay'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20));
      } else {
        this._overlay.show('You win!',
          buttonRow([['Next Level', 'next'], ['Replay', 'replay'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20, 170));
      }
    } else if (w.who === O) {
      playSound(SND_LOSE);
      this._overlay.show('Computer wins',
        buttonRow([['Try Again', 'replay'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20));
    } else {
      // draw
      if (last) {
        playSound(SND_WIN, { channel: 'music' });
        this._overlay.show('Draw — you held the champion!',
          buttonRow([['Play Again', 'replay'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20));
      } else {
        playSound(SND_DRAW, { volume: 0.5 });
        this._overlay.show("It's a draw",
          buttonRow([['Replay', 'replay'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20));
      }
    }
  }

  update(dt) {
    if (this._twoP || this._done || this._turn !== O) return;
    this._aiWait += dt;
    if (this._aiWait > 0.4) {
      this._aiWait = 0;
      this._aiMove();
    }
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
    if (this._done) return;
    // mode toggle — only before the first mark of a game
    if (this._moves === 0 &&
        x >= this._modeBtn.x && x <= this._modeBtn.x + this._modeBtn.w &&
        y >= this._modeBtn.y && y <= this._modeBtn.y + this._modeBtn.h) {
      return this._setTwoP(!this._twoP);
    }
    if (!this._twoP && this._turn !== X) return;   // solo: wait for the AI
    const g = this._grid;
    if (x < g.x || x > g.x + g.s || y < g.y || y > g.y + g.s) return;
    const col = Math.min(2, Math.floor((x - g.x) / this._cell));
    const row = Math.min(2, Math.floor((y - g.y) / this._cell));
    const i = row * 3 + col;
    if (this._board[i]) return;
    this._board[i] = this._turn;
    this._moves += 1;
    playSound(SND_MARK);
    this._turn = this._turn === X ? O : X;
    this._aiWait = 0;
    this._checkEnd();
  }

  render(ctx) {
    ctx.fillStyle = '#151b26';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    const g = this._grid;
    const c = this._cell;

    // grid lines
    ctx.strokeStyle = '#41567d';
    ctx.lineWidth = 6;
    ctx.lineCap = 'round';
    for (let k = 1; k < 3; k++) {
      ctx.beginPath();
      ctx.moveTo(g.x + k * c, g.y + 10);
      ctx.lineTo(g.x + k * c, g.y + g.s - 10);
      ctx.moveTo(g.x + 10, g.y + k * c);
      ctx.lineTo(g.x + g.s - 10, g.y + k * c);
      ctx.stroke();
    }

    // marks
    ctx.lineWidth = 14;
    for (let i = 0; i < 9; i++) {
      const cx = g.x + (i % 3) * c + c / 2;
      const cy = g.y + ((i / 3) | 0) * c + c / 2;
      const r = c * 0.28;
      if (this._board[i] === X) {
        ctx.strokeStyle = '#5b8cff';
        ctx.beginPath();
        ctx.moveTo(cx - r, cy - r); ctx.lineTo(cx + r, cy + r);
        ctx.moveTo(cx + r, cy - r); ctx.lineTo(cx - r, cy + r);
        ctx.stroke();
      } else if (this._board[i] === O) {
        ctx.strokeStyle = '#ff8a5c';
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, Math.PI * 2);
        ctx.stroke();
      }
    }

    // win line
    if (this._done && this._done.line) {
      const [a, , d] = this._done.line;
      const p = (i) => [g.x + (i % 3) * c + c / 2, g.y + ((i / 3) | 0) * c + c / 2];
      const [ax, ay] = p(a);
      const [dx, dy] = p(d);
      ctx.strokeStyle = '#7be0a0';
      ctx.lineWidth = 10;
      ctx.beginPath();
      ctx.moveTo(ax, ay);
      ctx.lineTo(dx, dy);
      ctx.stroke();
    }

    // HUD
    ctx.fillStyle = 'rgba(14,19,28,0.82)';
    ctx.fillRect(0, 0, VIEW_W, HUD);
    ctx.fillStyle = '#eef2f7';
    ctx.font = '600 22px system-ui, sans-serif';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    ctx.fillText(this._twoP ? '2 players' : `Level ${this._level + 1}/${LEVELS.length} – ${LEVELS[this._level].name}`, 24, HUD / 2);
    ctx.textAlign = 'center';
    ctx.fillStyle = '#9fb4d8';
    const _msg = this._done ? 'game over'
      : this._twoP ? (this._turn === X ? "blue's turn" : "orange's turn")
      : this._turn === X ? 'your turn' : 'computer thinking';
    ctx.fillText(_msg, VIEW_W / 2, HUD / 2);
    hudSpeakButton(ctx, _msg, VIEW_W / 2, HUD / 2);

    // mode pill (tappable only before the first mark)
    const mb = this._modeBtn;
    ctx.fillStyle = this._moves === 0 ? '#5b8cff' : 'rgba(255,255,255,0.12)';
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
