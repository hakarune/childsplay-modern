<!-- Per-game graphics declaration — Design Policy §A.7.
     Hand-edit freely; keep it in sync in the commit that changes art. -->

# `puzzle` — graphics declaration

| Field | Value |
| --- | --- |
| Game id | `puzzle` (puzzle.js / Puzzle.tscn) |
| Owns any art? | no |
| Shared pools used | `backgrounds` (the paintings), filtered by the level's tier. |
| Content file(s) | — (difficulty is a `_easy/_med/_hard` filename tag, §A.3) |
| Theme variants | light+dark from palette only (art is photographic) |
| Style themes | none |

## Assets

| Logical name | Pool / path (no ext) | Formats | Native px | Target box (world units) | Aspect / fit | Difficulty tag | Licence / source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| background pool | backgrounds/* (paintings + aquarium tanks + future drops) | jpg | ~800x560 | frame, contain | ~4:3 | easy \| med \| hard — `_tier` filename tag (`bruegel0_hard.jpg`); untagged = any tier | kid-friendly scene art (castle-dragon, fairy-forest, …) |

## Notes

- Native px is the real pixel size of the largest raster in the set.
- Target box is the max on-screen size in world units (1280×720 ref); the
  renderer letterboxes inside it.
- Art is referenced without an extension — `svg` wins over `png`/`jpg`, so a
  newer vector can be dropped in beside the raster (Policy §C.2).
