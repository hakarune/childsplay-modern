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
  { id: 'findit',        name: 'Find It',        load: () => import('./findit.js') },
  { id: 'aquarium',      name: 'Aquarium',       load: () => import('./aquarium.js') },
  { id: 'pong',          name: 'Pong',           load: () => import('./pong.js') },
  { id: 'fourrow',       name: 'Four in a Row',  load: () => import('./fourrow.js') },
  { id: 'flashcards',    name: 'Flashcards',     load: () => import('./flashcards.js') },
  { id: 'blockbreaker',  name: 'Block Breaker',  load: () => import('./blockbreaker.js') },
  { id: 'packid',        name: 'Packid',         load: () => import('./packid.js') },
  { id: 'billiards',     name: 'Billiards',      load: () => import('./billiards.js') },
];

export const MENU = [
  { id: 'memory',        name: 'Memory',        icon: 'icons/memory.png',        submenu: true },
  { id: 'fallingletter', name: 'Falling Letter', icon: 'icons/fallingletter.png' },
  { id: 'findsound',     name: 'Find Sound',    icon: 'icons/findsound.png' },
  { id: 'puzzle',        name: 'Puzzle',        icon: 'icons/puzzle.png' },
  { id: 'findit',        name: 'Find It',       icon: 'icons/findit.png' },
  { id: 'aquarium',      name: 'Aquarium',      icon: 'icons/aquarium.png' },
  { id: 'pong',          name: 'Pong',          icon: 'icons/pong.png' },
  { id: 'fourrow',       name: 'Four in a Row', icon: 'icons/fourrow.png' },
  { id: 'flashcards',    name: 'Flashcards',    icon: 'icons/flashcards.png' },
  { id: 'blockbreaker',  name: 'Block Breaker', icon: 'icons/blockbreaker.png' },
  { id: 'packid',        name: 'Packid',        icon: 'icons/packid.png' },
  { id: 'billiards',     name: 'Billiards',     icon: 'icons/billiards.png' },
];

export function getGame(id) {
  return GAMES.find((g) => g.id === id) || null;
}
