// games/index.js — the launcher registry.
//
// id / display name / launcher icon (under web-canvas/assets/) / a lazy
// import of the module. Every module's default export is a Scene subclass
// with the signature  new GameScene(game, { onExit })  — main.js registers
// it with the engine on first launch and re-instantiates it (a clean
// reset) each time the tile is tapped.

export const GAMES = [
  { id: 'memory',        name: 'Memory',         icon: 'icons/memory.png',        load: () => import('./memory.js') },
  { id: 'fallingletter', name: 'Falling Letter', icon: 'icons/fallingletter.png', load: () => import('./fallingletter.js') },
  { id: 'soundmemory',   name: 'Sound Memory',   icon: 'icons/soundmemory.png',   load: () => import('./soundmemory.js') },
  { id: 'packid',        name: 'Packid',         icon: 'icons/packid.png',        load: () => import('./packid.js') },
  { id: 'billiards',     name: 'Billiards',      icon: 'icons/billiards.png',     load: () => import('./billiards.js') },
];

export function getGame(id) {
  return GAMES.find((g) => g.id === id) || null;
}
