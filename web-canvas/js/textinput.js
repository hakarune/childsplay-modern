// textinput.js — dual keyboard for the letter games (Design Policy §I.3).
//
// Three input paths, all funnelling to one onChar(letter) callback:
//   1. a physical keyboard   (games already forward Scene.keydown)
//   2. the device's OS keyboard, summoned on demand via a hidden <input>
//      — the PRIMARY path on a touch device (big, familiar, autocorrect off)
//   3. the in-canvas QWERTY the game draws — always available as the
//      accessibility path (switch access, no-hands, kiosk with no OS kbd)
//
// A visible "⌨" toggle (the game draws it) flips between 2 and 3. The
// choice is remembered per game id.

const isTouch = (typeof window !== 'undefined')
  && (('ontouchstart' in window)
    || (navigator.maxTouchPoints > 0)
    || (window.matchMedia && window.matchMedia('(pointer: coarse)').matches));

export class TextInput {
  /** @param {string} gameId  @param {(ch:string)=>void} onChar */
  constructor(gameId, onChar) {
    this._key = `cp:osk:${gameId}`;
    this._onChar = onChar;
    this.isTouch = isTouch;

    // default: OS keyboard on touch, in-canvas otherwise (physical is king
    // on desktop, and the drawn keyboard is the visible fallback there).
    let saved = null;
    try { saved = localStorage.getItem(this._key); } catch { /* */ }
    this.osk = saved === null ? isTouch : saved === '1';

    this._el = document.createElement('input');
    this._el.type = 'text';
    this._el.setAttribute('autocomplete', 'off');
    this._el.setAttribute('autocorrect', 'off');
    this._el.setAttribute('autocapitalize', 'characters');
    this._el.setAttribute('aria-label', 'Type letters for the game');
    this._el.setAttribute('inputmode', 'text');
    Object.assign(this._el.style, {
      position: 'fixed', left: '0', bottom: '0', width: '1px', height: '1px',
      opacity: '0.001', border: '0', padding: '0', margin: '0',
      background: 'transparent', color: 'transparent', caretColor: 'transparent',
      zIndex: '-1', transform: 'translateY(200%)',
    });
    this._el.addEventListener('input', () => {
      const v = this._el.value;
      const ch = v ? v[v.length - 1].toUpperCase() : '';
      this._el.value = '';
      // only the OS-keyboard path drives onChar; physical keys reach the
      // game through Scene.keydown, so this guard prevents a double type.
      if (this.osk && ch >= 'A' && ch <= 'Z') this._onChar(ch);
    });
    // keep focus while OS-keyboard mode is on and an overlay isn't up
    this._el.addEventListener('blur', () => {
      if (this._active && this.osk) setTimeout(() => { try { this._el.focus(); } catch { /* */ } }, 0);
    });
    document.body.appendChild(this._el);
    this._active = false;
  }

  /** Game entered — start listening; on touch+osk, wait for present(). */
  start() { this._active = true; if (this.osk && !isTouch) this._focus(); }

  /** Game left — clean up. */
  stop() {
    this._active = false;
    try { this._el.blur(); } catch { /* */ }
    if (this._el.parentNode) this._el.parentNode.removeChild(this._el);
  }

  /** Whether the game should draw its in-canvas keyboard right now. */
  get showCanvasKeyboard() { return !this.osk; }

  /** Flip OS-keyboard vs in-canvas. Call from a pointer handler (a user
   *  gesture) so focusing the input is allowed to raise the OS keyboard. */
  toggle() {
    this.osk = !this.osk;
    try { localStorage.setItem(this._key, this.osk ? '1' : '0'); } catch { /* */ }
    if (this.osk) this._focus(); else this._blur();
    return this.osk;
  }

  /** Re-assert the OS keyboard (e.g. after closing a win overlay). */
  present() { if (this.osk) this._focus(); }
  dismiss() { this._blur(); }

  _focus() { try { this._el.focus({ preventScroll: true }); } catch { /* */ } }
  _blur() { try { this._el.blur(); } catch { /* */ } }
}
