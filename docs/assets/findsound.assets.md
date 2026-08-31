<!-- Per-game graphics declaration — Design Policy §A.7.
     Hand-edit freely; keep it in sync in the commit that changes art. -->

# `findsound` — graphics declaration

| Field | Value |
| --- | --- |
| Game id | `findsound` (findsound.js / FindSound.tscn) |
| Owns any art? | no |
| Shared pools used | one graphics pool per level (`animals`, `vehicles`, `instruments`, `sounds`) + `soundmemory/snd/*.ogg`. |
| Content file(s) | none — a level IS a pool folder; picture & clip pair by stem |
| Theme variants | light+dark from palette only |
| Style themes | none |

## Assets

| Logical name | Pool / path (no ext) | Formats | Native px | Target box (world units) | Aspect / fit | Difficulty tag | Licence / source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| choice pictures | <pool>/* where the stem has a `soundmemory/<stem>.ogg` | png | ~112x112 (some to 150x203) | ≤ 190 sq tile, contain | varies | the pool folder IS the level | GPL, legacy `FindsoundData` |

## Notes

- Native px is the real pixel size of the largest raster in the set.
- Target box is the max on-screen size in world units (1280×720 ref); the
  renderer letterboxes inside it.
- Art is referenced without an extension — `svg` wins over `png`/`jpg`, so a
  newer vector can be dropped in beside the raster (Policy §C.2).
