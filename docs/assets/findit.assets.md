<!-- Per-game graphics declaration — Design Policy §A.7.
     Hand-edit freely; keep it in sync in the commit that changes art. -->

# `findit` — graphics declaration

| Field | Value |
| --- | --- |
| Game id | `findit` (findit.js / FindIt.tscn) |
| Owns any art? | no |
| Shared pools used | `backgrounds` (the painting shown twice); the difference spots are procedural. |
| Content file(s) | — (none) |
| Theme variants | light+dark from palette only |
| Style themes | none |

## Assets

| Logical name | Pool / path (no ext) | Formats | Native px | Target box (world units) | Aspect / fit | Difficulty tag | Licence / source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| painting pool | backgrounds/* (non-aquarium) | jpg | ~800x560 | half-width panel, contain | ~4:3 | 3 levels — any painting | GPL, legacy `WipeData` |

## Notes

- Native px is the real pixel size of the largest raster in the set.
- Target box is the max on-screen size in world units (1280×720 ref); the
  renderer letterboxes inside it.
- Art is referenced without an extension — `svg` wins over `png`/`jpg`, so a
  newer vector can be dropped in beside the raster (Policy §C.2).
