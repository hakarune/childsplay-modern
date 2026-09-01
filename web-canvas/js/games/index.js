// games/index.js — two lists.
//
// GAMES  — every loadable game module (default export is a Scene subclass
//          `new GameScene(game, opts)`). main.js lazy-imports + registers
//          these on demand.
// MENU   — what the main dashboard shows. The `memory` tile is special:
//          it opens the Memory sub-menu (memory-menu.js) instead of a
//          game, which then picks a variant / Sound Memory.

export const GAMES = [
  { id: 'memory',       name: 'Memory Games',               load: () => import('./memory.js') },
  { id: 'fallingletter',name: 'Falling Letters',      load: () => import('./fallingletter.js') },
  { id: 'soundmemory',  name: 'Sound Memory',         load: () => import('./soundmemory.js') },
  { id: 'findsound',    name: 'Find the sound',       load: () => import('./findsound.js') },
  { id: 'puzzle',       name: 'Puzzles',              load: () => import('./puzzle.js') },
  { id: 'findit',       name: 'Picture Find',         load: () => import('./findit.js') },
  { id: 'aquarium',     name: 'Aquarium',             load: () => import('./aquarium.js') },
  { id: 'pong',         name: 'Pong',                 load: () => import('./pong.js') },
  { id: 'fourrow',      name: 'Connect Four',         load: () => import('./fourrow.js') },
  { id: 'flashcards',   name: 'Flashcards',           load: () => import('./flashcards.js') },
  { id: 'blockbreaker', name: 'Block Breaker',        load: () => import('./blockbreaker.js') },
  { id: 'simon',        name: 'Simon',                load: () => import('./simon.js') },
  { id: 'electro',      name: 'ImageLink',            load: () => import('./electro.js') },
  { id: 'tictactoe',    name: 'Tic-Tac-Toe',          load: () => import('./tictactoe.js') },
  { id: 'wipe',         name: 'Picture Wipe',         load: () => import('./wipe.js') },
  { id: 'ichanger',     name: 'What changed',         load: () => import('./ichanger.js') },
  { id: 'numbers',      name: 'Remember the Number',  load: () => import('./numbers.js') },
  { id: 'synonyms',     name: 'StartsWith',           load: () => import('./synonyms.js') },
  { id: 'packid',       name: 'PacKid',               load: () => import('./packid.js') },
  { id: 'billiards',    name: 'Billiards',            load: () => import('./billiards.js') },
  { id: 'quiz',         name: 'Quizzes',              load: () => import('./quiz.js') },
];

export const MENU = [
  { id: 'memory',       name: 'Memory Games',               icon: 'icons/memory.png',        submenu: true },
  { id: 'fallingletter',name: 'Falling Letters',      icon: 'icons/fallingletter.png' },
  { id: 'findsound',    name: 'Find the sound',       icon: 'icons/findsound.png' },
  { id: 'puzzle',       name: 'Puzzles',              icon: 'icons/puzzle.png' },
  { id: 'findit',       name: 'Picture Find',         icon: 'icons/findit.png' },
  { id: 'aquarium',     name: 'Aquarium',             icon: 'icons/aquarium.png' },
  { id: 'pong',         name: 'Pong',                 icon: 'icons/pong.png' },
  { id: 'fourrow',      name: 'Connect Four',         icon: 'icons/fourrow.png' },
  { id: 'flashcards',   name: 'Flashcards',           icon: 'icons/flashcards.png' },
  { id: 'blockbreaker', name: 'Block Breaker',        icon: 'icons/blockbreaker.png' },
  { id: 'simon',        name: 'Simon',                icon: 'icons/simon.png' },
  { id: 'electro',      name: 'ImageLink',            icon: 'icons/electro.png' },
  { id: 'tictactoe',    name: 'Tic-Tac-Toe',          icon: 'icons/tictactoe.png' },
  { id: 'wipe',         name: 'Picture Wipe',         icon: 'icons/wipe.png' },
  { id: 'ichanger',     name: 'What changed',         icon: 'icons/ichanger.png' },
  { id: 'numbers',      name: 'Remember the Number',  icon: 'icons/numbers.png' },
  { id: 'synonyms',     name: 'StartsWith',           icon: 'icons/synonyms.png' },
  { id: 'packid',       name: 'PacKid',               icon: 'icons/packid.png' },
  { id: 'billiards',    name: 'Billiards',            icon: 'icons/billiards.png' },
  { id: 'quiz',         name: 'Quizzes',              icon: 'icons/quiz.png', submenu: true },
];

export function getGame(id) {
  return GAMES.find((g) => g.id === id) || null;
}
