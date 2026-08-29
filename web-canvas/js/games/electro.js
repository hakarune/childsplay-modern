// electro.js — the "Electro" wiring board. Two columns: animal pictures on
// the left, their names on the right (shuffled). Drag a wire from a picture
// to its name. Right connections lock in green; wrong ones just buzz and
// fall away. Connect every pair to clear the level. Six levels, 3 → 8 pairs.

import { Scene, VIEW_W, VIEW_H, img, loadImage, playSound } from '../engine.js';
import { clamp, roundRect, shuffle, dist, Overlay, buttonRow } from '../util.js';

const HUD = 56;
const SIDE = 44;
const PAIRS = [3, 4, 5, 6, 7, 8];

const ANIMALS = [
  '01_cat', '02_pig', '03_bear', '06_cow', '07_sheep', '09_panda',
  '14_fox', '17_lion', '21_frog', '12_wolf', '13_monkey', '16_elephant',
  '05_penguin', '08_turtle',
];
const label = (id) => id.replace(/^\d+_/, '').replace(/^\w/, (c) => c.toUpperCase());

const SND_PICK = 'sfx/dealcard1.wav';
const SND_GOOD = 'sfx/good.ogg';
const SND_WRONG = 'sfx/wrong.ogg';
const SND_WIN = 'sfx/winner.ogg';
const NODE_R = 13;

export default class ElectroGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._overlay = new Overlay();
    this._level = 0;
    this._startLevel(0);
  }

  _startLevel(n) {
    this._level = clamp(n, 0, PAIRS.length - 1);
    const count = PAIRS[this._level];
    const ids = shuffle(ANIMALS.slice()).slice(0, count);
    this._ids = ids.slice();
    this._rightIds = shuffle(ids.slice());
    for (const id of ids) loadImage(`memory/${id}.png`);
    this._solved = new Set();
    this._wrong = null;            // { a, b, t }  transient buzz
    this._drag = null;             // { col:'L'|'R', id, x, y }
    this._overlay.hide();
    this._geo();
  }

  _geo() {
    const count = PAIRS[this._level];
    this._tileW = clamp(VIEW_W * 0.30, 200, 340);
    const availH = VIEW_H - HUD - 56;
    const gap = 14;
    this._tileH = Math.min(94, (availH - gap * (count - 1)) / count);
    const gridH = count * this._tileH + gap * (count - 1);
    const top = HUD + 28 + Math.max(0, (availH - gridH) / 2);
    this._leftX = SIDE;
    this._rightX = VIEW_W - SIDE - this._tileW;
    this._rowY = (i) => top + i * (this._tileH + gap);
    this._leftNode = (i) => ({ x: this._leftX + this._tileW, y: this._rowY(i) + this._tileH / 2 });
    this._rightNode = (i) => ({ x: this._rightX, y: this._rowY(i) + this._tileH / 2 });
  }

  resize() {
    this._geo();
    this._overlay.reflow(VIEW_W / 2, VIEW_H / 2 + 20);
  }

  _nodeHit(x, y) {
    for (let i = 0; i < this._ids.length; i++) {
      if (!this._solved.has(this._ids[i])) {
        const n = this._leftNode(i);
        if (dist(x, y, n.x, n.y) < NODE_R * 2.2) return { col: 'L', id: this._ids[i], i };
      }
      if (!this._solved.has(this._rightIds[i])) {
        const n = this._rightNode(i);
        if (dist(x, y, n.x, n.y) < NODE_R * 2.2) return { col: 'R', id: this._rightIds[i], i };
      }
    }
    return null;
  }

  pointerdown(x, y) {
    if (this._overlay.visible) return;
    const hit = this._nodeHit(x, y);
    if (hit) {
      this._drag = { col: hit.col, id: hit.id, x, y };
      playSound(SND_PICK, { volume: 0.5 });
    }
  }

  pointermove(x, y) {
    this._overlay.pointermove(x, y);
    if (this._drag) { this._drag.x = x; this._drag.y = y; }
  }

  pointerup(x, y) {
    if (this._overlay.visible) {
      const act = this._overlay.pointerup(x, y);
      if (act === 'next') this._startLevel(this._level + 1);
      else if (act === 'replay') this._startLevel(this._level);
      else if (act === 'menu') this._exit();
      return;
    }
    if (!this._drag) return;
    const d = this._drag;
    this._drag = null;
    const hit = this._nodeHit(x, y);
    if (!hit || hit.col === d.col) return;      // needs to land on the other column

    if (hit.id === d.id) {
      this._solved.add(d.id);
      playSound(SND_GOOD);
      if (this._solved.size >= PAIRS[this._level]) this._levelDone();
    } else {
      this._wrong = { a: d.id, b: hit.id, t: 0 };
      playSound(SND_WRONG);
    }
  }

  _levelDone() {
    const last = this._level >= PAIRS.length - 1;
    if (last) {
      playSound(SND_WIN, { channel: 'music' });
      this._overlay.show('Every wire connected!',
        buttonRow([['Play Again', 'replay'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20));
    } else {
      playSound(SND_WIN, { volume: 0.6, channel: 'music' });
      this._overlay.show(`Level ${this._level + 1} done!`,
        buttonRow([['Next Level', 'next'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20));
    }
  }

  update(dt) {
    if (this._wrong) { this._wrong.t += dt; if (this._wrong.t > 0.5) this._wrong = null; }
  }

  _tile(ctx, x, y, w, h, fill) {
    roundRect(ctx, x, y, w, h, 14);
    ctx.fillStyle = fill;
    ctx.fill();
  }

  render(ctx) {
    ctx.fillStyle = '#141a24';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    const wrongIds = this._wrong ? [this._wrong.a, this._wrong.b] : [];

    // left column — pictures
    for (let i = 0; i < this._ids.length; i++) {
      const id = this._ids[i];
      const y = this._rowY(i);
      const done = this._solved.has(id);
      const buzz = wrongIds.includes(id);
      this._tile(ctx, this._leftX, y, this._tileW, this._tileH,
        buzz ? '#5b2b2b' : done ? '#26402c' : '#243247');
      const im = img(`memory/${id}.png`);
      if (im && im.naturalWidth) {
        const pad = 8;
        const s = Math.min((this._tileW - pad * 2) / im.naturalWidth, (this._tileH - pad * 2) / im.naturalHeight);
        const dw = im.naturalWidth * s;
        const dh = im.naturalHeight * s;
        ctx.drawImage(im, this._leftX + pad, y + (this._tileH - dh) / 2, dw, dh);
      }
      this._drawNode(ctx, this._leftNode(i), done);
    }

    // right column — names
    ctx.font = '600 24px system-ui, sans-serif';
    ctx.textBaseline = 'middle';
    for (let i = 0; i < this._rightIds.length; i++) {
      const id = this._rightIds[i];
      const y = this._rowY(i);
      const done = this._solved.has(id);
      const buzz = wrongIds.includes(id);
      this._tile(ctx, this._rightX, y, this._tileW, this._tileH,
        buzz ? '#5b2b2b' : done ? '#26402c' : '#243247');
      ctx.fillStyle = done ? '#8fd6a0' : '#eef2f7';
      ctx.textAlign = 'center';
      ctx.fillText(label(id), this._rightX + this._tileW / 2 + 8, y + this._tileH / 2);
      this._drawNode(ctx, this._rightNode(i), done);
    }

    // locked wires
    ctx.lineWidth = 6;
    ctx.lineCap = 'round';
    for (const id of this._solved) {
      const li = this._ids.indexOf(id);
      const ri = this._rightIds.indexOf(id);
      const a = this._leftNode(li);
      const b = this._rightNode(ri);
      this._wire(ctx, a, b, '#5fce6b');
    }
    // buzzing wire
    if (this._wrong) {
      const a = this._leftNode(this._ids.indexOf(this._wrong.a));
      const b = this._rightNode(this._rightIds.indexOf(this._wrong.b));
      ctx.globalAlpha = clamp(1 - this._wrong.t / 0.5, 0, 1);
      this._wire(ctx, a, b, '#ff5a5a');
      ctx.globalAlpha = 1;
    }
    // dragging wire
    if (this._drag) {
      const list = this._drag.col === 'L' ? this._ids : this._rightIds;
      const i = list.indexOf(this._drag.id);
      const a = this._drag.col === 'L' ? this._leftNode(i) : this._rightNode(i);
      this._wire(ctx, a, { x: this._drag.x, y: this._drag.y }, '#ffd93d');
    }

    // HUD
    ctx.fillStyle = 'rgba(16,21,32,0.6)';
    ctx.fillRect(0, 0, VIEW_W, HUD);
    ctx.fillStyle = '#eef2f7';
    ctx.font = '600 22px system-ui, sans-serif';
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    ctx.fillText(`Level ${this._level + 1}/${PAIRS.length}   ·   ${this._solved.size}/${PAIRS[this._level]} wired`, 200, HUD / 2);
    ctx.textAlign = 'center';
    ctx.fillStyle = '#9fb4d8';
    ctx.fillText('drag a wire from each picture to its name', VIEW_W / 2, HUD / 2);

    this._overlay.render(ctx, VIEW_W, VIEW_H);
  }

  _wire(ctx, a, b, color) {
    ctx.strokeStyle = color;
    ctx.beginPath();
    ctx.moveTo(a.x, a.y);
    const mx = (a.x + b.x) / 2;
    ctx.bezierCurveTo(mx, a.y, mx, b.y, b.x, b.y);
    ctx.stroke();
  }

  _drawNode(ctx, n, done) {
    ctx.beginPath();
    ctx.arc(n.x, n.y, NODE_R, 0, Math.PI * 2);
    ctx.fillStyle = done ? '#5fce6b' : '#8fa6c8';
    ctx.fill();
    ctx.fillStyle = '#141a24';
    ctx.beginPath();
    ctx.arc(n.x, n.y, NODE_R * 0.45, 0, Math.PI * 2);
    ctx.fill();
  }
}
