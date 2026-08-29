// main.js — bootstrap + navigation.
//
//   MainMenu tile  -> a game, except the "memory" tile which opens the
//                     Memory sub-menu (memory-menu.js).
//   Memory sub-menu -> a memory variant (memory.js) or Sound Memory.
//
// Games are lazy-imported and re-instantiated per launch (a clean reset).

import { Game } from './engine.js';
import { MainMenu } from './menu.js';
import { MemoryMenu } from './games/memory-menu.js';
import { getGame } from './games/index.js';

const canvas = document.getElementById('game-canvas');
const hud = document.getElementById('hud');
const backBtn = document.getElementById('back-btn');
const title = document.getElementById('activity-name');
const splash = document.getElementById('splash');
const fsBtn = document.getElementById('fs-btn');

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

function openMemoryMenu() {
  title.textContent = 'Memory';
  hud.hidden = false;
  backHandler = toMainMenu;
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
  hud.hidden = false;
  backHandler = back;
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
  hud.hidden = true;
  title.textContent = '';
  backHandler = toMainMenu;
  game.setState('MainMenu');
}

// Satisfy the mobile autoplay policy on the first tap anywhere.
window.addEventListener('pointerdown', () => {
  const Ctx = window.AudioContext || window.webkitAudioContext;
  if (Ctx && !window.__spAudio) window.__spAudio = new Ctx();
}, { once: true });

game.setState('MainMenu');
game.start();
if (splash) splash.remove();
