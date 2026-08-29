// theme.js — the named-role colour palette (Design Policy §D).
//
// Game code reads `theme.<role>` every frame and MUST NOT contain colour
// literals. `setTheme('light'|'dark')` mutates the live `theme` object in
// place (so importers keep their reference), stamps
// document.documentElement.dataset.theme, and mirrors every role to a CSS
// custom property `--cp-<role>` on :root for the HTML chrome.

export const ROLES = [
  'bg', 'surface', 'surface_alt', 'text', 'text_muted',
  'accent', 'accent_press', 'good', 'bad', 'warn',
  'line', 'overlay_scrim', 'p1', 'p2',
];

// Contrast-checked against their own bg/surface (WCAG AA for text, 3:1 for
// lines and graphic elements) — see docs/Design-Policy.md §D.4.
export const DARK = {
  bg: '#12161f',
  surface: '#232c3d',
  surface_alt: '#374663',
  text: '#eef2f7',
  text_muted: '#a6b8d6',
  accent: '#5b8cff',
  accent_press: '#3a63d0',
  good: '#6ee38a',
  bad: '#ff6b6b',
  warn: '#ffb454',
  line: '#5a7bb5',
  overlay_scrim: 'rgba(4,7,12,0.66)',
  p1: '#ff6b6b',
  p2: '#ffd93d',
};

export const LIGHT = {
  bg: '#eef1f6',
  surface: '#ffffff',
  surface_alt: '#d7e0f2',
  text: '#1a2330',
  text_muted: '#525d70',
  accent: '#2f5fe0',
  accent_press: '#1f43b0',
  good: '#137a37',
  bad: '#c62f2f',
  warn: '#9a5b00',
  line: '#7183a8',
  overlay_scrim: 'rgba(12,17,26,0.55)',
  p1: '#c62f2f',
  p2: '#b07500',
};

// live object — imported by reference everywhere
export const theme = { ...DARK, mode: 'dark' };

const KEY = 'cp:theme';

function _apply(mode) {
  const src = mode === 'light' ? LIGHT : DARK;
  for (const r of ROLES) theme[r] = src[r];
  theme.mode = mode;
  if (typeof document !== 'undefined' && document.documentElement) {
    const root = document.documentElement;
    root.dataset.theme = mode;
    for (const r of ROLES) root.style.setProperty(`--cp-${r.replace(/_/g, '-')}`, src[r]);
  }
}

export function getTheme() { return theme.mode; }

export function setTheme(mode) {
  const m = mode === 'light' ? 'light' : 'dark';
  _apply(m);
  try { localStorage.setItem(KEY, m); } catch { /* private mode */ }
  return m;
}

export function toggleTheme() {
  return setTheme(theme.mode === 'light' ? 'dark' : 'light');
}

// Resolve the startup theme: saved choice → OS preference → dark.
export function initTheme() {
  let m = null;
  try { m = localStorage.getItem(KEY); } catch { /* ignore */ }
  if (m !== 'light' && m !== 'dark') {
    m = (typeof window !== 'undefined' && window.matchMedia
      && window.matchMedia('(prefers-color-scheme: light)').matches) ? 'light' : 'dark';
  }
  _apply(m);
  return m;
}
