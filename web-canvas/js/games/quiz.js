// quiz.js — the shared multiple-choice quiz engine (Design Policy §J/§H).
//
// Boots with opts.deck = a deck id; loads assets/data/quiz/<deck>.json,
// groups the questions by `level`, and runs each level as a short round:
// show a question (spoken via TTS + a 🔊 button), tap one of the shuffled
// answer buttons. A wrong tap just shakes — no penalty (§H.1.3). Clear a
// level's questions to advance; clear the last level to win.

import { Scene, VIEW_W, VIEW_H, img, loadImage, playSound } from '../engine.js';
import {
  clamp, roundRect, shuffle, inRect, Overlay, buttonRow,
  hudSpeakButton, hudSpeakHit, speakHud, loadData,
} from '../util.js';
import { theme } from '../theme.js';
import { speak } from '../tts.js';

const HUD = 64;

const SND_GOOD = 'sfx/good.ogg';
const SND_BAD = 'sfx/wrong.ogg';
const SND_WIN = 'sfx/winner.ogg';

const FALLBACK = {
  name: 'Quiz',
  prompt: 'tap the right answer',
  questions: [
    { level: 1, q: '2 + 2 = ?', choices: ['4', '3', '5'], answer: 0 },
    { level: 1, q: 'What colour is grass?', choices: ['Green', 'Blue', 'Red'], answer: 0 },
  ],
};

export default class QuizGame extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._exit = opts.onExit || (() => {});
    this._deckId = opts.deck || 'general';
    this._overlay = new Overlay();
    this._deck = FALLBACK;
    this._ready = false;
    this._level = 0;
    this._maxLevel = 1;

    loadData(`quiz/${this._deckId}`, FALLBACK).then((d) => {
      if (d && Array.isArray(d.questions) && d.questions.length) this._deck = d;
      this._maxLevel = this._deck.questions.reduce((m, q) => Math.max(m, q.level || 1), 1);
      this._ready = true;
      this._startLevel(0);
    });
  }

  _startLevel(n) {
    this._level = clamp(n, 0, this._maxLevel - 1);
    const want = this._level + 1;
    const pool = this._deck.questions.filter((q) => (q.level || 1) === want);
    this._questions = shuffle(pool.length ? pool : this._deck.questions).slice(0, 6);
    this._qi = 0;
    this._shake = null;             // { i, t }
    this._locked = false;          // brief pause after a correct answer
    this._pending = -1;            // choice armed by a first tap (§J two-tap)
    this._overlay.hide();
    this._loadQuestion();
  }

  _loadQuestion() {
    const q = this._questions[this._qi];
    if (!q) return;
    // shuffle the choice order, remember where the answer went
    const order = shuffle(q.choices.map((_, i) => i));
    this._choices = order.map((i) => q.choices[i]);
    this._answer = order.indexOf(q.answer);
    this._image = q.image || null;
    this._pending = -1;
    if (this._image) loadImage(this._image);
    this._geo();
    this._speak();
  }

  _speak() {
    const q = this._questions[this._qi];
    if (q) speak(q.q || this._deck.prompt || '');
  }

  _geo() {
    const q = this._questions[this._qi] || {};
    const n = (this._choices || q.choices || []).length;
    const hasImg = !!this._image;
    const top = HUD + 24;
    const qBoxH = hasImg ? 220 : 120;
    this._qBox = { x: 60, y: top, w: VIEW_W - 120, h: qBoxH };

    const bw = Math.min(560, VIEW_W - 160);
    const bh = 78;                                  // §I.1.2 primary target ≥ 72
    const gap = 18;
    const startY = top + qBoxH + 36;
    this._btns = [];
    for (let i = 0; i < n; i++) {
      this._btns.push({ x: (VIEW_W - bw) / 2, y: startY + i * (bh + gap), w: bw, h: bh });
    }
  }

  resize() {
    if (this._ready) this._geo();
    this._overlay.reflow(VIEW_W / 2, VIEW_H / 2 + 20);
  }

  update(dt) {
    if (this._shake) { this._shake.t += dt; if (this._shake.t > 0.4) this._shake = null; }
    if (this._locked) {
      this._locked -= dt;
      if (this._locked <= 0) {
        this._locked = false;
        this._qi += 1;
        if (this._qi >= this._questions.length) this._levelDone();
        else this._loadQuestion();
      }
    }
  }

  pointerup(x, y) {
    if (hudSpeakHit(x, y)) return speakHud();
    if (this._overlay.visible) {
      const act = this._overlay.pointerup(x, y);
      if (act === 'next') this._startLevel(this._level + 1);
      else if (act === 'replay') this._startLevel(this._level);
      else if (act === 'menu') this._exit();
      return;
    }
    if (!this._ready || this._locked) return;
    const i = this._btns.findIndex((b) => inRect(b, x, y));
    if (i < 0) return;

    // Two-tap answering (§J): the first tap on a choice reads it aloud and
    // arms it; a second tap on the SAME choice commits. Tapping a different
    // choice just moves the arm and speaks the new one.
    if (this._pending !== i) {
      this._pending = i;
      this._shake = null;
      speak(this._choices[i]);
      return;
    }

    this._pending = -1;
    if (i === this._answer) {
      playSound(SND_GOOD);
      this._locked = 0.45;
    } else {
      this._shake = { i, t: 0 };
      playSound(SND_BAD);
    }
  }

  _levelDone() {
    const last = this._level >= this._maxLevel - 1;
    if (last) {
      playSound(SND_WIN, { channel: 'music' });
      this._overlay.show('You finished the quiz!',
        buttonRow([['Play Again', 'replay'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20));
    } else {
      playSound(SND_WIN, { volume: 0.6, channel: 'music' });
      this._overlay.show(`Level ${this._level + 1} done!`,
        buttonRow([['Next Level', 'next'], ['Menu', 'menu']], VIEW_W / 2, VIEW_H / 2 + 20));
    }
  }

  render(ctx) {
    ctx.fillStyle = theme.bg;
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    if (!this._ready) {
      ctx.fillStyle = theme.text_muted;
      ctx.font = '500 24px system-ui, sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('loading…', VIEW_W / 2, VIEW_H / 2);
      return;
    }

    const q = this._questions[this._qi] || {};

    // question card
    const qb = this._qBox;
    roundRect(ctx, qb.x, qb.y, qb.w, qb.h, 16);
    ctx.fillStyle = theme.surface;
    ctx.fill();

    if (this._image) {
      const im = img(this._image);
      if (im && im.naturalWidth) {
        const box = qb.h - 24;
        const s = Math.min(box / im.naturalWidth, box / im.naturalHeight);
        const dw = im.naturalWidth * s, dh = im.naturalHeight * s;
        ctx.drawImage(im, qb.x + 16, qb.y + (qb.h - dh) / 2, dw, dh);
      }
    }

    ctx.fillStyle = theme.text;
    ctx.font = '600 28px system-ui, sans-serif';
    ctx.textAlign = this._image ? 'left' : 'center';
    ctx.textBaseline = 'middle';
    const tx = this._image ? qb.x + qb.h + 8 : qb.x + qb.w / 2;
    this._wrapText(ctx, q.q || '', tx, qb.y + qb.h / 2, this._image ? qb.w - qb.h - 24 : qb.w - 48, 34);

    // answer buttons
    ctx.font = '600 24px system-ui, sans-serif';
    this._btns.forEach((b, i) => {
      const dx = (this._shake && this._shake.i === i)
        ? Math.sin(this._shake.t * 50) * 8 * (1 - this._shake.t / 0.4) : 0;
      const armed = this._pending === i;
      roundRect(ctx, b.x + dx, b.y, b.w, b.h, 14);
      ctx.fillStyle = armed ? theme.accent : theme.surface_alt;
      ctx.fill();
      ctx.strokeStyle = armed ? theme.accent : theme.line;
      ctx.lineWidth = armed ? 4 : 2;
      ctx.stroke();
      ctx.fillStyle = armed ? '#fff' : theme.text;
      ctx.textAlign = 'center';
      ctx.fillText(this._choices[i], b.x + dx + b.w / 2, b.y + b.h / 2 + 1);
    });

    // HUD
    ctx.fillStyle = theme.hud;
    ctx.fillRect(0, 0, VIEW_W, HUD);
    ctx.fillStyle = theme.line;
    ctx.fillRect(0, HUD - 1, VIEW_W, 1);
    ctx.fillStyle = theme.hud_text;
    ctx.font = '600 22px system-ui, sans-serif';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    ctx.fillText(`${this._deck.name}  ·  L${this._level + 1}/${this._maxLevel}  ·  ${this._qi + 1}/${this._questions.length}`, 200, HUD / 2);
    const msg = q.q || this._deck.prompt || 'tap the right answer';
    ctx.textAlign = 'center';
    ctx.fillStyle = theme.hud_muted;
    ctx.fillText('tap to hear it, tap again to choose', VIEW_W / 2, HUD / 2);
    hudSpeakButton(ctx, msg, VIEW_W / 2, HUD / 2);

    this._overlay.render(ctx, VIEW_W, VIEW_H);
  }

  _wrapText(ctx, text, cx, cy, maxW, lineH) {
    const words = String(text).split(/\s+/);
    const lines = [];
    let line = '';
    for (const w of words) {
      const test = line ? `${line} ${w}` : w;
      if (ctx.measureText(test).width > maxW && line) { lines.push(line); line = w; }
      else line = test;
    }
    if (line) lines.push(line);
    const y0 = cy - ((lines.length - 1) * lineH) / 2;
    lines.forEach((l, i) => ctx.fillText(l, cx, y0 + i * lineH));
  }
}
