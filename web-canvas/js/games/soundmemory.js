// soundmemory.js — the cards hide sounds, not pictures. Tap a card to
// hear its clip; find the two that sound the same. A match reveals the
// matching picture.

import { Scene, VIEW_W, VIEW_H, img, playSound, loadManifest } from '../engine.js';
import { roundRect, drawImageFit, shuffle, inRect, Overlay, buttonRow, poolKeys } from '../util.js';
import { theme } from '../theme.js';

const LEVELS = [
  { name: 'Toddler', cols: 2, rows: 2 },
  { name: 'Easy',    cols: 4, rows: 2 },
  { name: 'Medium',  cols: 4, rows: 3 },
];

// Every (picture, clip) pair across the Find Sound pools: a picture in one
// of these pools that also has a soundmemory/<stem>.ogg.
const PICTURE_POOLS = ['animals', 'vehicles', 'instruments', 'sounds'];

const SND_MATCH = 'sfx/good.ogg';
const SND_MISMATCH = 'sfx/wrong.ogg';
const SND_WIN = 'sfx/winner.ogg';

export default class SoundMemoryGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._overlay = new Overlay();
    this._level = 0;
    this._set = [];                 // [{ id, pool }]
    this._cards = [];
    this._pairs = 0;
    this._matched = 0;
    this._tries = 0;
    loadManifest().then((m) => {
      const snd = new Set(poolKeys(m, 'soundmemory/snd'));
      this._set = PICTURE_POOLS.flatMap((pool) =>
        poolKeys(m, pool).filter((id) => snd.has(id)).map((id) => ({ id, pool })));
      if (this._set.length) this._startLevel(0);
    });
  }

  _startLevel(n) {
    this._level = Math.max(0, Math.min(n, LEVELS.length - 1));
    const lv = LEVELS[this._level];
    this._pairs = (lv.cols * lv.rows) >> 1;
    this._tries = 0;
    this._matched = 0;
    this._first = null;
    this._second = null;
    this._cool = 0;
    this._pulse = 0;
    this._overlay.hide();

    const picks = shuffle(this._set.slice()).slice(0, this._pairs);
    const cells = shuffle(picks.concat(picks));

    this._cards = cells.map((p) => ({ id: p.id, pool: p.pool, x: 0, y: 0, s: 0, matched: false }));
    this._place();
  }

  // Re-position cards for the current world size, keeping their state.
  _place() {
    const lv = LEVELS[this._level];
    const top = 90;
    const gw = VIEW_W - 120;
    const gh = VIEW_H - top - 40;
    const gap = 20;
    const cw = (gw - gap * (lv.cols - 1)) / lv.cols;
    const chh = (gh - gap * (lv.rows - 1)) / lv.rows;
    const size = Math.min(cw, chh, 240);
    const ox = (VIEW_W - (size * lv.cols + gap * (lv.cols - 1))) / 2;
    const oy = top + (gh - (size * lv.rows + gap * (lv.rows - 1))) / 2;

    this._cards.forEach((c, i) => {
      c.x = ox + (i % lv.cols) * (size + gap);
      c.y = oy + ((i / lv.cols) | 0) * (size + gap);
      c.s = size;
    });
  }

  resize() {
    if (this._cards && this._cards.length) this._place();
    this._overlay.reflow(VIEW_W / 2, VIEW_H / 2 + 20);
  }

  update(dt) {
    this._pulse += dt;
    if (this._cool > 0) {
      this._cool -= dt;
      if (this._cool <= 0) this._compare();
    }
  }

  _cardAt(x, y) {
    return this._cards.find((c) => !c.matched && inRect({ x: c.x, y: c.y, w: c.s, h: c.s }, x, y));
  }

  pointermove(x, y) { this._overlay.pointermove(x, y); }

  pointerup(x, y) {
    if (this._overlay.visible) {
      const act = this._overlay.pointerup(x, y);
      if (act === 'next') this._startLevel(this._level + 1);
      else if (act === 'menu') this._exit();
      return;
    }
    if (this._cool > 0) return;
    const c = this._cardAt(x, y);
    if (!c || c === this._first) return;

    // cut the previous card's clip the instant a new one is tapped
    if (this._clip) this._clip.stop();
    this._clip = playSound(`soundmemory/snd/${c.id}.ogg`);
    this._playing = c;
    this._pulse = 0;

    if (!this._first) { this._first = c; return; }
    this._second = c;
    this._tries++;
    this._cool = 1.0;               // let both clips be heard
  }

  _compare() {
    const a = this._first;
    const b = this._second;
    if (a && b && a.id === b.id) {
      a.matched = b.matched = true;
      this._matched++;
      playSound(SND_MATCH);
      if (this._matched === this._pairs) this._win();
    } else {
      playSound(SND_MISMATCH);
    }
    this._first = this._second = null;
    this._playing = null;
  }

  _win() {
    playSound(SND_WIN, { channel: 'music' });
    const last = this._level >= LEVELS.length - 1;
    const btns = last
      ? buttonRow([['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20)
      : buttonRow([['Next Level', 'next'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20);
    this._overlay.show(`Wonderful listening!\n${this._tries} tries`, btns);
  }

  render(ctx) {
    ctx.fillStyle = theme.surface;
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    ctx.fillStyle = theme.hud;
    ctx.fillRect(0, 0, VIEW_W, 70);
    ctx.fillStyle = theme.line;
    ctx.fillRect(0, 70 - 1, VIEW_W, 1);
    ctx.fillStyle = theme.hud_text;
    ctx.font = '600 24px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(`Tries ${this._tries}    Pairs ${this._matched}/${this._pairs}`, VIEW_W / 2, 35);
    ctx.textAlign = 'right';
    ctx.fillText(`Level ${this._level + 1}/${LEVELS.length}`, VIEW_W - 24, 35);

    for (const c of this._cards) {
      const first = c === this._first;
      const playing = c === this._playing && this._pulse < 0.6;

      roundRect(ctx, c.x, c.y, c.s, c.s, 16);
      ctx.fillStyle = c.matched ? '#4a9d5b' : first ? '#e0a021' : '#3b6ea5';
      ctx.fill();

      if (c.matched) {
        drawImageFit(ctx, img(`${c.pool}/${c.id}`), c.x + 12, c.y + 12, c.s - 24, c.s - 24);
      } else {
        const wob = playing ? 1 + 0.12 * Math.sin(this._pulse * 22) : 1;
        ctx.save();
        ctx.translate(c.x + c.s / 2, c.y + c.s / 2);
        ctx.scale(wob, wob);
        ctx.fillStyle = 'rgba(255,255,255,0.92)';
        ctx.font = `700 ${Math.round(c.s * 0.4)}px system-ui, sans-serif`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(playing ? '♪' : '?', 0, 4);
        ctx.restore();
      }
    }

    this._overlay.render(ctx, VIEW_W, VIEW_H);
  }
}
