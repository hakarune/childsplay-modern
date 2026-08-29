<!--
  Per-game graphics declaration. Required by docs/Design-Policy.md §A.7.
  Copy to  docs/assets/<gameid>.assets.md  and fill in every row.
  One row per distinct asset the game draws (group obvious series with a
  glob, e.g. `frog_*`).  Keep it in sync in the same commit that adds or
  changes art.
-->

# `<gameid>` — graphics declaration

| Field | Value |
| --- | --- |
| Game id | `<gameid>` (matches `web-canvas/js/games/<id>.js` / `desktop-godot/scenes/games/<Name>.tscn`) |
| Owns any art? | yes / no — set **no** if it only pulls from shared pools |
| Shared pools used | `backgrounds`, `animals`, `objects`, `ui`, … (see policy §A.2) |
| Content file(s) | `assets/data/<name>.txt` / `.json`, or — |
| Theme variants | `light+dark from palette only` **or** list which assets ship a `_dark` override |
| Style themes | none / `atari, neon, y2k, material` (each provides light+dark) |

## Assets

| Logical name | Pool / path (no extension) | Formats present | Native px | Target box (world units) | Aspect / fit | Difficulty tag | Licence / source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| card back | `ui/card_back` | svg, png | 180×240 | 3:4 tile, `contain` | 3:4 | — | GPL-3, legacy `CP_cardback.png` |
| painting pool | `backgrounds/*` (filtered by tier) | jpg | ~800×500 | frame, `contain` | ~8:5 | easy \| med \| hard | GPL, legacy `WipeData/tileset_1` |
| frog | `animals/frog_1 … frog_3` | png | 128×128 | ≤160 sq, `contain` | 1:1 | — | GPL, legacy `IchangerData` |

## Notes

- Every "Native px" MUST be the real pixel size of the largest raster in the set.
- "Target box" is the max on-screen size in **world units** (1280×720 ref); the
  renderer letter-boxes inside it (`drawImageFit` / `stretch_mode = KEEP_ASPECT`).
- If an asset is only legible in one theme, it MUST have a `_dark` (or `_light`)
  sibling — see policy §D.4. Otherwise the palette handles both.
- SVGs used above ~256 px MUST set an import `scale` (Godot) / be authored at
  display size; full-screen art stays raster (policy §C.4).
