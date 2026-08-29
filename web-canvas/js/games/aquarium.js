// aquarium.js — a calm digital fish tank. No score: just watch the fish,
// poke one to hear a bubble + see its name, or tap the water to drop food
// the nearby fish swim over to.

import { Scene, VIEW_W, VIEW_H, img, loadImage, playSound, playLoop } from '../engine.js';
import { rand, clamp, shuffle } from '../util.js';
import { speak, hasVoice } from '../tts.js';

const KEY_NAMES = 'cp:aquarium:names';

const TANKS = ['aquarium/tank1.jpg', 'aquarium/tank2.jpg'];
const BUBBLE = 'aquarium/bubble.png';

const SPECIES = [
  { id: 'shark1', name: 'shark', base: 0.9, rare: true },
  { id: 'manta', name: 'manta ray', base: 0.8, rare: true },
  { id: 'eel', name: 'eel', base: 0.9 },
  { id: 'discus2', name: 'discus', base: 1.0 },
  { id: 'QueenAngel', name: 'angelfish', base: 1.2 },
  { id: 'butfish', name: 'butterfly fish', base: 1.1 },
  { id: 'blueking2', name: 'blue tang', base: 1.0 },
  { id: 'collaris', name: 'tang', base: 1.3 },
  { id: 'six_barred', name: 'wrasse', base: 1.2 },
  { id: 'cichlid1', name: 'cichlid', base: 1.3 },
  { id: 'newf1', name: 'goldfish', base: 1.0 },
  { id: 'f01', name: 'fish', base: 1.2 }, { id: 'f04', name: 'fish', base: 1.2 },
  { id: 'f06', name: 'fish', base: 1.1 }, { id: 'f09', name: 'fish', base: 1.2 },
  { id: 'f13', name: 'fish', base: 1.1 },
];

const SND_BLUB = 'sfx/blub0.wav';
const SND_SPLASH = 'sfx/poolsplash.wav';
const AMBIENT = 'sfx/aqua_ambient.ogg';

const FISH_COUNT = 13;
const BAND = { top: 90, bottom: VIEW_H - 44 };

export default class AquariumGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._t = 0;
    this._tank = TANKS[(Math.random() * TANKS.length) | 0];
    this._bubbles = [];
    this._ripples = [];
    this._food = [];
    this._labels = [];
    this._parallax = 0;
    this._ambient = null;
    // mode 1 (default): fish sounds only. mode 2: also speak the name.
    try { this._sayNames = localStorage.getItem(KEY_NAMES) === '1'; } catch { this._sayNames = false; }
    this._namesBtn = { x: VIEW_W - 150, y: 14, w: 132, h: 36 };

    loadImage(this._tank);
    loadImage(BUBBLE);

    const pool = shuffle(SPECIES.flatMap((s) => (s.rare ? [s] : [s, s])));
    this._fish = [];
    for (let i = 0; i < FISH_COUNT; i++) {
      const sp = pool[i % pool.length];
      const dir = Math.random() < 0.5 ? 1 : -1;
      const speed = rand(30, 82) * (sp.rare ? 0.7 : 1);
      const fish = {
        sp, frames: null,
        x: rand(60, VIEW_W - 60),
        y: rand(BAND.top + 40, BAND.bottom - 40),
        vx: dir * speed, vy: 0, speed,
        scale: sp.base * rand(0.7, 1.15) * (sp.rare ? 1.1 : 1),
        frameT: Math.random() * 2, phase: Math.random() * 10,
        dart: 0, target: null, hover: 0,
      };
      Promise.all([loadImage(`aquarium/${sp.id}_0.png`), loadImage(`aquarium/${sp.id}_1.png`)])
        .then(([a, b]) => { fish.frames = [a, b]; });
      this._fish.push(fish);
    }
  }

  _startAmbient() {
    if (this._ambient) return;
    this._ambient = playLoop(AMBIENT, { volume: 0.25, channel: 'music' });
  }

  exit() {
    if (this._ambient) { this._ambient.stop(); this._ambient = null; }
  }

  // --- helpers ---
  _dims(f) {
    const im = f.frames && f.frames[0];
    const w = (im && im.naturalWidth ? im.naturalWidth : 90) * f.scale;
    const h = (im && im.naturalHeight ? im.naturalHeight : 50) * f.scale;
    return [w, h];
  }

  _fishAt(x, y) {
    for (let i = this._fish.length - 1; i >= 0; i--) {
      const f = this._fish[i];
      const [w, h] = this._dims(f);
      if (Math.abs(x - f.x) < w / 2 && Math.abs(y - f.y) < h / 2) return f;
    }
    return null;
  }

  // --- update ---
  update(dt) {
    this._t += dt;
    this._parallax = Math.sin(this._t * 0.12) * 22;

    // ambient bubble stream
    if (Math.random() < dt * 6) {
      this._bubbles.push({ x: rand(40, VIEW_W - 40), y: BAND.bottom, vy: rand(40, 90), r: rand(3, 9), wob: Math.random() * 10 });
    }
    for (const b of this._bubbles) { b.y -= b.vy * dt; b.x += Math.sin(this._t * 3 + b.wob) * 12 * dt; }
    this._bubbles = this._bubbles.filter((b) => b.y > BAND.top - 20);

    for (const r of this._ripples) r.t += dt;
    this._ripples = this._ripples.filter((r) => r.t < 1.1);

    for (const p of this._food) { p.y += p.vy * dt; p.life -= dt; }
    this._food = this._food.filter((p) => p.life > 0 && p.y < BAND.bottom + 10);

    for (const l of this._labels) { l.y -= 26 * dt; l.t += dt; }
    this._labels = this._labels.filter((l) => l.t < 1.6);

    for (const f of this._fish) this._stepFish(f, dt);
  }

  _stepFish(f, dt) {
    f.frameT += dt * (0.5 + f.speed / 90);
    if (f.dart > 0) f.dart -= dt;
    if (f.hover > 0) f.hover -= dt;

    // steer toward food
    if (f.target) {
      const dx = f.target.x - f.x;
      const dy = f.target.y - f.y;
      const d = Math.hypot(dx, dy) || 1;
      f.vx += (dx / d) * 160 * dt;
      f.vy += (dy / d) * 120 * dt;
      if (d < 26) {
        this._food = this._food.filter((p) => p !== f.target);
        for (const o of this._fish) if (o.target === f.target) o.target = null;
        for (let i = 0; i < 5; i++) this._bubbles.push({ x: f.x, y: f.y, vy: rand(50, 110), r: rand(2, 6), wob: Math.random() * 10 });
      }
    } else {
      // gentle wander + vertical bob
      if (Math.random() < dt * 1.5) f.vx += rand(-20, 20);
      f.vy += (Math.sin((this._t + f.phase) * 1.2) * 16 - f.vy) * dt * 2;
    }

    // separation
    for (const o of this._fish) {
      if (o === f) continue;
      const dx = f.x - o.x, dy = f.y - o.y;
      const d2 = dx * dx + dy * dy;
      if (d2 < 3600 && d2 > 1) {
        const d = Math.sqrt(d2);
        f.vx += (dx / d) * 40 * dt;
        f.vy += (dy / d) * 30 * dt;
      }
    }

    const spd = Math.hypot(f.vx, f.vy) || 1;
    const max = f.speed * (f.dart > 0 ? 2.4 : 1) * (f.target ? 1.6 : 1);
    if (spd > max) { f.vx *= max / spd; f.vy *= max / spd; }

    f.x += f.vx * dt;
    f.y += f.vy * dt;

    const [w, h] = this._dims(f);
    const mx = w * 0.35;
    if (f.x < mx) { f.x = mx; f.vx = Math.abs(f.vx); }
    if (f.x > VIEW_W - mx) { f.x = VIEW_W - mx; f.vx = -Math.abs(f.vx); }
    if (f.y < BAND.top + h / 2) { f.y = BAND.top + h / 2; f.vy = Math.abs(f.vy) * 0.6; }
    if (f.y > BAND.bottom - h / 2) { f.y = BAND.bottom - h / 2; f.vy = -Math.abs(f.vy) * 0.6; }
  }

  // --- input ---
  pointerup(x, y) {
    const b = this._namesBtn;
    if (hasVoice() && x >= b.x && x <= b.x + b.w && y >= b.y && y <= b.y + b.h) {
      this._sayNames = !this._sayNames;
      try { localStorage.setItem(KEY_NAMES, this._sayNames ? '1' : '0'); } catch { /* */ }
    }
  }

  pointerdown(x, y) {
    this._startAmbient();
    const b = this._namesBtn;
    if (hasVoice() && x >= b.x && x <= b.x + b.w && y >= b.y && y <= b.y + b.h) return;
    const f = this._fishAt(x, y);
    if (f) {
      f.dart = 0.7;
      playSound(SND_BLUB);
      for (let i = 0; i < 7; i++) this._bubbles.push({ x: f.x + rand(-15, 15), y: f.y, vy: rand(60, 130), r: rand(2, 7), wob: Math.random() * 10 });
      this._labels.push({ text: f.sp.name, x: f.x, y: f.y - 24, t: 0 });
      if (this._sayNames) speak(f.sp.name);
    } else {
      this._ripples.push({ x, y, t: 0 });
      this._food.push({ x, y, vy: rand(14, 24), life: 6 });
      playSound(SND_SPLASH, { volume: 0.4 });
      const near = [...this._fish].sort((a, b) => Math.hypot(a.x - x, a.y - y) - Math.hypot(b.x - x, b.y - y)).slice(0, 4);
      for (const nf of near) nf.target = this._food[this._food.length - 1];
    }
  }

  pointermove(x, y) {
    const f = this._fishAt(x, y);
    if (f) f.hover = 0.25;
  }

  // --- render ---
  render(ctx) {
    // background (cover-fit, slow parallax)
    const bg = img(this._tank);
    ctx.fillStyle = '#0a2a3a';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);
    if (bg && bg.naturalWidth) {
      const s = Math.max((VIEW_W + 80) / bg.naturalWidth, VIEW_H / bg.naturalHeight);
      const dw = bg.naturalWidth * s, dh = bg.naturalHeight * s;
      ctx.drawImage(bg, (VIEW_W - dw) / 2 + this._parallax, (VIEW_H - dh) / 2, dw, dh);
    }
    // blue wash
    ctx.fillStyle = 'rgba(20,90,130,0.18)';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    this._drawSeaweed(ctx);

    // food
    for (const p of this._food) {
      ctx.globalAlpha = clamp(p.life, 0, 1);
      ctx.fillStyle = '#c58a3d';
      ctx.beginPath();
      ctx.arc(p.x, p.y, 4, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;

    // fish
    for (const f of this._fish) {
      const frame = f.frames && f.frames[(f.frameT | 0) % 2];
      if (!frame || !frame.naturalWidth) continue;
      const [w, h] = this._dims(f);
      const grow = f.hover > 0 ? 1.08 : 1;
      ctx.save();
      ctx.translate(f.x, f.y);
      ctx.scale((f.vx < 0 ? -1 : 1) * grow, grow);
      ctx.drawImage(frame, -w / 2, -h / 2, w, h);
      ctx.restore();
    }

    // bubbles
    const bub = img(BUBBLE);
    for (const b of this._bubbles) {
      if (bub && bub.naturalWidth) {
        ctx.globalAlpha = 0.75;
        ctx.drawImage(bub, b.x - b.r, b.y - b.r, b.r * 2, b.r * 2);
      } else {
        ctx.globalAlpha = 0.5;
        ctx.strokeStyle = '#cfeeffcc';
        ctx.beginPath();
        ctx.arc(b.x, b.y, b.r, 0, Math.PI * 2);
        ctx.stroke();
      }
    }
    ctx.globalAlpha = 1;

    // ripples
    for (const r of this._ripples) {
      ctx.globalAlpha = (1 - r.t / 1.1) * 0.6;
      ctx.strokeStyle = '#dff2ff';
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.arc(r.x, r.y, 8 + r.t * 90, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.globalAlpha = 1;

    // floating names
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    for (const l of this._labels) {
      ctx.globalAlpha = clamp(1 - l.t / 1.6, 0, 1);
      ctx.fillStyle = '#ffffff';
      ctx.font = '700 30px system-ui, sans-serif';
      ctx.fillText(l.text, l.x, l.y);
    }
    ctx.globalAlpha = 1;

    // hint strip
    ctx.fillStyle = 'rgba(10,20,30,0.35)';
    ctx.fillRect(0, 0, VIEW_W, 64);
    ctx.fillStyle = '#dfeaf5';
    ctx.font = '500 22px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('tap a fish to say hello  ·  tap the water to feed them', VIEW_W / 2, 32);

    if (hasVoice()) {
      const b = this._namesBtn;
      ctx.fillStyle = this._sayNames ? '#5b8cff' : 'rgba(255,255,255,0.14)';
      ctx.beginPath();
      if (ctx.roundRect) ctx.roundRect(b.x, b.y, b.w, b.h, 10);
      else ctx.rect(b.x, b.y, b.w, b.h);
      ctx.fill();
      ctx.fillStyle = '#ffffff';
      ctx.font = '600 16px system-ui, sans-serif';
      ctx.fillText(this._sayNames ? '🔊 names: on' : '🔊 names: off', b.x + b.w / 2, b.y + b.h / 2);
    }
  }

  _drawSeaweed(ctx) {
    ctx.strokeStyle = 'rgba(40,120,70,0.55)';
    ctx.lineCap = 'round';
    for (let i = 0; i < 6; i++) {
      const bx = 80 + i * 220 + (i % 2) * 60;
      const hgt = 150 + (i % 3) * 60;
      const sway = Math.sin(this._t * 1.1 + i) * 26;
      ctx.lineWidth = 12 - (i % 3) * 3;
      ctx.beginPath();
      ctx.moveTo(bx, VIEW_H);
      ctx.quadraticCurveTo(bx + sway, VIEW_H - hgt / 2, bx + sway * 1.6, VIEW_H - hgt);
      ctx.stroke();
    }
  }
}
