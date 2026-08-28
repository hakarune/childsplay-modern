// _stub.js — shared scaffold for minigames that are not fully ported yet.
//
// Gives a consistent "coming soon" scene: centred title, a short blurb,
// and a tap-anywhere-to-return affordance. Real activities replace this
// with their own Scene subclass but keep the same factory signature.

import { Scene, VIEW_W, VIEW_H } from '../engine.js';

export function makeStub({ title, blurb }) {
  return (engine, { onFinished }) => new StubScene({ title, blurb, onFinished });
}

class StubScene extends Scene {
  constructor({ title, blurb, onFinished }) {
    super();
    this._title = title;
    this._blurb = blurb;
    this._onFinished = onFinished;
    this._t = 0;
  }

  update(dt) {
    this._t += dt;
  }

  pointerup() {
    this._onFinished();
  }

  render(ctx) {
    ctx.fillStyle = '#1a2230';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    ctx.fillStyle = '#eef2f7';
    ctx.font = '600 64px system-ui, sans-serif';
    ctx.fillText(this._title, VIEW_W / 2, VIEW_H / 2 - 40);

    ctx.fillStyle = '#9fb0c9';
    ctx.font = '400 28px system-ui, sans-serif';
    ctx.fillText(this._blurb, VIEW_W / 2, VIEW_H / 2 + 24);

    // Gentle pulse so it is obvious the loop is running.
    const a = 0.5 + 0.5 * Math.sin(this._t * 3);
    ctx.fillStyle = `rgba(159, 176, 201, ${a})`;
    ctx.font = '400 22px system-ui, sans-serif';
    ctx.fillText('tap anywhere to go back', VIEW_W / 2, VIEW_H - 80);
  }
}
