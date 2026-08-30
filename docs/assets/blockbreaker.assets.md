<!-- Per-game graphics declaration — Design Policy §A.7.
     Hand-edit freely; keep it in sync in the commit that changes art. -->

# `blockbreaker` — graphics declaration

| Field | Value |
| --- | --- |
| Game id | `blockbreaker` (blockbreaker.js / BlockBreaker.tscn) |
| Owns any art? | no |
| Shared pools used | None — paddle, ball, bricks drawn; brick tints are an iconic palette kept as literals. |
| Content file(s) | — (none) |
| Theme variants | light+dark from palette (play area is a framed dark board) |
| Style themes | none |

## Assets

| Logical name | Pool / path (no ext) | Formats | Native px | Target box (world units) | Aspect / fit | Difficulty tag | Licence / source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| paddle / ball / bricks | — (drawn) | — | — | — | — | wall layout = level | — |

## Notes

- Native px is the real pixel size of the largest raster in the set.
- Target box is the max on-screen size in world units (1280×720 ref); the
  renderer letterboxes inside it.
- Art is referenced without an extension — `svg` wins over `png`/`jpg`, so a
  newer vector can be dropped in beside the raster (Policy §C.2).
