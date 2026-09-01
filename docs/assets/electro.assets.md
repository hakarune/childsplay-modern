<!-- Per-game graphics declaration — Design Policy §A.7.
     Hand-edit freely; keep it in sync in the commit that changes art. -->

# `electro` — graphics declaration

| Field | Value |
| --- | --- |
| Game id | `electro` (electro.js / Electro.tscn) |
| Owns any art? | no |
| Shared pools used | `animals` — the picture side of each picture↔name pair (pairs from `godot/assets/data/electro.json`). |
| Content file(s) | `godot/assets/data/electro.json` (picture↔name pairs) |
| Theme variants | light+dark from palette only |
| Style themes | none |

## Assets

| Logical name | Pool / path (no ext) | Formats | Native px | Target box (world units) | Aspect / fit | Difficulty tag | Licence / source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| pair pictures | animals/<id> (ids listed in electro.json) | png | 90x150 (mostly) | ≤ 150 sq node, contain | varies | pair count = level (3→8) | GPL, legacy `Electro_spData` |

## Notes

- Native px is the real pixel size of the largest raster in the set.
- Target box is the max on-screen size in world units (1280×720 ref); the
  renderer letterboxes inside it.
- Art is referenced without an extension — `svg` wins over `png`/`jpg`, so a
  newer vector can be dropped in beside the raster (Policy §C.2).
