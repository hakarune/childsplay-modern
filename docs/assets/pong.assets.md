<!-- Per-game graphics declaration — Design Policy §A.7.
     Hand-edit freely; keep it in sync in the commit that changes art. -->

# `pong` — graphics declaration

| Field | Value |
| --- | --- |
| Game id | `pong` (pong.js / Pong.tscn) |
| Owns any art? | no |
| Shared pools used | None — court, paddles, ball drawn. Court colours come from the chosen style theme. |
| Content file(s) | — (none) |
| Theme variants | light+dark from palette + per-style |
| Style themes | `material` (Modern) · `atari` (Retro) · `neon` (90s Neon) · `y2k` — each ships light + dark |

## Assets

| Logical name | Pool / path (no ext) | Formats | Native px | Target box (world units) | Aspect / fit | Difficulty tag | Licence / source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| court / paddles / ball | — (drawn) | — | — | — | — | — | — |

## Notes

- Native px is the real pixel size of the largest raster in the set.
- Target box is the max on-screen size in world units (1280×720 ref); the
  renderer letterboxes inside it.
- Art is referenced without an extension — `svg` wins over `png`/`jpg`, so a
  newer vector can be dropped in beside the raster (Policy §C.2).
