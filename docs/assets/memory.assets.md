<!-- Per-game graphics declaration — Design Policy §A.7.
     Hand-edit freely; keep it in sync in the commit that changes art. -->

# `memory` — graphics declaration

| Field | Value |
| --- | --- |
| Game id | `memory` (memory.js / Memory.tscn) |
| Owns any art? | no |
| Shared pools used | `ui` (card faces), `animals` (Pictures deck). Letter/Number/UPPER decks draw glyphs — no art. |
| Content file(s) | — (none) |
| Theme variants | light+dark from palette only |
| Style themes | none |

## Assets

| Logical name | Pool / path (no ext) | Formats | Native px | Target box (world units) | Aspect / fit | Difficulty tag | Licence / source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| card back | ui/card_back | png | 161x161 | ≤ 3:4 tile, contain | ~1:1 | — | GPL-3, legacy `CP_cardback` |
| card front | ui/card_front | png | 161x161 | ≤ 3:4 tile, contain | ~1:1 | — | GPL-3, legacy `CP_cardfront` |
| picture deck | animals/* (all) | png | 90x150 | fits card minus inset, contain | varies | — (grid size = level) | GPL, legacy `Memory_spData/tileset_2` |

## Notes

- Native px is the real pixel size of the largest raster in the set.
- Target box is the max on-screen size in world units (1280×720 ref); the
  renderer letterboxes inside it.
- Art is referenced without an extension — `svg` wins over `png`/`jpg`, so a
  newer vector can be dropped in beside the raster (Policy §C.2).
