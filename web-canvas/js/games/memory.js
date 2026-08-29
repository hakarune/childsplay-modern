// memory.js — picture / letter / number pairs. Flip two cards; a match
// stays up. The `variant` option picks the deck:
//   pictures | lower | upper | numbers
// Grid grows 2x2 -> 4x3 -> 4x4 -> 5x4 across levels.

import { Scene, VIEW_W, VIEW_H, img, playSound } from '../engine.js';
import { roundRect, drawImageFit, shuffle, inRect, Overlay, buttonRow } from '../util.js';

const LEVELS = [
  { name: 'Toddler', cols: 2, rows: 2 },
  { name: 'Easy',    cols: 4, rows: 3 },
  { name: 'Medium',  cols: 4, rows: 4 },
  { name: 'Hard',    cols: 5, rows: 4 },
];

const PIC_NAMES = ['01_cat', '02_pig', '03_bear', '04_hippopotamus', '05_penguin',
  '06_cow', '07_sheep', '08_turtle', '09_panda', '10_chicken', '11_redbird',
  '12_wolf', '13_monkey', '14_fox', '15_bluebirds', '16_elephant', '17_lion',
  '18_gnu', '19_bluebaby', '20_greenbaby', '21_frog'];

const BACK = 'memory/CP_cardback.png';
const FRONT = 'memory/CP_cardfront.png';

const VARIANT_LABEL = { pictures: 'Pictures', lower: 'lowercase', upper: 'UPPERCASE', numbers: 'Numbers' };

const SND_FLIP = 'sfx/dealcard1.wav';
const SND_MATCH = 'sfx/good.ogg';
const SND_MISMATCH = 'sfx/wrong.ogg';
const SND_WIN = 'sfx/winner.ogg';

function deckFor(variant) {
  switch (variant) {
    case 'lower':
      return 'abcdefghijklmnopqrstuvwxyz'.split('').map((c) => ({ id: c, text: c }));
    case 'upper':
      return 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').map((c) => ({ id: c, text: c }));
    case 'numbers':
      return '0123456789'.split('').map((c) => ({ id: c, text: c }));
    default:
      return PIC_NAMES.map((n) => ({ id: n, img: `memory/${n}.png` }));
  }
}

export default class MemoryGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._variant = VARIANT_LABEL[opts.variant] ? opts.variant : 'pictures';
    this._deck = deckFor(this._variant);
    this._overlay = new Overlay();
    this._level = 0;
    this._startLevel(0);
  }

  _startLevel(n) {
    this._level = Math.max(0, Math.min(n, LEVELS.length - 1));
    const lv = LEVELS[this._level];
    this._pairs = Math.min((lv.cols * lv.rows) >> 1, this._deck.length);
    this._flips = 0;
    this._matched = 0;
    this._open = [];
    this._cool = 0;
    this._after = null;
    this._overlay.hide();

    const faces = shuffle(this._deck.slice()).slice(0, this._pairs);
    const cells = shuffle(faces.concat(faces));

    const marginX = 60;
    const top = 90;
    const bottom = 40;
    const gw = VIEW_W - marginX * 2;
    const gh = VIEW_H - top - bottom;
    const gap = 16;
    const cw = (gw - gap * (lv.cols - 1)) / lv.cols;
    const ch = (gh - gap * (lv.rows - 1)) / lv.rows;
    const size = Math.min(cw, ch);
    const ox = (VIEW_W - (size * lv.cols + gap * (lv.cols - 1))) / 2;
    const oy = top + (gh - (size * lv.rows + gap * (lv.rows - 1))) / 2;

    this._cards = cells.map((face, i) => ({
      face,
      x: ox + (i % lv.cols) * (size + gap),
      y: oy + ((i / lv.cols) | 0) * (size + gap),
      s: size,
      t: 0,        // flip anim 0=down 1=up
      up: false,
      matched: false,
    }));
  }

  update(dt) {
    for (const c of this._cards) {
      const target = c.up || c.matched ? 1 : 0;
      c.t += Math.sign(target - c.t) * Math.min(Math.abs(target - c.t), dt * 7);
    }
    if (this._cool > 0) {
      this._cool -= dt;
      if (this._cool <= 0 && this._after) {
        const fn = this._after;
        this._after = null;
        fn();
      }
    }
  }

  _cardAt(x, y) {
    return this._cards.find((c) => !c.matched && !c.up && inRect({ x: c.x, y: c.y, w: c.s, h: c.s }, x, y));
  }

  pointermove(x, y) { this._overlay.pointermove(x, y); }

  pointerup(x, y) {
    if (this._overlay.visible) {
      const act = this._overlay.pointerup(x, y);
      if (act === 'next') this._startLevel(this._level + 1);
      else if (act === 'menu') this._exit();
      return;
    }
    if (this._cool > 0 || this._open.length >= 2) return;
    const c = this._cardAt(x, y);
    if (!c) return;
    c.up = true;
    playSound(SND_FLIP);
    this._open.push(c);
    if (this._open.length === 2) this._resolve();
  }

  _resolve() {
    this._flips++;
    const [a, b] = this._open;
    if (a.face.id === b.face.id) {
      this._cool = 0.4;
      this._after = () => {
        a.matched = b.matched = true;
        this._matched++;
        this._open = [];
        playSound(SND_MATCH);
        if (this._matched === this._pairs) this._win();
      };
    } else {
      this._cool = 0.85;
      this._after = () => {
        a.up = b.up = false;
        this._open = [];
        playSound(SND_MISMATCH);
      };
    }
  }

  _win() {
    playSound(SND_WIN);
    const last = this._level >= LEVELS.length - 1;
    const btns = last
      ? buttonRow([['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20)
      : buttonRow([['Next Level', 'next'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20);
    this._overlay.show(`Great job!\ncleared in ${this._flips} flips`, btns);
  }

  render(ctx) {
    ctx.fillStyle = '#222b3d';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    ctx.fillStyle = 'rgba(16,21,32,0.6)';
    ctx.fillRect(0, 0, VIEW_W, 70);
    ctx.fillStyle = '#eef2f7';
    ctx.font = '600 24px system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(`Flips ${this._flips}    Pairs ${this._matched}/${this._pairs}`, VIEW_W / 2, 35);
    ctx.textAlign = 'left';
    ctx.fillText(`Memory - ${VARIANT_LABEL[this._variant]}`, 220, 35);
    ctx.textAlign = 'right';
    ctx.fillText(`Level ${this._level + 1}/${LEVELS.length}`, VIEW_W - 24, 35);

    const back = img(BACK);
    const front = img(FRONT);
    for (const c of this._cards) {
      const sx = Math.abs(1 - 2 * c.t);       // 1 -> 0 -> 1
      const showFront = c.t > 0.5;
      const w = c.s * sx;
      const cx = c.x + c.s / 2;

      ctx.save();
      ctx.translate(cx, c.y);
      roundRect(ctx, -w / 2, 0, w, c.s, 12);
      ctx.fillStyle = c.matched ? '#3f7d52' : '#33405a';
      ctx.fill();
      ctx.clip();

      if (w > 2) {
        if (!showFront) {
          drawImageFit(ctx, back, -w / 2 + 6, 6, w - 12, c.s - 12);
        } else if (c.face.img) {
          drawImageFit(ctx, img(c.face.img), -w / 2 + 6, 6, w - 12, c.s - 12);
        } else {
          drawImageFit(ctx, front, -w / 2 + 6, 6, w - 12, c.s - 12);
          ctx.save();
          ctx.scale(sx, 1);            // squish the glyph with the flip
          ctx.fillStyle = '#1b2333';
          ctx.font = `700 ${Math.round(c.s * 0.5)}px system-ui, sans-serif`;
          ctx.textAlign = 'center';
          ctx.textBaseline = 'middle';
          ctx.fillText(c.face.text, 0, c.s / 2 + 2);
          ctx.restore();
        }
      }
      ctx.restore();

      if (c.matched) {
        ctx.strokeStyle = '#7be0a0';
        ctx.lineWidth = 3;
        roundRect(ctx, c.x + 1.5, c.y + 1.5, c.s - 3, c.s - 3, 12);
        ctx.stroke();
      }
    }

    this._overlay.render(ctx, VIEW_W, VIEW_H);
  }
}
