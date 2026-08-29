// games/index.js — two lists.
//
// GAMES  — every loadable game module (default export is a Scene subclass
//          `new GameScene(game, opts)`). main.js lazy-imports + registers
//          these on demand.
// MENU   — what the main dashboard shows. The `memory` tile is special:
//          it opens the Memory sub-menu (memory-menu.js) instead of a
//          game, which then picks a variant / Sound Memory.

export const GAMES = [
  { id: 'memory',        name: 'Memory',         load: () => import('./memory.js') },
  { id: 'fallingletter', name: 'Falling Letter', load: () => import('./fallingletter.js') },
  { id: 'soundmemory',   name: 'Sound Memory',   load: () => import('./soundmemory.js') },
  { id: 'findsound',     name: 'Find Sound',     load: () => import('./findsound.js') },
  { id: 'puzzle',        name: 'Puzzle',         load: () => import('./puzzle.js') },
  { id: 'packid',        name: 'Packid',         load: () => import('./packid.js') },
  { id: 'billiards',     name: 'Billiards',      load: () => import('./billiards.js') },
];

export const MENU = [
  { id: 'memory',        name: 'Memory',         icon: 'icons/memory.png',        submenu: true },
  { id: 'fallingletter', name: 'Falling Letter', icon: 'icons/fallingletter.png' },
  { id: 'findsound',     name: 'Find Sound',     icon: 'icons/findsound.png' },
  { id: 'puzzle',        name: 'Puzzle',         icon: 'icons/puzzle.png' },
  { id: 'packid',        name: 'Packid',         icon: 'icons/packid.png' },
  { id: 'billiards',     name: 'Billiards',      icon: 'icons/billiards.png' },
];

export function getGame(id) {
  return GAMES.find((g) => g.id === id) || null;
}
