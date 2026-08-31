<!-- Per-game graphics declaration — Design Policy §A.7.
     Hand-edit freely; keep it in sync in the commit that changes art. -->

# `wipe` — graphics declaration

| Field | Value |
| --- | --- |
| Game id | `wipe` (wipe.js / Wipe.tscn) |
| Owns any art? | no |
| Shared pools used | `backgrounds` (the hidden painting), filtered by the level's tier; `ui/sponge`. |
| Content file(s) | — (difficulty is a `_easy/_med/_hard` filename tag, §A.3) |
| Theme variants | light+dark from palette only (art is photographic) |
| Style themes | none |

## Assets

| Logical name | Pool / path (no ext) | Formats | Native px | Target box (world units) | Aspect / fit | Difficulty tag | Licence / source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| background pool | backgrounds/* (shared with Puzzle, no-repeat) | jpg | ~800x560 | frame, contain | ~4:3 | easy(1-4) \| med(5-8) \| hard(9-12) — `_tier` filename tag; untagged = any tier | GPL, legacy `WipeData` |
| sponge | ui/sponge | png | 60x61 | level sponge radius 54→26 | ~1:1 | — | GPL-3 |

## Notes

- Native px is the real pixel size of the largest raster in the set.
- Target box is the max on-screen size in world units (1280×720 ref); the
  renderer letterboxes inside it.
- Art is referenced without an extension — `svg` wins over `png`/`jpg`, so a
  newer vector can be dropped in beside the raster (Policy §C.2).
