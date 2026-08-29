// main.js — bootstrap. Creates the engine, registers the MainMenu, and
// lazily loads / (re)instantiates a game module when its launcher tile is
// tapped. Re-registering + setState() gives every launch a fresh, reset
// game object.

import { Game } from './engine.js';
import { MainMenu } from './menu.js';
import { getGame } from './games/index.js';

const canvas = document.getElementById('game-canvas');
const hud = document.getElementById('hud');
const backBtn = document.getElementById('back-btn');
const title = document.getElementById('activity-name');
const splash = document.getElementById('splash');

const game = new Game(canvas);
game.register('MainMenu', (g) => new MainMenu(g, { onSelect: launch }));

async function launch(id) {
  const entry = getGame(id);
  if (!entry) return;
  title.textContent = entry.name;
  hud.hidden = false;
  try {
    const mod = await entry.load();
    game.register(id, (g) => new mod.default(g, { onExit: toMenu }));
    game.setState(id);
  } catch (err) {
    console.error(`Failed to load game "${id}"`, err);
    toMenu();
  }
}

function toMenu() {
  hud.hidden = true;
  title.textContent = '';
  game.setState('MainMenu');
}

backBtn.addEventListener('click', toMenu);

// Satisfy the mobile autoplay policy on the first tap anywhere.
window.addEventListener('pointerdown', () => {
  const Ctx = window.AudioContext || window.webkitAudioContext;
  if (Ctx && !window.__spAudio) window.__spAudio = new Ctx();
}, { once: true });

game.setState('MainMenu');
game.start();
if (splash) splash.remove();
