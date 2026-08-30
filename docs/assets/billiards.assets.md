<!-- Per-game graphics declaration — Design Policy §A.7.
     Hand-edit freely; keep it in sync in the commit that changes art. -->

# `billiards` — graphics declaration

| Field | Value |
| --- | --- |
| Game id | `billiards` (billiards.js / Billiards.tscn) |
| Owns any art? | yes (small sprites) |
| Shared pools used | `sprites/billiards` — cue ball, object ball, pocket, cue stick. Ball tints are iconic literals. |
| Content file(s) | — (none) |
| Theme variants | table felt / rail are iconic literals; chrome follows the palette |
| Style themes | none |

## Assets

| Logical name | Pool / path (no ext) | Formats | Native px | Target box (world units) | Aspect / fit | Difficulty tag | Licence / source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| balls | sprites/billiards/ball1 (cue), ball2 (object) | png | 60x60 | ≤ 2*BR, contain | 1:1 | rack size 3/6/10 = level | GPL, legacy `BilliardData` |
| pocket | sprites/billiards/hole | png | 60x60 | ≤ pocket R, contain | 1:1 | — | GPL, legacy `BilliardData` |
| cue stick | sprites/billiards/stick | png | 123x6 | aim line length | wide | — | GPL, legacy `BilliardData` |

## Notes

- Native px is the real pixel size of the largest raster in the set.
- Target box is the max on-screen size in world units (1280×720 ref); the
  renderer letterboxes inside it.
- Art is referenced without an extension — `svg` wins over `png`/`jpg`, so a
  newer vector can be dropped in beside the raster (Policy §C.2).
