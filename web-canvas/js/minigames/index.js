// minigames/index.js — registry of playable activities.
//
// Each entry lazily imports its module so the menu stays light and only
// the chosen activity's code is downloaded. A module's default export is
// a factory: (engine, { onFinished }) => Scene
//
// Games ported so far: Packid, Fallingletter, Soundmemory, Memory, Billiards.

export const MINIGAMES = [
  {
    id: 'packid',
    name: 'Packid',
    load: () => import('./packid.js'),
  },
  {
    id: 'fallingletter',
    name: 'Falling Letter',
    load: () => import('./fallingletter.js'),
  },
  {
    id: 'soundmemory',
    name: 'Sound Memory',
    load: () => import('./soundmemory.js'),
  },
  {
    id: 'memory',
    name: 'Memory',
    load: () => import('./memory.js'),
  },
  {
    id: 'billiards',
    name: 'Billiards',
    load: () => import('./billiards.js'),
  },
];

export function getMinigame(id) {
  return MINIGAMES.find((m) => m.id === id) || null;
}
