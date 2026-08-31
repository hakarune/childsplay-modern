<!-- Per-game graphics declaration — Design Policy §A.7.
     Hand-edit freely; keep it in sync in the commit that changes art. -->

# `flashcards` — graphics declaration

| Field | Value |
| --- | --- |
| Game id | `flashcards` (flashcards.js / Flashcards.tscn) |
| Owns any art? | no |
| Shared pools used | `animals` (12 cards, reuses Memory / Find Sound art) + recorded name clips for de/nl/fr/es. |
| Content file(s) | recorded name clips `assets/audio/flashcards/<word>_<lang>.ogg` |
| Theme variants | cards stay light on a `surface_alt` backdrop in both themes |
| Style themes | none |

## Assets

| Logical name | Pool / path (no ext) | Formats | Native px | Target box (world units) | Aspect / fit | Difficulty tag | Licence / source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| animal cards | animals/{bear,cow,dog,elephant,fox,frog,hippopotamus,horse,lion,pig,penguin,rooster} | png | 90x150 / 112x112 / 140x101 | ≤ card minus inset, contain | varies | — (toy) | GPL, legacy `FlashcardsData` |

## Notes

- Native px is the real pixel size of the largest raster in the set.
- Target box is the max on-screen size in world units (1280×720 ref); the
  renderer letterboxes inside it.
- Art is referenced without an extension — `svg` wins over `png`/`jpg`, so a
  newer vector can be dropped in beside the raster (Policy §C.2).
