<!-- Per-game graphics declaration — Design Policy §A.7.
     Hand-edit freely; keep it in sync in the commit that changes art. -->

# `simon` — graphics declaration

| Field | Value |
| --- | --- |
| Game id | `simon` (simon.js / Simon.tscn) |
| Owns any art? | no |
| Shared pools used | None — four pads drawn; pad colours are iconic literals. Tones are synthesised (no audio files). |
| Content file(s) | — (none) |
| Theme variants | pads are fixed iconic colours; chrome follows the palette |
| Style themes | none |

## Assets

| Logical name | Pool / path (no ext) | Formats | Native px | Target box (world units) | Aspect / fit | Difficulty tag | Licence / source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| pads | — (drawn) | — | — | — | — | sequence length = level | — |

## Notes

- Native px is the real pixel size of the largest raster in the set.
- Target box is the max on-screen size in world units (1280×720 ref); the
  renderer letterboxes inside it.
- Art is referenced without an extension — `svg` wins over `png`/`jpg`, so a
  newer vector can be dropped in beside the raster (Policy §C.2).
