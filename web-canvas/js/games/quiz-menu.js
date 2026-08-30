// quiz-menu.js — the "Quiz" tile opens this: a picker for the quiz decks.
// Picking one hands ('quiz', { deck, variant }) back to main.js's launcher,
// which boots the shared engine (quiz.js) with that deck.

import { Scene, VIEW_W, VIEW_H } from '../engine.js';
import { roundRect, inRect } from '../util.js';
import { theme } from '../theme.js';

const TITLE_H = 150;
const PAD = 70;
const GAP = 32;

const DECKS = [
  { deck: 'general', label: 'General', sample: '💡' },
  { deck: 'picture', label: 'Pictures', sample: '🐾' },
  { deck: 'math',    label: 'Math',    sample: '➕' },
  { deck: 'words',   label: 'Words',   sample: 'A B' },
  { deck: 'sayings', label: 'Sayings', sample: '💬' },
];

export class QuizMenu extends Scene {
  constructor(game, opts = {}) {
    super(game);
    this._onPick = opts.onPick || (() => {});
    this._tiles = [];
    this._hover = -1;
    this._press = -1;
  }

  enter() { this._layout(); }
  resize() { this._layout(); }

  _layout() {
    const cols = 3;
    const rows = Math.ceil(DECKS.length / cols);
    const availW = VIEW_W - PAD * 2;
    const availH = VIEW_H - TITLE_H - PAD;
    const tw = (availW - GAP * (cols - 1)) / cols;
    const th = Math.min(tw * 0.78, (availH - GAP * (rows - 1)) / rows);
    const gridW = cols * tw + (cols - 1) * GAP;
    const gridH = rows * th + (rows - 1) * GAP;
    const sx = (VIEW_W - gridW) / 2;
    const sy = TITLE_H + (availH - gridH) / 2;

    this._tiles = DECKS.map((d, i) => ({
      d,
      x: sx + (i % cols) * (tw + GAP),
      y: sy + Math.floor(i / cols) * (th + GAP),
      w: tw,
      h: th,
    }));
  }

  _hit(x, y) { return this._tiles.findIndex((t) => inRect(t, x, y)); }

  pointermove(x, y) { this._hover = this._hit(x, y); }
  pointerdown(x, y) { this._press = this._hit(x, y); }

  pointerup(x, y) {
    const i = this._hit(x, y);
    if (i >= 0 && i === this._press) {
      const d = this._tiles[i].d;
      this._onPick('quiz', { deck: d.deck, variant: d.label });
    }
    this._press = -1;
  }

  render(ctx) {
    ctx.fillStyle = theme.bg;
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = theme.text;
    ctx.font = '700 56px system-ui, sans-serif';
    ctx.fillText('Quiz', VIEW_W / 2, TITLE_H / 2 - 4);
    ctx.fillStyle = theme.text_muted;
    ctx.font = '400 24px system-ui, sans-serif';
    ctx.fillText('pick a quiz', VIEW_W / 2, TITLE_H / 2 + 40);

    this._tiles.forEach((t, i) => {
      const pressed = i === this._press;
      const hovered = i === this._hover && !pressed;
      const k = pressed ? 4 : 0;
      roundRect(ctx, t.x + k, t.y + k, t.w - k * 2, t.h - k * 2, 24);
      ctx.fillStyle = pressed ? theme.accent_press : hovered ? theme.surface_alt : theme.surface;
      ctx.fill();

      ctx.fillStyle = theme.text;
      ctx.font = `700 ${Math.round(t.h * 0.34)}px system-ui, sans-serif`;
      ctx.fillText(t.d.sample, t.x + t.w / 2, t.y + t.h * 0.42);

      ctx.fillStyle = '#ffffff';
      ctx.font = `600 ${Math.round(t.h * 0.15)}px system-ui, sans-serif`;
      ctx.fillText(t.d.label, t.x + t.w / 2, t.y + t.h - t.h * 0.16);
    });
  }
}
