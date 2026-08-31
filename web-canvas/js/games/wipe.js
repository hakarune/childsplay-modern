// wipe.js — a painting hidden under a grey cover. Drag the sponge to wipe
// the cover away and reveal the picture. Clear enough of it to finish the
// level. Six paintings; the target rises and the sponge shrinks.

import { Scene, VIEW_W, VIEW_H, img, loadImage, loadManifest, playSound } from '../engine.js';
import { clamp, Overlay, buttonRow, tierBag, poolKeys, parseTier, hudSpeakButton, hudSpeakHit, speakHud } from '../util.js';
import { theme } from '../theme.js';

const HUD = 64;

// The whole `backgrounds/` pool (paintings + aquarium tanks + future drops).
// Wipe + Puzzle share the `backgrounds:<tier>` bags so one session playing
// both won't see the same picture twice (§B.4). Difficulty is a filename
// tag — `bruegel0_hard.jpg`, untagged = any tier (§A.3) — read off the
// manifest, no data file.

// 12 levels: target rises 0.65 → 0.99, sponge shrinks 54 → 26; tier steps
// easy (1-4) → med (5-8) → hard (9-12) for the shared-pool picture draw.
const LEVELS = Array.from({ length: 12 }, (_, i) => ({
  target: 0.65 + (0.99 - 0.65) * (i / 11),
  sponge: Math.round(54 - (54 - 26) * (i / 11)),
  tier: i < 4 ? 'easy' : i < 8 ? 'med' : 'hard',
}));

const CELL = 20;                    // target cover-cell size (px, world units)

const SND_WIPE = 'sfx/pick.wav';
const SND_WIN = 'sfx/winner.ogg';

export default class WipeGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._overlay = new Overlay();
    this._level = 0;
    this._bgReady = loadManifest().then((m) => { this._bgStems = poolKeys(m, 'backgrounds'); });
    this._startLevel(0);
  }

  _tierOf(stem) { return parseTier(stem).tier; }

  _startLevel(n) {
    this._level = clamp(n, 0, LEVELS.length - 1);
    this._img = null;
    this._done = false;
    this._drag = false;
    this._ptr = null;
    this._cover = null;              // fresh cover — don't remap the old board
    this._cols = 0;
    this._rows = 0;
    this._overlay.hide();
    const lv = LEVELS[this._level];
    const forLevel = this._level;
    this._bgReady.then(() => {
      if (this._level !== forLevel) return;
      const want = tierBag('backgrounds', this._bgStems, this._tierOf, lv.tier).draw();
      this._imgName = want;
      loadImage(`backgrounds/${want}`).then((im) => {
        if (this._imgName !== want) return;
        this._img = im;
        this._geo();
      });
    });
    this._geo();
  }

  _geo() {
    const availW = VIEW_W - 100;
    const availH = VIEW_H - HUD - 90;
    let aspect = 8 / 5;
    if (this._img && this._img.naturalWidth) aspect = this._img.naturalWidth / this._img.naturalHeight;
    let fw = availW;
    let fh = fw / aspect;
    if (fh > availH) { fh = availH; fw = fh * aspect; }
    this._frame = { x: (VIEW_W - fw) / 2, y: HUD + 20 + (availH - fh) / 2, w: fw, h: fh };

    const cols = Math.max(8, Math.round(fw / CELL));
    const rows = Math.max(6, Math.round(fh / CELL));
    // preserve any progress on resize by remapping fractional coverage
    const prev = this._cover;
    const prevC = this._cols;
    const prevR = this._rows;
    this._cols = cols;
    this._rows = rows;
    this._cover = new Uint8Array(cols * rows).fill(1);
    if (prev && prevC && prevR) {
      for (let r = 0; r < rows; r++) {
        for (let c = 0; c < cols; c++) {
          const pc = Math.min(prevC - 1, (c / cols * prevC) | 0);
          const pr = Math.min(prevR - 1, (r / rows * prevR) | 0);
          this._cover[r * cols + c] = prev[pr * prevC + pc];
        }
      }
    }
  }

  resize() {
    this._geo();
    this._overlay.reflow(VIEW_W / 2, VIEW_H / 2 + 20);
  }

  _revealed() {
    if (!this._cover) return 0;
    let open = 0;
    for (let i = 0; i < this._cover.length; i++) if (!this._cover[i]) open++;
    return open / this._cover.length;
  }

  _wipeAt(x, y) {
    if (this._done || !this._frame) return;
    const f = this._frame;
    if (x < f.x - 20 || x > f.x + f.w + 20 || y < f.y - 20 || y > f.y + f.h + 20) return;
    const cw = f.w / this._cols;
    const ch = f.h / this._rows;
    const rad = LEVELS[this._level].sponge;
    const c0 = clamp(Math.floor((x - rad - f.x) / cw), 0, this._cols - 1);
    const c1 = clamp(Math.ceil((x + rad - f.x) / cw), 0, this._cols - 1);
    const r0 = clamp(Math.floor((y - rad - f.y) / ch), 0, this._rows - 1);
    const r1 = clamp(Math.ceil((y + rad - f.y) / ch), 0, this._rows - 1);
    let changed = false;
    for (let r = r0; r <= r1; r++) {
      for (let c = c0; c <= c1; c++) {
        const idx = r * this._cols + c;
        if (!this._cover[idx]) continue;
        const cx = f.x + (c + 0.5) * cw;
        const cy = f.y + (r + 0.5) * ch;
        if ((cx - x) ** 2 + (cy - y) ** 2 <= rad * rad) {
          this._cover[idx] = 0;
          changed = true;
        }
      }
    }
    if (changed && !this._wipeCd) {
      playSound(SND_WIPE, { volume: 0.35, rate: 1.4 });
      this._wipeCd = 0.08;
    }
    if (this._revealed() >= LEVELS[this._level].target) this._finish();
  }

  _finish() {
    if (this._done) return;
    this._done = true;
    this._cover.fill(0);            // sweep the rest away
    playSound(SND_WIN, { channel: 'music' });
    const last = this._level >= LEVELS.length - 1;
    this._overlay.show(
      last ? 'Every painting uncovered!' : 'Nice wiping!',
      buttonRow(
        last ? [['Play Again', 'replay'], ['Menu', 'menu']]
             : [['Next Level', 'next'], ['Menu', 'menu']],
        VIEW_W / 2, VIEW_H / 2 + 20,
      ),
    );
  }

  update(dt) {
    if (this._wipeCd) this._wipeCd = Math.max(0, this._wipeCd - dt);
  }

  pointerdown(x, y) {
    if (this._overlay.visible) return;
    this._drag = true;
    this._ptr = { x, y };
    this._wipeAt(x, y);
  }

  pointermove(x, y) {
    this._overlay.pointermove(x, y);
    this._ptr = { x, y };
    if (this._drag) this._wipeAt(x, y);
  }

  pointerup(x, y) {
    if (hudSpeakHit(x, y)) return speakHud();
    this._drag = false;
    if (this._overlay.visible) {
      const act = this._overlay.pointerup(x, y);
      if (act === 'next') this._startLevel(this._level + 1);
      else if (act === 'replay') this._startLevel(this._level);
      else if (act === 'menu') this._exit();
    }
  }

  render(ctx) {
    ctx.fillStyle = theme.bg;
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    const f = this._frame;
    if (f) {
      const im = this._img || (this._imgName && img(`backgrounds/${this._imgName}`));
      if (im && im.naturalWidth) ctx.drawImage(im, f.x, f.y, f.w, f.h);
      else {
        ctx.fillStyle = theme.surface;
        ctx.fillRect(f.x, f.y, f.w, f.h);
      }

      // cover
      if (this._cover) {
        const cw = f.w / this._cols;
        const ch = f.h / this._rows;
        for (let r = 0; r < this._rows; r++) {
          for (let c = 0; c < this._cols; c++) {
            if (!this._cover[r * this._cols + c]) continue;
            const shade = 60 + ((c * 7 + r * 13) % 22);
            ctx.fillStyle = `rgb(${shade},${shade + 4},${shade + 10})`;
            ctx.fillRect(f.x + c * cw - 0.5, f.y + r * ch - 0.5, cw + 1, ch + 1);
          }
        }
      }

      ctx.strokeStyle = theme.line;
      ctx.lineWidth = 4;
      ctx.strokeRect(f.x, f.y, f.w, f.h);

      // sponge cursor
      if (this._ptr && !this._done && !this._overlay.visible) {
        ctx.strokeStyle = 'rgba(255,255,255,0.6)';
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.arc(this._ptr.x, this._ptr.y, LEVELS[this._level].sponge, 0, Math.PI * 2);
        ctx.stroke();
      }
    }

    // HUD
    ctx.fillStyle = theme.hud;
    ctx.fillRect(0, 0, VIEW_W, HUD);
    ctx.fillStyle = theme.line;
    ctx.fillRect(0, HUD - 1, VIEW_W, 1);
    ctx.fillStyle = theme.hud_text;
    ctx.font = '600 22px system-ui, sans-serif';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    const pct = Math.round(this._revealed() * 100);
    const goal = Math.round(LEVELS[this._level].target * 100);
    ctx.fillText(`L${this._level + 1}/${LEVELS.length}   ·   ${pct}%  (goal ${goal}%)`, 24, HUD / 2);
    ctx.textAlign = 'center';
    ctx.fillStyle = theme.hud_muted;
    ctx.fillText('drag to wipe the cover away', VIEW_W / 2, HUD / 2);
    hudSpeakButton(ctx, 'drag to wipe the cover away', VIEW_W / 2, HUD / 2);

    this._overlay.render(ctx, VIEW_W, VIEW_H);
  }
}
