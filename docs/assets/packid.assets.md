<!-- Per-game graphics declaration — Design Policy §A.7.
     Hand-edit freely; keep it in sync in the commit that changes art. -->

# `packid` — graphics declaration

| Field | Value |
| --- | --- |
| Game id | `packid` (packid.js / Packid.tscn) |
| Owns any art? | yes (small sprites) |
| Shared pools used | `sprites/packid` — player frames (`pac_*`), fruit ghosts, cherry, brick. |
| Content file(s) | — (none) |
| Theme variants | maze / atmosphere are iconic literals; chrome follows the palette |
| Style themes | none |

## Assets

| Logical name | Pool / path (no ext) | Formats | Native px | Target box (world units) | Aspect / fit | Difficulty tag | Licence / source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| player | sprites/packid/pac_{l,r,u,d}[,_c] | png | ~22x23 | grid cell, contain | ~1:1 | — | GPL, legacy `PackidData` |
| fruit ghosts + cherry | sprites/packid/{appel,citroen,kers,banaan,peer} | png | 14x22 … 22x22 | grid cell, contain | ~1:1 | maze size = level | GPL, legacy `PackidData` |
| brick | sprites/packid/brick | png | 24x24 | grid cell | 1:1 | — | GPL, legacy `PackidData` |

## Notes

- Native px is the real pixel size of the largest raster in the set.
- Target box is the max on-screen size in world units (1280×720 ref); the
  renderer letterboxes inside it.
- Art is referenced without an extension — `svg` wins over `png`/`jpg`, so a
  newer vector can be dropped in beside the raster (Policy §C.2).
