// simon.js — repeat the growing colour-and-tone sequence. Six levels; the
// target length grows 2 → 7. A wrong tap just replays the same sequence
// (no lives, no game-over) — only forward progress.

import { Scene, VIEW_W, VIEW_H, playSound } from '../engine.js';
import { clamp, roundRect, inRect, Overlay, buttonRow } from '../util.js';

const HUD = 56;
const TARGETS = [2, 3, 4, 5, 6, 7];

// quadrant: colour + tone (Hz). Index order = TL, TR, BL, BR.
const PADS = [
  { on: '#ff5a5a', off: '#7a2f2f', freq: 262 }, // red    C4
  { on: '#ffd93d', off: '#7a6a1c', freq: 330 }, // yellow E4
  { on: '#5fce6b', off: '#2c5f32', freq: 392 }, // green  G4
  { on: '#4d96ff', off: '#2b4d7a', freq: 494 }, // blue   B4
];

const SND_GOOD = 'sfx/good.ogg';
const SND_WRONG = 'sfx/wrong.ogg';
const SND_WIN = 'sfx/winner.ogg';

function tone(freq, dur = 0.42) {
  try {
    const AC = window.__spAudio ||
      (window.__spAudio = new (window.AudioContext || window.webkitAudioContext)());
    if (AC.state === 'suspended') AC.resume();
    const t0 = AC.currentTime;
    const osc = AC.createOscillator();
    const g = AC.createGain();
    osc.type = 'sine';
    osc.frequency.value = freq;
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.linearRampToValueAtTime(0.28, t0 + 0.02);
    g.gain.exponentialRampToValueAtTime(0.0006, t0 + dur);
    osc.connect(g).connect(AC.destination);
    osc.start(t0);
    osc.stop(t0 + dur + 0.05);
  } catch {
    /* no WebAudio — the game still works silently */
  }
}

export default class SimonGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._overlay = new Overlay();
    this._level = 0;
    this._startLevel(0);
  }

  _startLevel(n) {
    this._level = clamp(n, 0, TARGETS.length - 1);
    this._seq = [];
    this._phase = 'idle';          // idle | show | input | pause
    this._showState = 'start';     // start | lit | gap  (within 'show')
    this._showIdx = 0;
    this._inputIdx = 0;
    this._lit = -1;                // pad index currently lit, else -1
    this._t = 0;
    this._flash = null;            // { kind:'good'|'wrong', t }
    this._overlay.hide();
    this._geo();
  }

  _geo() {
    const availH = VIEW_H - HUD - 40;
    const s = Math.min(VIEW_W * 0.62, availH);
    this._board = { x: (VIEW_W - s) / 2, y: HUD + 20 + (availH - s) / 2, s };
    const gap = s * 0.05;
    const half = (s - gap) / 2;
    const bx = this._board.x;
    const by = this._board.y;
    this._rects = [
      { x: bx, y: by, w: half, h: half },
      { x: bx + half + gap, y: by, w: half, h: half },
      { x: bx, y: by + half + gap, w: half, h: half },
      { x: bx + half + gap, y: by + half + gap, w: half, h: half },
    ];
    this._startBtn = { x: VIEW_W / 2 - 120, y: by + s / 2 - 40, w: 240, h: 80 };
  }

  resize() {
    this._geo();
    this._overlay.reflow(VIEW_W / 2, VIEW_H / 2 + 20);
  }

  _stepTime() {
    const k = 1 - this._level * 0.07;        // a little quicker each level
    return { lit: 0.44 * k, gap: 0.18 * k };
  }

  _beginShow() {
    this._phase = 'show';
    this._showState = 'start';
    this._showIdx = 0;
    this._lit = -1;
    this._t = 0;
  }

  _appendAndShow() {
    this._seq.push((Math.random() * 4) | 0);
    this._phase = 'pause';
    this._t = 0;
  }

  update(dt) {
    if (this._flash) {
      this._flash.t += dt;
      if (this._flash.t > 0.5) this._flash = null;
    }

    if (this._phase === 'pause') {
      this._t += dt;
      if (this._t > 0.55) this._beginShow();
      return;
    }
    if (this._phase !== 'show') return;

    const { lit, gap } = this._stepTime();
    this._t += dt;

    if (this._showState === 'start') {
      if (this._showIdx >= this._seq.length) {
        this._phase = 'input';
        this._inputIdx = 0;
        this._lit = -1;
        return;
      }
      this._lit = this._seq[this._showIdx];
      tone(PADS[this._lit].freq, lit * 0.9);
      this._showState = 'lit';
      this._t = 0;
    } else if (this._showState === 'lit' && this._t >= lit) {
      this._lit = -1;
      this._showState = 'gap';
      this._t = 0;
    } else if (this._showState === 'gap' && this._t >= gap) {
      this._showIdx += 1;
      this._showState = 'start';
      this._t = 0;
    }
  }

  pointerup(x, y) {
    if (this._overlay.visible) {
      const act = this._overlay.pointerup(x, y);
      if (act === 'next') this._startLevel(this._level + 1);
      else if (act === 'replay') this._startLevel(this._level);
      else if (act === 'menu') this._exit();
      return;
    }

    if (this._phase === 'idle') {
      if (inRect(this._startBtn, x, y)) {
        this._seq = [(Math.random() * 4) | 0];
        this._beginShow();
      }
      return;
    }

    if (this._phase !== 'input') return;

    const p = this._rects.findIndex((r) => inRect(r, x, y));
    if (p < 0) return;

    this._lit = p;
    tone(PADS[p].freq, 0.3);

    if (p === this._seq[this._inputIdx]) {
      this._inputIdx += 1;
      if (this._inputIdx >= this._seq.length) {
        if (this._seq.length >= TARGETS[this._level]) {
          this._levelDone();
        } else {
          this._flash = { kind: 'good', t: 0 };
          playSound(SND_GOOD, { volume: 0.5 });
          this._appendAndShow();
        }
      }
    } else {
      this._flash = { kind: 'wrong', t: 0 };
      playSound(SND_WRONG);
      this._phase = 'pause';
      this._t = -0.3;                 // a longer beat before the replay
    }
  }

  _levelDone() {
    const last = this._level >= TARGETS.length - 1;
    this._phase = 'idle';
    this._lit = -1;
    if (last) {
      playSound(SND_WIN);
      this._overlay.show(
        'You matched every sequence!',
        buttonRow([['Play Again', 'replay'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20),
      );
    } else {
      playSound(SND_GOOD);
      this._overlay.show(
        `Level ${this._level + 1} done!`,
        buttonRow([['Next Level', 'next'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20),
      );
    }
  }

  render(ctx) {
    ctx.fillStyle = '#161b26';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    this._rects.forEach((r, i) => {
      const lit = this._lit === i ||
        (this._flash && this._flash.kind === 'good') ||
        (this._flash && this._flash.kind === 'wrong' && i === this._seq[this._inputIdx]);
      ctx.fillStyle = lit ? PADS[i].on : PADS[i].off;
      roundRect(ctx, r.x, r.y, r.w, r.h, 18);
      ctx.fill();
    });

    const b = this._board;
    ctx.fillStyle = '#0f131c';
    ctx.beginPath();
    ctx.arc(b.x + b.s / 2, b.y + b.s / 2, b.s * 0.14, 0, Math.PI * 2);
    ctx.fill();

    if (this._phase === 'idle' && !this._overlay.visible) {
      const sb = this._startBtn;
      ctx.fillStyle = '#4c7dff';
      roundRect(ctx, sb.x, sb.y, sb.w, sb.h, 16);
      ctx.fill();
      ctx.fillStyle = '#fff';
      ctx.font = '700 30px system-ui, sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('Start', sb.x + sb.w / 2, sb.y + sb.h / 2 + 1);
    }

    ctx.fillStyle = 'rgba(16,21,32,0.6)';
    ctx.fillRect(0, 0, VIEW_W, HUD);
    ctx.fillStyle = '#eef2f7';
    ctx.font = '600 22px system-ui, sans-serif';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    const shown = Math.min(this._seq.length, TARGETS[this._level]);
    ctx.fillText(`Level ${this._level + 1}/${TARGETS.length}   ·   length ${shown}/${TARGETS[this._level]}`, 200, HUD / 2);
    ctx.textAlign = 'center';
    ctx.fillStyle = '#9fb4d8';
    const msg = this._phase === 'idle' ? 'press Start, then repeat the sequence'
      : (this._phase === 'show' || this._phase === 'pause') ? 'watch and listen…'
      : 'your turn — tap the colours in order';
    ctx.fillText(msg, VIEW_W / 2, HUD / 2);

    this._overlay.render(ctx, VIEW_W, VIEW_H);
  }
}
