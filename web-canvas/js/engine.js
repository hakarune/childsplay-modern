// engine.js — minimal canvas engine for Childsplay-Modern (web target).
//
// Responsibilities:
//   * own the <canvas> and its 2D context
//   * keep a fixed 1280x720 internal resolution, letterbox-scaled to the
//     viewport (handles phones, tablets, Chromebooks + device pixel ratio)
//   * run a single requestAnimationFrame loop
//   * dispatch normalised pointer events (mouse + touch) in game coords
//   * manage one active Scene at a time

export const VIEW_W = 1280;
export const VIEW_H = 720;

/**
 * A Scene is any object with optional lifecycle hooks:
 *   enter(engine)      — called once when the scene becomes active
 *   exit()             — called once when it is replaced
 *   update(dt)         — per-frame logic, dt in seconds
 *   render(ctx)        — per-frame drawing
 *   pointerdown/move/up(x, y) — input in 1280x720 space
 */
export class Scene {
  enter() {}
  exit() {}
  update() {}
  render() {}
  pointerdown() {}
  pointermove() {}
  pointerup() {}
}

export class Engine {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.scene = null;
    this._last = 0;
    this._raf = 0;
    this._scale = 1;
    this._offsetX = 0;
    this._offsetY = 0;

    this._onResize = this._onResize.bind(this);
    this._frame = this._frame.bind(this);

    window.addEventListener('resize', this._onResize);
    window.addEventListener('orientationchange', this._onResize);
    this._bindPointer();
    this._onResize();
  }

  /** Swap the active scene, running exit/enter hooks. */
  setScene(scene) {
    if (this.scene && this.scene.exit) this.scene.exit();
    this.scene = scene;
    if (scene && scene.enter) scene.enter(this);
  }

  start() {
    if (this._raf) return;
    this._last = performance.now();
    this._raf = requestAnimationFrame(this._frame);
  }

  stop() {
    cancelAnimationFrame(this._raf);
    this._raf = 0;
  }

  _frame(now) {
    const dt = Math.min((now - this._last) / 1000, 0.05);
    this._last = now;

    if (this.scene) {
      if (this.scene.update) this.scene.update(dt);
      const { ctx } = this;
      ctx.save();
      ctx.setTransform(this._scale, 0, 0, this._scale, this._offsetX, this._offsetY);
      ctx.clearRect(0, 0, VIEW_W, VIEW_H);
      if (this.scene.render) this.scene.render(ctx);
      ctx.restore();
    }

    this._raf = requestAnimationFrame(this._frame);
  }

  _onResize() {
    const dpr = window.devicePixelRatio || 1;
    const vw = window.innerWidth;
    const vh = window.innerHeight;

    // Fit 1280x720 inside the viewport, preserving aspect ratio.
    const scale = Math.min(vw / VIEW_W, vh / VIEW_H);
    const cssW = Math.round(VIEW_W * scale);
    const cssH = Math.round(VIEW_H * scale);

    this.canvas.style.width = cssW + 'px';
    this.canvas.style.height = cssH + 'px';
    this.canvas.width = Math.round(cssW * dpr);
    this.canvas.height = Math.round(cssH * dpr);

    this._scale = scale * dpr;
    this._offsetX = 0;
    this._offsetY = 0;
  }

  /** Convert a DOM event position into 1280x720 game coordinates. */
  _toGameCoords(clientX, clientY) {
    const rect = this.canvas.getBoundingClientRect();
    const x = (clientX - rect.left) / rect.width * VIEW_W;
    const y = (clientY - rect.top) / rect.height * VIEW_H;
    return [x, y];
  }

  _bindPointer() {
    const fwd = (type, ev) => {
      if (!this.scene || !this.scene[type]) return;
      const src = ev.touches && ev.touches[0] ? ev.touches[0]
                : ev.changedTouches && ev.changedTouches[0] ? ev.changedTouches[0]
                : ev;
      const [x, y] = this._toGameCoords(src.clientX, src.clientY);
      this.scene[type](x, y);
    };

    this.canvas.addEventListener('mousedown', (e) => fwd('pointerdown', e));
    this.canvas.addEventListener('mousemove', (e) => fwd('pointermove', e));
    window.addEventListener('mouseup', (e) => fwd('pointerup', e));

    this.canvas.addEventListener('touchstart', (e) => { e.preventDefault(); fwd('pointerdown', e); }, { passive: false });
    this.canvas.addEventListener('touchmove', (e) => { e.preventDefault(); fwd('pointermove', e); }, { passive: false });
    this.canvas.addEventListener('touchend', (e) => { e.preventDefault(); fwd('pointerup', e); }, { passive: false });
  }

  destroy() {
    this.stop();
    window.removeEventListener('resize', this._onResize);
    window.removeEventListener('orientationchange', this._onResize);
  }
}
