<!-- Per-game graphics declaration — Design Policy §A.7.
     Hand-edit freely; keep it in sync in the commit that changes art. -->

# `memory-menu` — graphics declaration

| Field | Value |
| --- | --- |
| Game id | `memory-menu` (memory-menu.js / MemoryMenu.tscn) |
| Owns any art? | no |
| Shared pools used | Uses the shared menu-tile renderer; the five deck tiles draw glyphs / a picture swatch, no dedicated art. |
| Content file(s) | — (none) |
| Theme variants | light+dark from palette only |
| Style themes | none |

## Assets

| Logical name | Pool / path (no ext) | Formats | Native px | Target box (world units) | Aspect / fit | Difficulty tag | Licence / source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| deck tiles | — (drawn) | — | — | — | — | — | — |

## Notes

- Native px is the real pixel size of the largest raster in the set.
- Target box is the max on-screen size in world units (1280×720 ref); the
  renderer letterboxes inside it.
- Art is referenced without an extension — `svg` wins over `png`/`jpg`, so a
  newer vector can be dropped in beside the raster (Policy §C.2).
