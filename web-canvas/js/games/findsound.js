// findsound.js — hear a sound, tap the picture it belongs to.
//
// Each level is a themed board of pictures (animals, vehicles,
// instruments...). A round plays one picture's clip; find them all to
// clear the level. Wrong taps just wobble — no penalty.

import { Scene, VIEW_W, VIEW_H, img, playSound, loadSound, loadManifest } from '../engine.js';
import { roundRect, drawImageFit, shuffle, inRect, Overlay, buttonRow, drawButton, makeNameToggle, nameFromId, poolKeys } from '../util.js';
import { theme } from '../theme.js';

// A level = a graphics pool folder; its cards = every picture in that pool
// that has a matching soundmemory/<stem>.ogg (picture & clip pair by stem).
// No data file — add a picture + its clip, done.
const LEVEL_POOLS = ['animals', 'vehicles', 'instruments', 'sounds'];
const LEVEL_NAME = { animals: 'Animals', vehicles: 'Vehicles', instruments: 'Instruments', sounds: 'Noises' };
const MAX_CARDS = 9;

const SND_GOOD = 'sfx/good.ogg';
const SND_BAD = 'sfx/wrong.ogg';
const SND_WIN = 'sfx/winner.ogg';

const IMG = (pool, id) => `${pool}/${id}`;
const CLIP = (id) => `soundmemory/snd/${id}.ogg`;

export default class FindSoundGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._overlay = new Overlay();
    this._names = makeNameToggle('findsound', { x: VIEW_W - 172, y: 18, w: 150, h: 34 });
    this._levels = [];
    this._cards = [];
    this._level = 0;
    loadManifest().then((m) => {
      const snd = new Set(poolKeys(m, 'soundmemory/snd'));
      this._levels = LEVEL_POOLS
        .map((pool) => ({
          name: LEVEL_NAME[pool] || pool,
          pool,
          ids: shuffle(poolKeys(m, pool).filter((id) => snd.has(id))).slice(0, MAX_CARDS),
        }))
        .filter((lv) => lv.ids.length >= 3);
      if (this._levels.length) this._startLevel(0);
    });
  }

  _sayName(id) { this._names.say(nameFromId(id)); }

  _startLevel(n) {
    this._level = Math.max(0, Math.min(n, this._levels.length - 1));
    const lv = this._levels[this._level];
    this._pool = lv.pool;
    this._tries = 0;
    this._wobble = null;         // { card, t }
    this._overlay.hide();

    const cols = lv.ids.length <= 6 ? 3 : 4;
    const rows = Math.ceil(lv.ids.length / cols);
    const top = 150;
    const gw = VIEW_W - 140;
    const gh = VIEW_H - top - 50;
    const gap = 22;
    const cw = (gw - gap * (cols - 1)) / cols;
    const ch = (gh - gap * (rows - 1)) / rows;
    const size = Math.min(cw, ch, 230);
    const ox = (VIEW_W - (size * cols + gap * (cols - 1))) / 2;
    const oy = top + (gh - (size * rows + gap * (rows - 1))) / 2;

    this._cards = shuffle(lv.ids.slice()).map((id, i) => ({
      id,
      x: ox + (i % cols) * (size + gap),
      y: oy + ((i / cols) | 0) * (size + gap),
      s: size,
      found: false,
    }));

    // Preload every clip for the level, then start the first round.
    Promise.all(lv.ids.map((id) => loadSound(CLIP(id)))).then(() => this._nextRound());

    this._replayBtn = { x: VIEW_W / 2 - 130, y: 78, w: 260, h: 52, label: '🔊  Play again', action: 'replay' };
  }

  _nextRound() {
    const left = this._cards.filter((c) => !c.found);
    if (left.length === 0) return this._win();
    this._target = left[(Math.random() * left.length) | 0];
    this._playTarget();
  }

  _playTarget() {
    if (this._target) playSound(CLIP(this._target.id));
  }

  update(dt) {
    if (this._wobble) {
      this._wobble.t += dt;
      if (this._wobble.t > 0.45) this._wobble = null;
    }
  }

  _cardAt(x, y) {
    return this._cards.find((c) => !c.found && inRect({ x: c.x, y: c.y, w: c.s, h: c.s }, x, y));
  }

  pointermove(x, y) { this._overlay.pointermove(x, y); }

  pointerup(x, y) {
    if (this._overlay.visible) {
      const act = this._overlay.pointerup(x, y);
      if (act === 'next') this._startLevel(this._level + 1);
      else if (act === 'replay') this._startLevel(this._level);
      else if (act === 'menu') this._exit();
      return;
    }
    if (this._names.hit(x, y)) { this._names.toggle(); return; }
    if (inRect(this._replayBtn, x, y)) { this._playTarget(); return; }

    const c = this._cardAt(x, y);
    if (!c || !this._target) return;
    if (c.id === this._target.id) {
      c.found = true;
      playSound(SND_GOOD);
      this._sayName(c.id);
      this._nextRound();
    } else {
      this._tries++;
      this._wobble = { card: c, t: 0 };
      playSound(SND_BAD);
    }
  }

  _win() {
    playSound(SND_WIN, { channel: 'music' });
    const last = this._level >= this._levels.length - 1;
    const rows = [['Replay', 'replay'], ['Menu', 'menu']];
    if (!last) rows.unshift(['Next Level', 'next']);
    this._overlay.show(`You found them all!\n${this._tries} wrong tap${this._tries === 1 ? '' : 's'}`,
      buttonRow(rows, VIEW_W / 2, VIEW_H / 2 + 20, 190));
  }

  render(ctx) {
    ctx.fillStyle = theme.surface;
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);
    if (!this._levels.length) {
      ctx.fillStyle = theme.hud_muted;
      ctx.font = '600 24px system-ui, sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('loading…', VIEW_W / 2, VIEW_H / 2);
      return;
    }

    // HUD
    ctx.fillStyle = theme.hud;
    ctx.fillRect(0, 0, VIEW_W, 70);
    ctx.fillStyle = theme.line;
    ctx.fillRect(0, 70 - 1, VIEW_W, 1);
    ctx.fillStyle = theme.hud_text;
    ctx.font = '600 24px system-ui, sans-serif';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    const found = this._cards.filter((c) => c.found).length;
    ctx.fillText(`L${this._level + 1}/${this._levels.length} ${this._levels[this._level].name}  ·  found ${found}/${this._cards.length}`, 220, 35);
    this._names.rect.x = VIEW_W - 172;
    this._names.draw(ctx);

    if (!this._overlay.visible) drawButton(ctx, this._replayBtn, false);

    for (const c of this._cards) {
      let dx = 0;
      if (this._wobble && this._wobble.card === c) {
        dx = Math.sin(this._wobble.t * 50) * 8 * (1 - this._wobble.t / 0.45);
      }
      roundRect(ctx, c.x + dx, c.y, c.s, c.s, 16);
      ctx.fillStyle = c.found ? theme.good : theme.surface_alt;
      ctx.fill();
      ctx.save();
      ctx.globalAlpha = c.found ? 0.55 : 1;
      drawImageFit(ctx, img(IMG(this._pool, c.id)), c.x + dx + 12, c.y + 12, c.s - 24, c.s - 24);
      ctx.restore();
      if (c.found) {
        ctx.fillStyle = theme.good;
        ctx.font = `700 ${Math.round(c.s * 0.24)}px system-ui, sans-serif`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('✓', c.x + c.s - 22, c.y + 22);
      }
    }

    this._overlay.render(ctx, VIEW_W, VIEW_H);
  }
}
