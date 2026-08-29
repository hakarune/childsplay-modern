// engine.js — the web-canvas engine.
//
//   * state machine  — MainMenu + the five games, registered by name
//   * asset loader    — images & sounds under web-canvas/assets/, cached
//   * audio manager   — preload, cache, overlapping one-shot playback
//   * game loop        — rAF, fixed 1280x720 world, aspect-fit scaling,
//                        pointer/touch/key event normalisation
//
// Games are modules whose default export is (game, opts) => Scene.

// The world is a fixed 720-unit-tall canvas whose WIDTH flexes to match the
// viewport's aspect ratio, so the game fills the screen instead of being
// letter-boxed. VIEW_W is a live binding — engine._resize() reassigns it and
// every importer sees the new value. Games must read VIEW_W/VIEW_H inside
// their methods (never cache a width-derived constant at module scope) and
// implement resize() to re-lay-out.
export let VIEW_W = 1280;
export const VIEW_H = 720;

// In landscape the world aspect follows the viewport, clamped so layouts
// drawn around 16:9 don't distort on very square or very wide screens.
// In portrait the world stays a fixed 16:9 and is fit to the WIDTH, so the
// game still plays (letter-boxed top and bottom) without a device turn.
const MIN_ASPECT = 1.30;   // ~4:3  — iPad, older monitors
const MAX_ASPECT = 2.00;   // ~18:9 — wide laptops, split view
const REF_ASPECT = 16 / 9; // portrait / fallback world shape

const ASSET_ROOT = new URL('../assets/', import.meta.url).href;
const isImage = (p) => /\.(png|jpe?g|svg|webp|gif)$/i.test(p);

// ---------------------------------------------------------------------------
// Asset + audio manager
// ---------------------------------------------------------------------------

const _imgPromises = new Map();
const _imgReady = new Map();   // path -> HTMLImageElement (once loaded)
const _sndPromises = new Map();
const _sndReady = new Map();

export function assetURL(path) {
  return ASSET_ROOT + String(path).replace(/^\/+/, '');
}

export function loadImage(path) {
  if (_imgPromises.has(path)) return _imgPromises.get(path);
  const p = new Promise((resolve) => {
    const img = new Image();
    img.onload = () => { _imgReady.set(path, img); resolve(img); };
    img.onerror = () => { console.warn(`[assets] missing image: ${path}`); resolve(img); };
    img.src = assetURL(path);
  });
  _imgPromises.set(path, p);
  return p;
}

export function loadSound(path) {
  if (_sndPromises.has(path)) return _sndPromises.get(path);
  const p = new Promise((resolve) => {
    const a = new Audio();
    a.preload = 'auto';
    const done = () => { _sndReady.set(path, a); resolve(a); };
    a.addEventListener('canplaythrough', done, { once: true });
    a.addEventListener('error', () => { console.warn(`[assets] missing audio: ${path}`); resolve(a); }, { once: true });
    a.src = assetURL(path);
    a.load();
  });
  _sndPromises.set(path, p);
  return p;
}

export function preload(paths) {
  return Promise.all(paths.map((p) => (isImage(p) ? loadImage(p) : loadSound(p))));
}

/** Synchronous cache accessor for render loops: kicks off a load on first
 *  use and returns the element once ready, otherwise null. */
export function img(path) {
  if (!_imgReady.has(path) && !_imgPromises.has(path)) loadImage(path);
  return _imgReady.get(path) || null;
}

/** Overlapping one-shot playback. Safe to call before the first user
 *  gesture (the play() rejection is swallowed). */
export function playSound(path, { volume = 1, rate = 1 } = {}) {
  loadSound(path).then((base) => {
    try {
      const shot = base.cloneNode(true);
      shot.volume = volume;
      shot.playbackRate = rate;
      shot.play().catch(() => {});
    } catch {
      /* ignore */
    }
  });
}

// ---------------------------------------------------------------------------
// Scene base
// ---------------------------------------------------------------------------

export class Scene {
  constructor(game) { this.game = game; }
  enter() {}
  exit() {}
  update(_dt) {}
  render(_ctx) {}
  pointerdown(_x, _y) {}
  pointermove(_x, _y) {}
  pointerup(_x, _y) {}
  keydown(_e) {}
  keyup(_e) {}
  resize() {}
}

// ---------------------------------------------------------------------------
// Game — loop, states, input
// ---------------------------------------------------------------------------

export class Game {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.scene = null;
    this.stateName = null;
    this._states = new Map();
    this._scale = 1;
    this._last = 0;
    this._raf = 0;
    this.pointer = { x: 0, y: 0, down: false };

    this._loop = this._loop.bind(this);
    this._resize = this._resize.bind(this);
    this._bindInput();
    window.addEventListener('resize', this._resize);
    window.addEventListener('orientationchange', this._resize);
    this._resize();
  }

  /** register(name, (game, opts) => Scene) */
  register(name, factory) {
    this._states.set(name, factory);
    return this;
  }

  setState(name, opts = {}) {
    const factory = this._states.get(name);
    if (!factory) { console.error(`[engine] unknown state "${name}"`); return; }
    if (this.scene && this.scene.exit) this.scene.exit();
    this.stateName = name;
    this.scene = factory(this, opts);
    this.scene.game = this;
    if (this.scene.enter) this.scene.enter();
  }

  start() {
    if (this._raf) return;
    this._last = performance.now();
    this._raf = requestAnimationFrame(this._loop);
  }

  stop() {
    cancelAnimationFrame(this._raf);
    this._raf = 0;
  }

  _loop(now) {
    const dt = Math.min((now - this._last) / 1000, 0.05);
    this._last = now;

    const s = this.scene;
    if (s && s.update) s.update(dt);

    const c = this.ctx;
    c.save();
    c.setTransform(this._scale, 0, 0, this._scale, 0, 0);
    c.clearRect(0, 0, VIEW_W, VIEW_H);
    if (s && s.render) s.render(c);
    c.restore();

    this._raf = requestAnimationFrame(this._loop);
  }

  /** Re-fit the canvas now (e.g. after a layout class toggled the HUD strip). */
  relayout() { this._resize(); }

  _resize() {
    const dpr = window.devicePixelRatio || 1;

    // Available area = the canvas's container box, so CSS (the reserved HUD
    // strip, safe-area insets) decides how much room the game gets. Fall
    // back to the raw viewport when there's no layout yet.
    let availW = Math.max(1, window.innerWidth);
    let availH = Math.max(1, window.innerHeight);
    const host = this.canvas.parentElement;
    if (host && host.getBoundingClientRect) {
      const r = host.getBoundingClientRect();
      if (r.width > 0 && r.height > 0) { availW = r.width; availH = r.height; }
    }

    if (availW >= availH) {
      // landscape: world width tracks the viewport aspect (clamped) so the
      // aspect-fit below leaves little or no letter-box.
      const aspect = Math.min(MAX_ASPECT, Math.max(MIN_ASPECT, availW / availH));
      VIEW_W = Math.round(VIEW_H * aspect);
    } else {
      // portrait: keep a fixed 16:9 world, fit to width, letter-box vertically.
      VIEW_W = Math.round(VIEW_H * REF_ASPECT);
    }

    const scale = Math.min(availW / VIEW_W, availH / VIEW_H);
    const cssW = Math.round(VIEW_W * scale);
    const cssH = Math.round(VIEW_H * scale);

    this.canvas.style.width = cssW + 'px';
    this.canvas.style.height = cssH + 'px';
    this.canvas.width = Math.round(cssW * dpr);
    this.canvas.height = Math.round(cssH * dpr);
    this.ctx.imageSmoothingEnabled = true;
    this._scale = scale * dpr;

    if (this.scene && this.scene.resize) this.scene.resize();
  }

  _toWorld(clientX, clientY) {
    const r = this.canvas.getBoundingClientRect();
    return [
      ((clientX - r.left) / r.width) * VIEW_W,
      ((clientY - r.top) / r.height) * VIEW_H,
    ];
  }

  _bindInput() {
    const fwd = (type, clientX, clientY) => {
      const [x, y] = this._toWorld(clientX, clientY);
      this.pointer.x = x;
      this.pointer.y = y;
      if (type === 'pointerdown') this.pointer.down = true;
      if (type === 'pointerup') this.pointer.down = false;
      const s = this.scene;
      if (s && s[type]) s[type](x, y);
    };

    const cv = this.canvas;
    cv.addEventListener('mousedown', (e) => fwd('pointerdown', e.clientX, e.clientY));
    cv.addEventListener('mousemove', (e) => fwd('pointermove', e.clientX, e.clientY));
    window.addEventListener('mouseup', (e) => fwd('pointerup', e.clientX, e.clientY));

    cv.addEventListener('touchstart', (e) => {
      e.preventDefault();
      const t = e.changedTouches[0];
      fwd('pointerdown', t.clientX, t.clientY);
    }, { passive: false });
    cv.addEventListener('touchmove', (e) => {
      e.preventDefault();
      const t = e.changedTouches[0];
      fwd('pointermove', t.clientX, t.clientY);
    }, { passive: false });
    cv.addEventListener('touchend', (e) => {
      e.preventDefault();
      const t = e.changedTouches[0];
      fwd('pointerup', t.clientX, t.clientY);
    }, { passive: false });

    window.addEventListener('keydown', (e) => {
      if (this.scene && this.scene.keydown) this.scene.keydown(e);
    });
    window.addEventListener('keyup', (e) => {
      if (this.scene && this.scene.keyup) this.scene.keyup(e);
    });
  }
}
