// main.js — bootstrap + navigation.
//
//   MainMenu tile  -> a game, except the "memory" tile which opens the
//                     Memory sub-menu (memory-menu.js).
//   Memory sub-menu -> a memory variant (memory.js) or Sound Memory.
//
// Games are lazy-imported and re-instantiated per launch (a clean reset).

import { Game, loadManifest, setMuted, isMuted } from './engine.js';
import { MainMenu } from './menu.js';
import { MemoryMenu } from './games/memory-menu.js';
import { getGame } from './games/index.js';
import { resetBags } from './util.js';
import { initTheme, toggleTheme, getTheme } from './theme.js';
import { initArtStyle, toggleArtStyle, getArtStyle, artStyles } from './artstyle.js';

const canvas = document.getElementById('game-canvas');
const hud = document.getElementById('hud');
const backBtn = document.getElementById('back-btn');
const title = document.getElementById('activity-name');
const splash = document.getElementById('splash');
const fsBtn = document.getElementById('fs-btn');
const themeBtn = document.getElementById('theme-btn');
const artBtn = document.getElementById('art-btn');
const muteBtn = document.getElementById('mute-btn');
const mutePop = document.getElementById('mute-pop');

// --- theme toggle --------------------------------------------------------
initTheme();
const syncThemeBtn = () => { themeBtn.textContent = getTheme() === 'light' ? '☾' : '☀'; };
syncThemeBtn();
themeBtn.addEventListener('click', () => { toggleTheme(); syncThemeBtn(); });

// --- artwork-style toggle (Policy §C.4) — shown only if overlay art exists,
// which loadManifest()/refreshArtStyles() decides once the manifest is in.
initArtStyle();
function syncArtBtn() {
  const styles = artStyles();
  artBtn.hidden = styles.length < 2;
  const s = getArtStyle();
  artBtn.title = `Artwork: ${s}` + (styles.length > 1 ? ` (tap for ${styles[(styles.indexOf(s) + 1) % styles.length]})` : '');
  artBtn.dataset.style = s;
}
artBtn.addEventListener('click', () => {
  toggleArtStyle();
  syncArtBtn();
  // Menus reload art immediately; a running game picks it up on its next
  // screen (re-resolving mid-level would restart it).
  if (game.stateName === 'MainMenu' || game.stateName === 'MemoryMenu') {
    game.setState(game.stateName);
  }
});

// --- sound popover (music / sfx / voice, independent) ------------------
// A checkbox is CHECKED when that channel is ON (audible).
for (const cb of mutePop.querySelectorAll('input[data-ch]')) {
  const ch = cb.dataset.ch;
  let on = true;
  try { on = localStorage.getItem(`cp:snd:${ch}`) !== '0'; } catch { /* */ }
  cb.checked = on;
  setMuted(ch, !on);
  cb.addEventListener('change', () => {
    setMuted(ch, !cb.checked);
    try { localStorage.setItem(`cp:snd:${ch}`, cb.checked ? '1' : '0'); } catch { /* */ }
    syncMuteBtn();
  });
}
function syncMuteBtn() {
  const anyOff = ['music', 'sfx', 'voice'].some((c) => isMuted(c));
  muteBtn.textContent = anyOff ? '🔇' : '🔊';
}
syncMuteBtn();
muteBtn.addEventListener('click', (e) => { e.stopPropagation(); mutePop.hidden = !mutePop.hidden; });
window.addEventListener('pointerdown', (e) => {
  if (!mutePop.hidden && !mutePop.contains(e.target) && e.target !== muteBtn) mutePop.hidden = true;
});

// --- fullscreen toggle -----------------------------------------------------
const fsEl = document.documentElement;
const canFullscreen = !!(fsEl.requestFullscreen || fsEl.webkitRequestFullscreen);
if (!canFullscreen) {
  fsBtn.hidden = true;
} else {
  fsBtn.addEventListener('click', () => {
    const d = document;
    const on = d.fullscreenElement || d.webkitFullscreenElement;
    if (on) (d.exitFullscreen || d.webkitExitFullscreen).call(d);
    else (fsEl.requestFullscreen || fsEl.webkitRequestFullscreen).call(fsEl);
  });
  const sync = () => {
    const on = document.fullscreenElement || document.webkitFullscreenElement;
    fsBtn.textContent = on ? '✕' : '⛶';
    fsBtn.title = on ? 'Exit fullscreen' : 'Fullscreen';
  };
  document.addEventListener('fullscreenchange', sync);
  document.addEventListener('webkitfullscreenchange', sync);
}

const game = new Game(canvas);

// Which handler the HUD Back button runs, per screen.
let backHandler = toMainMenu;
backBtn.addEventListener('click', () => backHandler());

game.register('MainMenu', (g) => new MainMenu(g, { onSelect }));
game.register('MemoryMenu', (g) => new MemoryMenu(g, { onPick: launchFromMemory }));

function onSelect(id) {
  if (id === 'memory') return openMemoryMenu();
  launch(id, {}, toMainMenu);
}

// Show/hide the top HUD strip. `body.in-game` reserves that strip in the
// layout (CSS) so the game's own on-canvas HUD isn't covered; relayout()
// re-fits the canvas into the new box.
function setHud(visible) {
  hud.hidden = !visible;
  document.body.classList.toggle('in-game', visible);
  game.relayout();
}

function openMemoryMenu() {
  title.textContent = 'Memory';
  backHandler = toMainMenu;
  setHud(true);
  game.setState('MemoryMenu');
}

function launchFromMemory(id, opts) {
  launch(id, opts, openMemoryMenu);
}

async function launch(id, opts, back) {
  const entry = getGame(id);
  if (!entry) return;
  title.textContent = opts.variant
    ? `${entry.name} – ${opts.variant}`
    : entry.name;
  backHandler = back;
  resetBags(`${id}:`);             // fresh no-repeat bags for this game (Policy §B.2)
  setHud(true);
  try {
    const mod = await entry.load();
    game.register(id, (g) => new mod.default(g, { ...opts, onExit: back }));
    game.setState(id, opts);
  } catch (err) {
    console.error(`Failed to load game "${id}"`, err);
    back();
  }
}

function toMainMenu() {
  title.textContent = '';
  backHandler = toMainMenu;
  setHud(false);
  game.setState('MainMenu');
}

// Satisfy the mobile autoplay policy on the first tap anywhere.
window.addEventListener('pointerdown', () => {
  const Ctx = window.AudioContext || window.webkitAudioContext;
  if (Ctx && !window.__spAudio) window.__spAudio = new Ctx();
}, { once: true });

// resolveImage() needs the manifest before the first frame draws pool art
await loadManifest();
syncArtBtn();                      // now we know whether overlay art exists

game.setState('MainMenu');
game.start();
if (splash) splash.remove();
