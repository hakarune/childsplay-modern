<!-- Per-game graphics declaration — Design Policy §A.7.
     Hand-edit freely; keep it in sync in the commit that changes art. -->

# `ichanger` — graphics declaration

| Field | Value |
| --- | --- |
| Game id | `ichanger` (ichanger.js / ImageChanger.tscn) |
| Owns any art? | no |
| Shared pools used | `animals` (the row of cards — reuses Memory art). |
| Content file(s) | — (none) |
| Theme variants | cards stay light on `surface_alt` in both themes |
| Style themes | none |

## Assets

| Logical name | Pool / path (no ext) | Formats | Native px | Target box (world units) | Aspect / fit | Difficulty tag | Licence / source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| row cards | animals/* (3–4 per round) | png | 90x150 | ≤ card minus inset, contain | varies | card count / shuffle = level | GPL, legacy `IchangerData` → shared `animals` |

## Notes

- Native px is the real pixel size of the largest raster in the set.
- Target box is the max on-screen size in world units (1280×720 ref); the
  renderer letterboxes inside it.
- Art is referenced without an extension — `svg` wins over `png`/`jpg`, so a
  newer vector can be dropped in beside the raster (Policy §C.2).
