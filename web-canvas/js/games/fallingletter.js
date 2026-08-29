// fallingletter.js — pop each balloon by typing its letter (physical or
// the on-screen keyboard) before it reaches the danger line.

import { Scene, VIEW_W, VIEW_H, playSound } from '../engine.js';
import { roundRect, clamp, rand, inRect, Overlay, buttonRow } from '../util.js';

const ALPHA = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const COLORS = ['#ff6b6b', '#ffd93d', '#6bcb77', '#4d96ff', '#b980f0', '#ff9f45'];

const R = 54;                     // balloon radius
const KB_H = 168;
const DANGER_Y = VIEW_H - KB_H - 46;

const START_VY = 70;
const VY_PER = 5;
const MAX_VY = 260;
const START_SPAWN = 1.9;
const SPAWN_PER = 0.045;
const MIN_SPAWN = 0.7;

const KB_ROWS = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];

const SND_SPAWN = 'sfx/pick.wav';
const SND_POP = 'sfx/wahoo.wav';
const SND_MISS = 'sfx/bump.wav';
const SND_END = 'sfx/winner.ogg';

export default class FallingLetterGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._overlay = new Overlay();
    this._buildKeyboard();
    this._reset();
  }

  _reset() {
    this._score = 0;
    this._lives = 3;
    this._balloons = [];
    this._spawnCd = 0.4;
    this._over = false;
    this._flash = new Map();      // key char -> remaining highlight secs
    this._overlay.hide();
  }

  _buildKeyboard() {
    const gap = 8;
    // widest row is 10 keys — size them to fit the current world width
    const keyW = Math.min(112, (VIEW_W - 40 - 9 * gap) / 10);
    const keyH = 42;
    const bottom = VIEW_H - 24;
    this._keys = [];
    KB_ROWS.forEach((row, r) => {
      const total = row.length * keyW + (row.length - 1) * gap;
      const x0 = (VIEW_W - total) / 2;
      const y = bottom - (KB_ROWS.length - r) * (keyH + gap);
      for (let i = 0; i < row.length; i++) {
        this._keys.push({ ch: row[i], x: x0 + i * (keyW + gap), y, w: keyW, h: keyH });
      }
    });
  }

  resize() {
    this._buildKeyboard();
    for (const b of this._balloons) b.x = clamp(b.x, R + 20, VIEW_W - R - 20);
    this._overlay.reflow(VIEW_W / 2, VIEW_H / 2 + 20);
  }

  // --- spawning / difficulty ---
  _vy() { return Math.min(MAX_VY, START_VY + this._score * VY_PER); }
  _spawnInterval() { return Math.max(MIN_SPAWN, START_SPAWN - this._score * SPAWN_PER); }

  _spawn() {
    const ch = ALPHA[(Math.random() * 26) | 0];
    this._balloons.push({
      ch,
      x: rand(R + 20, VIEW_W - R - 20),
      y: -R,
      vy: this._vy(),
      color: COLORS[(Math.random() * COLORS.length) | 0],
      pop: -1,
    });
    playSound(SND_SPAWN, { volume: 0.5 });
  }

  update(dt) {
    if (this._over) return;

    this._spawnCd -= dt;
    if (this._spawnCd <= 0) {
      this._spawn();
      this._spawnCd = this._spawnInterval();
    }

    for (const b of this._balloons) {
      if (b.pop >= 0) { b.pop += dt; continue; }
      b.y += b.vy * dt;
      if (b.y - R >= DANGER_Y) {
        b.dead = true;
        this._lives--;
        playSound(SND_MISS);
        if (this._lives <= 0) this._gameOver();
      }
    }
    this._balloons = this._balloons.filter((b) => !b.dead && !(b.pop > 0.25));

    for (const [k, v] of this._flash) {
      const n = v - dt;
      if (n <= 0) this._flash.delete(k); else this._flash.set(k, n);
    }
  }

  _hit(ch) {
    if (this._over) return;
    let target = null;
    for (const b of this._balloons) {
      if (b.pop < 0 && b.ch === ch && (!target || b.y > target.y)) target = b;
    }
    if (!target) return;
    target.pop = 0;
    this._score++;
    playSound(SND_POP);
  }

  _gameOver() {
    this._over = true;
    playSound(SND_END, { channel: 'music' });
    this._overlay.show(
      `Nice typing!\nyou caught ${this._score} letter${this._score === 1 ? '' : 's'}`,
      buttonRow([['Play Again', 'again'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20)
    );
  }

  keydown(e) {
    const ch = (e.key || '').toUpperCase();
    if (ch.length === 1 && ch >= 'A' && ch <= 'Z') {
      this._flash.set(ch, 0.15);
      this._hit(ch);
    }
  }

  pointermove(x, y) { this._overlay.pointermove(x, y); }

  pointerdown(x, y) {
    if (this._overlay.visible) return;
    const k = this._keys.find((key) => inRect(key, x, y));
    if (k) { this._flash.set(k.ch, 0.15); this._hit(k.ch); }
  }

  pointerup(x, y) {
    if (!this._overlay.visible) return;
    const act = this._overlay.pointerup(x, y);
    if (act === 'again') this._reset();
    else if (act === 'menu') this._exit();
  }

  render(ctx) {
    ctx.fillStyle = '#87c7eb';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    // danger zone
    ctx.fillStyle = 'rgba(230,60,60,0.16)';
    ctx.fillRect(0, DANGER_Y, VIEW_W, VIEW_H - DANGER_Y);
    ctx.strokeStyle = 'rgba(200,40,40,0.8)';
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.moveTo(0, DANGER_Y);
    ctx.lineTo(VIEW_W, DANGER_Y);
    ctx.stroke();

    // balloons
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    for (const b of this._balloons) {
      const popping = b.pop >= 0;
      const scale = popping ? 1 + b.pop * 3 : 1;
      const alpha = popping ? clamp(1 - b.pop * 4, 0, 1) : 1;
      ctx.globalAlpha = alpha;
      ctx.beginPath();
      ctx.arc(b.x, b.y, R * scale, 0, Math.PI * 2);
      ctx.fillStyle = b.color;
      ctx.fill();
      ctx.lineWidth = 4;
      ctx.strokeStyle = 'rgba(255,255,255,0.5)';
      ctx.stroke();
      if (!popping) {
        ctx.fillStyle = '#1b2333';
        ctx.font = '700 52px system-ui, sans-serif';
        ctx.fillText(b.ch, b.x, b.y + 2);
      }
      ctx.globalAlpha = 1;
    }

    // HUD
    ctx.fillStyle = 'rgba(16,21,32,0.55)';
    ctx.fillRect(0, 0, VIEW_W, 64);
    ctx.fillStyle = '#fff';
    ctx.font = '600 26px system-ui, sans-serif';
    ctx.textAlign = 'left';
    ctx.fillText(`Score ${this._score}`, 220, 33);
    ctx.textAlign = 'right';
    for (let i = 0; i < 3; i++) {
      ctx.globalAlpha = i < this._lives ? 1 : 0.28;
      ctx.fillText('♥', VIEW_W - 24 - i * 40, 33);
    }
    ctx.globalAlpha = 1;

    // on-screen keyboard
    for (const k of this._keys) {
      const lit = this._flash.has(k.ch);
      roundRect(ctx, k.x, k.y, k.w, k.h, 8);
      ctx.fillStyle = lit ? '#4c7dff' : 'rgba(255,255,255,0.9)';
      ctx.fill();
      ctx.fillStyle = lit ? '#fff' : '#1b2333';
      ctx.font = '700 24px system-ui, sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText(k.ch, k.x + k.w / 2, k.y + k.h / 2 + 1);
    }

    this._overlay.render(ctx, VIEW_W, VIEW_H);
  }
}
