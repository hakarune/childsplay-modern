<!-- Per-game graphics declaration — Design Policy §A.7.
     Hand-edit freely; keep it in sync in the commit that changes art. -->

# `soundmemory` — graphics declaration

| Field | Value |
| --- | --- |
| Game id | `soundmemory` (soundmemory.js / SoundMemory.tscn) |
| Owns any art? | no |
| Shared pools used | `ui` (card back), `soundmemory/snd/*.ogg` (audio), reveal art from `animals` / `soundpics`. |
| Content file(s) | — (none) |
| Theme variants | light+dark from palette only |
| Style themes | none |

## Assets

| Logical name | Pool / path (no ext) | Formats | Native px | Target box (world units) | Aspect / fit | Difficulty tag | Licence / source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| card back | ui/card_back | png | 161x161 | ≤ 3:4 tile, contain | ~1:1 | — | GPL-3 |
| reveal picture | animals/* or soundpics/* | png | 90x150 / 112x112 | fits card, contain | varies | — (grid size = level) | GPL, legacy `SoundmemoryData` |

## Notes

- Native px is the real pixel size of the largest raster in the set.
- Target box is the max on-screen size in world units (1280×720 ref); the
  renderer letterboxes inside it.
- Art is referenced without an extension — `svg` wins over `png`/`jpg`, so a
  newer vector can be dropped in beside the raster (Policy §C.2).
