<!-- Per-game graphics declaration — Design Policy §A.7.
     Hand-edit freely; keep it in sync in the commit that changes art. -->

# `synonyms` — graphics declaration

| Field | Value |
| --- | --- |
| Game id | `synonyms` (synonyms.js / WordMaker.tscn) |
| Owns any art? | no |
| Shared pools used | None — keyboard and word tray drawn. Dictionary: `assets/data/wordlist.json` (~1235 words). |
| Content file(s) | `assets/data/wordlist.json` (~1235-word kid dictionary) |
| Theme variants | light+dark from palette only |
| Style themes | none |

## Assets

| Logical name | Pool / path (no ext) | Formats | Native px | Target box (world units) | Aspect / fit | Difficulty tag | Licence / source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| keyboard / tray | — (drawn) | — | — | — | — | starting letter + target = level | — |

## Notes

- Native px is the real pixel size of the largest raster in the set.
- Target box is the max on-screen size in world units (1280×720 ref); the
  renderer letterboxes inside it.
- Art is referenced without an extension — `svg` wins over `png`/`jpg`, so a
  newer vector can be dropped in beside the raster (Policy §C.2).
