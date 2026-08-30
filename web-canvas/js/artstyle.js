// artstyle.js — the alternate-art overlay switch (Design Policy §C.4).
//
// Independent of light/dark (theme.js). "classic" = the base pools only.
// Any other value makes engine.resolveImage() look first for a same-named
// file under  web-canvas/assets/themes/<style>/<pool>/<name>  (indexed into
// manifest.json by sync-assets.sh as  themes/<style>/<pool>/<name> ), and
// fall back to the base pool when that style has no art for a given asset.
//
// So the ext fallback (svg > png > jpg) is always on; this just points the
// loader at an overlay directory first. Ship-ready even with no overlay art
// present — it is a transparent pass-through until a themes/ dir exists.

const KEY = 'cp:artstyle';
export const CLASSIC = 'classic';

// Styles the UI offers. "classic" is always first; the rest appear only if
// manifest.json actually carries `themes/<style>/…` keys (see refresh()).
const KNOWN = ['classic', 'modern'];

const state = { style: CLASSIC, available: [CLASSIC] };
const listeners = new Set();

export function getArtStyle() { return state.style; }
export function artStyles() { return state.available.slice(); }

/** Inspect a loaded manifest and record which overlay styles have art. */
export function refreshArtStyles(manifest) {
  const seen = new Set([CLASSIC]);
  for (const k of Object.keys(manifest || {})) {
    const m = /^themes\/([^/]+)\//.exec(k);
    if (m) seen.add(m[1]);
  }
  state.available = KNOWN.filter((s) => seen.has(s))
    .concat([...seen].filter((s) => !KNOWN.includes(s)));
  if (!state.available.includes(state.style)) setArtStyle(CLASSIC);
}

export function setArtStyle(style) {
  const s = state.available.includes(style) ? style : CLASSIC;
  if (s === state.style) return s;
  state.style = s;
  try { localStorage.setItem(KEY, s); } catch { /* private mode */ }
  for (const fn of listeners) fn(s);
  return s;
}

export function toggleArtStyle() {
  const list = state.available;
  if (list.length < 2) return state.style;
  const i = list.indexOf(state.style);
  return setArtStyle(list[(i + 1) % list.length]);
}

/** Register a callback fired after the style changes (menu / games reload art). */
export function onArtStyleChange(fn) { listeners.add(fn); return () => listeners.delete(fn); }

export function initArtStyle() {
  let s = null;
  try { s = localStorage.getItem(KEY); } catch { /* ignore */ }
  if (s && typeof s === 'string') state.style = s;
  return state.style;
}
