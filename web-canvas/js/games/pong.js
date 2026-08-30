// pong.js — bat and ball versus a gentle computer paddle. First to 5.
// A style picker on the start screen swaps the court "era" look (Atari /
// Neon / Y2K / Material); each style ships its own light + dark (Policy §D.5)
// and the global light/dark toggle still applies on top.

import { Scene, VIEW_W, VIEW_H, playSound } from '../engine.js';
import { clamp, rand, roundRect, inRect, Overlay, buttonRow } from '../util.js';
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

// Each style defines court / frame / midline / padL / padR / ball for BOTH
// light and dark. A missing role falls back to the global palette (§D.5.2).
const STYLE_THEMES = {
  material: {
    label: 'Modern',
    dark:  { court: '#0a1524', frame: '#5a7bb5', mid: 'rgba(255,255,255,0.20)', padL: '#5b8cff', padR: '#ffb454', ball: '#eef2f7' },
    light: { court: '#12314e', frame: '#bcd0ea', mid: 'rgba(255,255,255,0.30)', padL: '#7fb0ff', padR: '#ffcf87', ball: '#ffffff' },
  },
  atari: {
    label: 'Retro',
    dark:  { court: '#000000', frame: '#ffffff', mid: 'rgba(255,255,255,0.55)', padL: '#ffffff', padR: '#ffffff', ball: '#ffffff' },
    light: { court: '#e9e9e9', frame: '#111111', mid: 'rgba(0,0,0,0.45)', padL: '#111111', padR: '#111111', ball: '#111111' },
  },
  neon: {
    label: '90s Neon',
    dark:  { court: '#0a0020', frame: '#ff2fb0', mid: 'rgba(0,255,200,0.35)', padL: '#00f0ff', padR: '#ff2fb0', ball: '#f7ff00' },
    light: { court: '#2a2350', frame: '#ff5ec8', mid: 'rgba(255,255,255,0.32)', padL: '#22d3ee', padR: '#ff5ec8', ball: '#ffe000' },
  },
  y2k: {
    label: 'Y2K',
    dark:  { court: '#08131f', frame: '#7fdfff', mid: 'rgba(180,220,255,0.30)', padL: '#35c1ff', padR: '#7cffb2', ball: '#dff6ff' },
    light: { court: '#123243', frame: '#bfe9ff', mid: 'rgba(255,255,255,0.30)', padL: '#2aa9e0', padR: '#46c98a', ball: '#eaf8ff' },
  },
};
const STYLE_ORDER = ['material', 'atari', 'neon', 'y2k'];
const STYLE_KEY = 'cp:pong:style';

function loadStyle() {
  try {
    const s = localStorage.getItem(STYLE_KEY);
    if (s && STYLE_THEMES[s]) return s;
  } catch { /* */ }
  return 'material';
}

export default class PongGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._overlay = new Overlay();
    this._level = 0;
    this._keys = { up: false, down: false };
    this._style = loadStyle();
    this._phase = 'setup';           // setup | play
    this._layoutSetup();
  }

  // resolve a style role for the current global light/dark mode
  _c(role) {
    const st = STYLE_THEMES[this._style] || STYLE_THEMES.material;
    const set = theme.mode === 'light' ? st.light : st.dark;
    return (set && set[role]) || theme.board;
  }

  _layoutSetup() {
    const n = STYLE_ORDER.length;
    const sw = Math.min(220, (VIEW_W - 120) / n - 20);
    const gap = 24;
    const totalW = n * sw + (n - 1) * gap;
    const x0 = (VIEW_W - totalW) / 2;
    const y = VIEW_H / 2 - sw / 2;
    this._swatches = STYLE_ORDER.map((id, i) => ({
      id, x: x0 + i * (sw + gap), y, w: sw, h: sw,
    }));
    this._playBtn = { x: VIEW_W / 2 - 130, y: y + sw + 44, w: 260, h: 64 };
  }

  _startLevel(n) {
    this._phase = 'play';
    this._level = Math.max(0, Math.min(n, LEVELS.length - 1));
    this._you = 0;
    this._cpu = 0;
    this._over = false;
    this._py = (HUD + VIEW_H) / 2 - PH / 2;
    this._ay = this._py;
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
    if (this._phase !== 'play' || this._over) return;
    const top = HUD, bot = VIEW_H;

    const kv = (this._keys.down ? 1 : 0) - (this._keys.up ? 1 : 0);
    if (kv) this._py = clamp(this._py + kv * 420 * dt, top, bot - PH);
    if (this._ptr != null) {
      const want = clamp(this._ptr - PH / 2, top, bot - PH);
      this._py += (want - this._py) * Math.min(1, dt * 14);
    }

    const aiMax = LEVELS[this._level].ai;
    const acx = this._ay + PH / 2;
    if (Math.abs(this._by - acx) > 16) {
      this._ay = clamp(this._ay + Math.sign(this._by - acx) * aiMax * dt, top, bot - PH);
    }

    if (this._servePause > 0) { this._servePause -= dt; return; }

    this._bx += this._bvx * dt;
    this._by += this._bvy * dt;

    if (this._by - BR < top) { this._by = top + BR; this._bvy = Math.abs(this._bvy); playSound(SND_WALL); }
    if (this._by + BR > bot) { this._by = bot - BR; this._bvy = -Math.abs(this._bvy); playSound(SND_WALL); }

    const pL = 60, pR = VIEW_W - 60 - PW;
    if (this._bvx < 0 && this._bx - BR < pL + PW && this._bx - BR > pL - 20 &&
        this._by > this._py - BR && this._by < this._py + PH + BR) {
      this._bounce(this._py, 1);
    }
    if (this._bvx > 0 && this._bx + BR > pR && this._bx + BR < pR + PW + 20 &&
        this._by > this._ay - BR && this._by < this._ay + PH + BR) {
      this._bounce(this._ay, -1);
    }

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
    const rows = [['Replay', 'replay'], ['Change look', 'setup'], ['Menu', 'menu']];
    if (won && !last) rows.unshift(['Next Level', 'next']);
    this._overlay.show(
      `${won ? 'You win!' : 'So close!'}\n${this._you} – ${this._cpu}`,
      buttonRow(rows, VIEW_W / 2, VIEW_H / 2 + 20, 180)
    );
  }

  resize() {
    this._layoutSetup();
    this._py = clamp(this._py || HUD, HUD, VIEW_H - PH);
    this._ay = clamp(this._ay || HUD, HUD, VIEW_H - PH);
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
    if (this._phase === 'play' && x < VIEW_W * 0.55) this._ptr = y;
  }
  pointerdown(x, y) { if (this._phase === 'play' && x < VIEW_W * 0.55) this._ptr = y; }

  pointerup(x, y) {
    if (this._phase === 'setup') {
      const s = this._swatches.find((sw) => inRect(sw, x, y));
      if (s) {
        this._style = s.id;
        try { localStorage.setItem(STYLE_KEY, s.id); } catch { /* */ }
        return;
      }
      if (inRect(this._playBtn, x, y)) this._startLevel(0);
      return;
    }
    if (!this._overlay.visible) return;
    const act = this._overlay.pointerup(x, y);
    if (act === 'next') this._startLevel(this._level + 1);
    else if (act === 'replay') this._startLevel(this._level);
    else if (act === 'setup') { this._phase = 'setup'; this._overlay.hide(); this._layoutSetup(); }
    else if (act === 'menu') this._exit();
  }

  _renderSetup(ctx) {
    ctx.fillStyle = theme.bg;
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);
    ctx.fillStyle = theme.text;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.font = '700 44px system-ui, sans-serif';
    ctx.fillText('Pong', VIEW_W / 2, VIEW_H / 2 - this._swatches[0].h / 2 - 70);
    ctx.font = '500 22px system-ui, sans-serif';
    ctx.fillStyle = theme.text_muted;
    ctx.fillText('pick a look, then play', VIEW_W / 2, VIEW_H / 2 - this._swatches[0].h / 2 - 34);

    for (const sw of this._swatches) {
      const st = STYLE_THEMES[sw.id];
      const set = theme.mode === 'light' ? st.light : st.dark;
      roundRect(ctx, sw.x, sw.y, sw.w, sw.h, 16);
      ctx.fillStyle = set.court;
      ctx.fill();
      ctx.lineWidth = sw.id === this._style ? 5 : 2;
      ctx.strokeStyle = sw.id === this._style ? theme.accent : set.frame;
      ctx.stroke();
      // mini paddles + ball
      ctx.fillStyle = set.padL; ctx.fillRect(sw.x + 16, sw.y + sw.h * 0.32, 8, sw.h * 0.36);
      ctx.fillStyle = set.padR; ctx.fillRect(sw.x + sw.w - 24, sw.y + sw.h * 0.32, 8, sw.h * 0.36);
      ctx.fillStyle = set.ball;
      ctx.beginPath(); ctx.arc(sw.x + sw.w / 2, sw.y + sw.h / 2, 8, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = theme.text;
      ctx.font = '600 20px system-ui, sans-serif';
      ctx.fillText(st.label, sw.x + sw.w / 2, sw.y + sw.h + 22);
      if (sw.id === this._style) {
        ctx.fillStyle = theme.accent;
        ctx.beginPath(); ctx.arc(sw.x + sw.w - 16, sw.y + 16, 10, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = '#fff';
        ctx.font = '700 14px system-ui, sans-serif';
        ctx.fillText('✓', sw.x + sw.w - 16, sw.y + 17);
      }
    }

    const b = this._playBtn;
    roundRect(ctx, b.x, b.y, b.w, b.h, 14);
    ctx.fillStyle = theme.accent;
    ctx.fill();
    ctx.fillStyle = '#fff';
    ctx.font = '700 26px system-ui, sans-serif';
    ctx.fillText('Play', b.x + b.w / 2, b.y + b.h / 2 + 1);
  }

  render(ctx) {
    if (this._phase === 'setup') { this._renderSetup(ctx); return; }

    ctx.fillStyle = theme.bg;
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    const bx = 10, bw = VIEW_W - 20, byy = HUD + 8, bh = VIEW_H - HUD - 18;
    ctx.fillStyle = this._c('court');
    ctx.fillRect(bx, byy, bw, bh);
    ctx.strokeStyle = this._c('frame');
    ctx.lineWidth = 3;
    ctx.strokeRect(bx, byy, bw, bh);

    ctx.strokeStyle = this._c('mid');
    ctx.lineWidth = 4;
    ctx.setLineDash([16, 18]);
    ctx.beginPath();
    ctx.moveTo(VIEW_W / 2, byy + 6);
    ctx.lineTo(VIEW_W / 2, byy + bh - 6);
    ctx.stroke();
    ctx.setLineDash([]);

    ctx.fillStyle = this._c('padL');
    ctx.fillRect(60, this._py, PW, PH);
    ctx.fillStyle = this._c('padR');
    ctx.fillRect(VIEW_W - 60 - PW, this._ay, PW, PH);

    ctx.fillStyle = this._c('ball');
    ctx.beginPath();
    ctx.arc(this._bx, this._by, BR, 0, Math.PI * 2);
    ctx.fill();

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
