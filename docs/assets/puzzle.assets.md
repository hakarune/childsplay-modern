<!-- Per-game graphics declaration — Design Policy §A.7.
     Hand-edit freely; keep it in sync in the commit that changes art. -->

# `puzzle` — graphics declaration

| Field | Value |
| --- | --- |
| Game id | `puzzle` (puzzle.js / Puzzle.tscn) |
| Owns any art? | no |
| Shared pools used | `backgrounds` (the paintings), filtered by the level's tier. |
| Content file(s) | `assets/data/backgrounds.json` (difficulty tiers) |
| Theme variants | light+dark from palette only (art is photographic) |
| Style themes | none |

## Assets

| Logical name | Pool / path (no ext) | Formats | Native px | Target box (world units) | Aspect / fit | Difficulty tag | Licence / source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| painting pool | backgrounds/* (bruegel*/gogh*/monet*/pieck*/rembrandt*/renoir*/vermeer*) | jpg | ~800x560 | frame, contain | ~4:3 | easy \| med \| hard — `assets/data/backgrounds.json` | GPL, legacy `WipeData` paintings |

## Notes

- Native px is the real pixel size of the largest raster in the set.
- Target box is the max on-screen size in world units (1280×720 ref); the
  renderer letterboxes inside it.
- Art is referenced without an extension — `svg` wins over `png`/`jpg`, so a
  newer vector can be dropped in beside the raster (Policy §C.2).
