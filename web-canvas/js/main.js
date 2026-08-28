// main.js — bootstrap for the Childsplay-Modern web target.
//
// Wires the engine, the menu scene and the lazily-loaded minigames
// together, and manages the small HUD (back button + activity name).

import { Engine } from './engine.js';
import { MenuScene } from './menu.js';
import { getMinigame } from './minigames/index.js';

const canvas = document.getElementById('stage');
const hud = document.getElementById('hud');
const backBtn = document.getElementById('back-btn');
const activityName = document.getElementById('activity-name');

const engine = new Engine(canvas);

function showMenu() {
  hud.hidden = true;
  activityName.textContent = '';
  engine.setScene(new MenuScene({ onSelect: launchMinigame }));
}

async function launchMinigame(id) {
  const entry = getMinigame(id);
  if (!entry) return;

  activityName.textContent = entry.name;
  hud.hidden = false;

  try {
    const mod = await entry.load();
    const createScene = mod.default;
    engine.setScene(createScene(engine, { onFinished: showMenu }));
  } catch (err) {
    console.error(`Failed to load minigame "${id}"`, err);
    showMenu();
  }
}

backBtn.addEventListener('click', showMenu);

showMenu();
engine.start();
