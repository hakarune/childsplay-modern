<!-- Per-game graphics declaration — Design Policy §A.7. -->

# `quiz` — graphics declaration

| Field | Value |
| --- | --- |
| Game id | `quiz` (quiz.js / Quiz.tscn) — one shared engine behind the Quiz deck picker (quiz-menu.js / QuizMenu.tscn) |
| Owns any art? | no |
| Shared pools used | `animals` — only the **Pictures** deck, which sets `image` on its questions |
| Content file(s) | `godot/assets/data/quiz/*.json` — one per deck (`general`, `picture`, `math`, `words`, `sayings`) |
| Theme variants | light+dark from palette only |
| Style themes | none |

## Assets

| Logical name | Pool / path (no ext) | Formats | Native px | Target box (world units) | Aspect / fit | Difficulty tag | Licence / source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| question image | any pool stem set as `image` (Pictures deck uses `animals/*`) | png/svg | ~90×150 (animals) | ≤ ~200 sq, left of the question card, contain | varies | `level` field in the deck JSON | GPL, shared `animals` pool |
| question card / answer buttons | — (drawn / Button nodes) | — | — | card ≤ VIEW_W−120 wide; answer buttons ≥ 78 tall (§I.1.2) | — | — | — |

## Notes

- A deck is a JSON file: `{ name, prompt, questions: [{ level, q, choices, answer, image? }] }`.
  `answer` is an index into `choices`; the engine shuffles the display order.
- `image` is an extension-less pool stem — `svg` wins over `png`/`jpg` (§C.2).
- Adding a deck = drop a `quiz/<id>.json` in and add `{ deck: '<id>', label: '…' }`
  to the picker list in `quiz-menu.js` / `QuizMenu.gd`.
