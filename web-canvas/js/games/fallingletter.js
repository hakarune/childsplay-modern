// fallingletter.js — pop each balloon by typing its letter before it
// reaches the danger line. Input: a physical keyboard, the device's OS
// keyboard (⌨ toggle), or the in-canvas QWERTY (Design Policy §I.3).

import { Scene, VIEW_W, VIEW_H, playSound } from '../engine.js';
import {
  roundRect, clamp, rand, inRect, Overlay, buttonRow,
  hudSpeakButton, hudSpeakHit, speakHud,
} from '../util.js';
import { theme } from '../theme.js';
import { TextInput } from '../textinput.js';

const ALPHA = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const COLORS = ['#ff6b6b', '#ffd93d', '#6bcb77', '#4d96ff', '#b980f0', '#ff9f45'];

const R = 54;                     // balloon radius
const KB_H = 168;
const HUD = 64;

// ≥ 6 tiers, gentle first level (a 4-year-old on a phone), monotonic ramp
// (§H.1 / §H.2). Within a level the fall speed still creeps up a little.
const LEVELS = [
  { name: 'Warm up',  vy: 34,  spawn: 3.3, lives: 5 },
  { name: 'Easy',     vy: 44,  spawn: 2.8, lives: 4 },
  { name: 'Steady',   vy: 58,  spawn: 2.3, lives: 3 },
  { name: 'Quicker',  vy: 76,  spawn: 1.9, lives: 3 },
  { name: 'Fast',     vy: 96,  spawn: 1.6, lives: 3 },
  { name: 'Blizzard', vy: 122, spawn: 1.35, lives: 3 },
];
const POPS_PER_LEVEL = 12;
const VY_CREEP = 1.6;            // speed-up per pop, within a level
const VY_CREEP_MAX = 60;

const SND_SPAWN = 'sfx/pick.wav';
const SND_POP = 'sfx/wahoo.wav';
const SND_MISS = 'sfx/bump.wav';
const SND_END = 'sfx/winner.ogg';

export default class FallingLetterGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._overlay = new Overlay();
    this._text = new TextInput('fallingletter', (ch) => this._type(ch));
    this._kbToggle = { x: VIEW_W - 150, y: HUD + 10, w: 132, h: 40 };
    this._buildKeyboard();
    this._level = 0;
    this._startLevel(0);
  }

  enter() { this._text.start(); }
  exit() { this._text.stop(); }

  _startLevel(n) {
    this._level = clamp(n, 0, LEVELS.length - 1);
    const lv = LEVELS[this._level];
    this._score = 0;                 // pops this level
    this._total = this._total || 0;  // pops all game
    this._lives = lv.lives;
    this._balloons = [];
    this._spawnCd = 0.6;
    this._state = 'play';            // play | lost | won
    this._flash = new Map();
    this._overlay.hide();
    this._text.present();
  }

  _buildKeyboard() {
    const gap = 8;
    const keyW = Math.min(112, (VIEW_W - 40 - 9 * gap) / 10);
    const keyH = 42;
    const bottom = VIEW_H - 24;
    this._keys = [];
    ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'].forEach((row, r) => {
      const total = row.length * keyW + (row.length - 1) * gap;
      const x0 = (VIEW_W - total) / 2;
      const y = bottom - (3 - r) * (keyH + gap);
      for (let i = 0; i < row.length; i++) {
        this._keys.push({ ch: row[i], x: x0 + i * (keyW + gap), y, w: keyW, h: keyH });
      }
    });
  }

  resize() {
    this._buildKeyboard();
    this._kbToggle.x = VIEW_W - 150;
    for (const b of this._balloons) b.x = clamp(b.x, R + 20, VIEW_W - R - 20);
    this._overlay.reflow(VIEW_W / 2, VIEW_H / 2 + 20);
  }

  get _dangerY() {
    return this._text.showCanvasKeyboard ? VIEW_H - KB_H - 46 : VIEW_H - 70;
  }

  _vy() {
    const base = LEVELS[this._level].vy;
    return base + Math.min(VY_CREEP_MAX, this._score * VY_CREEP);
  }
  _spawnInterval() {
    return Math.max(1.0, LEVELS[this._level].spawn - this._score * 0.02);
  }

  _spawn() {
    this._balloons.push({
      ch: ALPHA[(Math.random() * 26) | 0],
      x: rand(R + 20, VIEW_W - R - 20),
      y: -R,
      vy: this._vy(),
      color: COLORS[(Math.random() * COLORS.length) | 0],
      pop: -1,
    });
    playSound(SND_SPAWN, { volume: 0.5 });
  }

  update(dt) {
    if (this._state !== 'play') return;

    this._spawnCd -= dt;
    if (this._spawnCd <= 0) { this._spawn(); this._spawnCd = this._spawnInterval(); }

    const dy = this._dangerY;
    for (const b of this._balloons) {
      if (b.pop >= 0) { b.pop += dt; continue; }
      b.y += b.vy * dt;
      if (b.y - R >= dy) {
        b.dead = true;
        this._lives--;
        playSound(SND_MISS);
        if (this._lives <= 0) this._loseLevel();
      }
    }
    this._balloons = this._balloons.filter((b) => !b.dead && !(b.pop > 0.25));

    for (const [k, v] of this._flash) {
      const n = v - dt;
      if (n <= 0) this._flash.delete(k); else this._flash.set(k, n);
    }
  }

  _type(ch) {
    if (this._state !== 'play') return;
    this._flash.set(ch, 0.15);
    let target = null;
    for (const b of this._balloons) {
      if (b.pop < 0 && b.ch === ch && (!target || b.y > target.y)) target = b;
    }
    if (!target) return;
    target.pop = 0;
    this._score++;
    this._total++;
    playSound(SND_POP);
    if (this._score >= POPS_PER_LEVEL) this._advance();
  }

  _advance() {
    if (this._level >= LEVELS.length - 1) {
      this._state = 'won';
      playSound(SND_END, { channel: 'music' });
      this._overlay.show(
        `You did it!\n${this._total} letters caught`,
        buttonRow([['Play Again', 'again'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20),
      );
    } else {
      this._startLevel(this._level + 1);
    }
  }

  // No game-over ejection (§H.1.3): out of lives just replays this level.
  _loseLevel() {
    this._state = 'lost';
    playSound(SND_MISS);
    this._overlay.show(
      `Let's try level ${this._level + 1} again`,
      buttonRow([['Try Again', 'retry'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20),
    );
  }

  keydown(e) {
    if (this._text.osk) return;      // OS-keyboard path handles letters
    const ch = (e.key || '').toUpperCase();
    if (ch.length === 1 && ch >= 'A' && ch <= 'Z') this._type(ch);
  }

  pointermove(x, y) { this._overlay.pointermove(x, y); }

  pointerdown(x, y) {
    if (this._overlay.visible) return;
    if (hudSpeakHit(x, y)) return speakHud();
    if (inRect(this._kbToggle, x, y)) { this._text.toggle(); return; }
    if (this._text.showCanvasKeyboard) {
      const k = this._keys.find((key) => inRect(key, x, y));
      if (k) this._type(k.ch);
    }
  }

  pointerup(x, y) {
    if (!this._overlay.visible) return;
    const act = this._overlay.pointerup(x, y);
    if (act === 'again') { this._total = 0; this._startLevel(0); }
    else if (act === 'retry') this._startLevel(this._level);
    else if (act === 'menu') this._exit();
  }

  render(ctx) {
    ctx.fillStyle = theme.mode === 'light' ? '#bfe3f5' : '#26374d';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    const dy = this._dangerY;
    ctx.fillStyle = 'rgba(230,60,60,0.16)';
    ctx.fillRect(0, dy, VIEW_W, VIEW_H - dy);
    ctx.strokeStyle = 'rgba(200,40,40,0.8)';
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.moveTo(0, dy);
    ctx.lineTo(VIEW_W, dy);
    ctx.stroke();

    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    for (const b of this._balloons) {
      const popping = b.pop >= 0;
      const scale = popping ? 1 + b.pop * 3 : 1;
      ctx.globalAlpha = popping ? clamp(1 - b.pop * 4, 0, 1) : 1;
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

    // HUD row (§G.2): level + progress left, instruction + 🔊 centre, lives right
    ctx.fillStyle = theme.hud;
    ctx.fillRect(0, 0, VIEW_W, HUD);
    ctx.fillStyle = theme.line;
    ctx.fillRect(0, HUD - 1, VIEW_W, 1);
    ctx.fillStyle = theme.hud_text;
    ctx.textBaseline = 'middle';
    ctx.font = '600 22px system-ui, sans-serif';
    ctx.textAlign = 'left';
    ctx.fillText(`L${this._level + 1}/${LEVELS.length}  ${LEVELS[this._level].name}  ·  ${this._score}/${POPS_PER_LEVEL}`, 210, HUD / 2);
    ctx.textAlign = 'right';
    for (let i = 0; i < LEVELS[this._level].lives; i++) {
      ctx.globalAlpha = i < this._lives ? 1 : 0.24;
      ctx.fillText('♥', VIEW_W - 24 - i * 30, HUD / 2);
    }
    ctx.globalAlpha = 1;

    const msg = 'pop the balloon that matches the letter';
    ctx.fillStyle = theme.hud_muted;
    ctx.font = '500 20px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(msg, VIEW_W / 2, HUD / 2);
    hudSpeakButton(ctx, msg, VIEW_W / 2, HUD / 2);

    // ⌨ toggle
    const t = this._kbToggle;
    roundRect(ctx, t.x, t.y, t.w, t.h, 8);
    ctx.fillStyle = this._text.osk ? theme.accent : theme.surface;
    ctx.fill();
    ctx.fillStyle = this._text.osk ? '#fff' : theme.text;
    ctx.font = '600 18px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(this._text.osk ? '⌨ keyboard' : '⌨ on-screen', t.x + t.w / 2, t.y + t.h / 2);

    // in-canvas keyboard — the accessibility path; hidden when OS kbd is on
    if (this._text.showCanvasKeyboard) {
      for (const k of this._keys) {
        const lit = this._flash.has(k.ch);
        roundRect(ctx, k.x, k.y, k.w, k.h, 8);
        ctx.fillStyle = lit ? theme.accent : theme.card;
        ctx.fill();
        ctx.fillStyle = lit ? '#fff' : theme.card_ink;
        ctx.font = '700 24px system-ui, sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText(k.ch, k.x + k.w / 2, k.y + k.h / 2 + 1);
      }
    } else {
      ctx.fillStyle = theme.hud_muted;
      ctx.font = '500 20px system-ui, sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('using your device keyboard — tap ⌨ for the on-screen one',
        VIEW_W / 2, VIEW_H - 34);
    }

    this._overlay.render(ctx, VIEW_W, VIEW_H);
  }
}
