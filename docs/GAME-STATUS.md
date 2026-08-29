# Game conversion status

Tracks every activity from the original **Childsplay**
(`legacy-sources/childsplay-legacy/`) against the two modern targets:

- **Godot** — `desktop-godot/scenes/games/*.tscn` (+ `scripts/games/*.gd`),
  wired into `desktop-godot/scripts/MainMenu.gd`
- **Web** — `web-canvas/js/games/*.js`, wired into `web-canvas/js/games/index.js`

Update this file in the same commit that adds or finishes a game.

## Legend

| Mark | Meaning |
| --- | --- |
| ✅ | Done — playable and wired into the launcher |
| 🟡 | Partial — the engine exists but a content set or feature is missing |
| 🔜 | Planned — next up |
| ⬜ | Not started |

## Summary

| Target | ✅ Done | 🟡 Partial | ⬜ Not started |
| --- | --- | --- | --- |
| Godot (of the 13 classic activities) | 4 | 1 | 8 |
| Web (of the 13 classic activities)   | 4 | 1 | 8 |

Both targets are at feature parity: the same five game scenes exist on each.

---

## Classic Childsplay activities (the shipped 13)

These are the activities in the standard Childsplay menu that this project
is committed to porting first.

| Game | Legacy module | Godot | Web | Notes |
| --- | --- | :---: | :---: | --- |
| **Memory** (pictures) | `memory_sp.py` | ✅ | ✅ | Flip/match, grids 2×2 → 5×4, win + next-level flow. Uses the `tileset_2` animal deck. |
| **Lower Case Memory** | `memory_sp.py` (letters deck) | 🟡 | 🟡 | Same engine as Memory — needs a lowercase a–z card deck + a "letters" level set. Small addition. |
| **Upper Case Memory** | `memory_sp.py` (letters deck) | 🟡 | 🟡 | Same engine — uppercase A–Z deck. |
| **Numbers Memory** | `memory_sp.py` (digits deck) | 🟡 | 🟡 | Same engine — 0–9 (and beyond) digit deck. |
| **Sound Memory** | `soundmemory.py` | ✅ | ✅ | `?`-tiles play a clip; match by audio id; a match reveals the picture. Grids 2×2 → 4×3. |
| **Fishtank** | `fishtank.py` | ⬜ | ⬜ | Click the fish to clear the tank; timed. Assets in `assets/graphics/lib/CPData/FishtankData` + `assets/audio/.../FishtankData`. |
| **Find Characters** | `findit_sp.py` | ⬜ | ⬜ | Spot the differences between two near-identical pictures. Assets under `Findit_spData`. |
| **Falling Letters** | `fallingletters.py` / `dltr.py` | ✅ | ✅ | Type (physical or on-screen QWERTY keyboard) the letter on each balloon before it hits the danger line; 3 lives; difficulty ramps with score. |
| **Puzzle** | `puzzle.py` | ⬜ | ⬜ | Drag jigsaw pieces to their slot. Tilesets (`PuzzleData/{childsplay,seniorplay}/tileset_1`) already in `assets/`. |
| **Find Sound** | `findsound.py` | ⬜ | ⬜ | Hear a sound, click the picture it belongs to. Clips + images (`FindsoundData`) are already vendored — the web build reuses them for Sound Memory. 6 levels in the original. |
| **Flashcards** | `flashcards.py` | ⬜ | ⬜ | Show a picture, play/label it in the target language; 5 levels. Needs the `alphabet-sounds/` voice packs. |
| **Pong** | `pong.py` | ⬜ | ⬜ | Bat-and-ball. `PongData` sounds (`winner.ogg`, `bump.wav`, `pick.wav`) are already used by other games. |
| **PackId** | `packid.py` | ✅ | ✅ | Open pillar maze, grid-snapped player, fruit "ghosts" with non-reversing AI, arrow **and** swipe steering, cherry pickup, friendly bump→reset (no game over), 3 sizes. |
| **Billiard** | `billiard.py` | ✅ | ✅ | 2D ball physics (damping, elastic ball-ball, cushion restitution), drag-to-aim with a power line, 6 pockets, cue-scratch respawn, 3/6/10-ball racks. Godot uses `RigidBody2D`; web uses a substepped custom solver. |

### What's next (priority order)

1. **Memory content decks** — lowercase / uppercase / numbers modes on the
   existing Memory scene (add a deck picker; low effort, closes 3 rows).
2. **Find Sound** — assets are already vendored; simple click-the-picture loop.
3. **Puzzle** — drag-and-drop; tilesets already present.
4. **Fishtank** — click-to-clear; quick to build.
5. **Pong** — small; physics shared with Billiard.
6. **Find Characters**, **Flashcards** — need more content wrangling.

---

## Extended legacy catalogue (not committed, tracked for completeness)

The original also ships these. None are converted; listed so nothing is lost.

| Activity | Legacy module | Godot | Web | What it is |
| --- | --- | :---: | :---: | --- |
| Numbers (counting) | `numbers_sp.py` | ⬜ | ⬜ | Count the objects on screen and pick the number. |
| Electro | `electro_sp.py` | ⬜ | ⬜ | Match pairs of pictures with wires (a Memory variant). |
| Fourrow | `fourrow.py` | ⬜ | ⬜ | Connect Four. |
| Tic Tac Toe | `TicTacToe.py` | ⬜ | ⬜ | Noughts and crosses. |
| Simon | `simon_sp.py` | ⬜ | ⬜ | Repeat the growing sequence of sounds/colours. |
| Block Breaker | `BlockBreaker.py` | ⬜ | ⬜ | Breakout / Arkanoid. |
| Image Changer | `ichanger.py` | ⬜ | ⬜ | Memorise images, then spot which one changed. |
| Photo Album | `photoalbum.py` | ⬜ | ⬜ | Browse a themed set of photos. |
| Wipe | `wipe.py` | ⬜ | ⬜ | "Wipe" the screen to reveal the picture underneath. |
| Synonyms | `synonyms.py` | ⬜ | ⬜ | Make a word from given letters. |
| Spin the Bottle | `spinbottle.py` | ⬜ | ⬜ | Word game — name something starting with a letter. |
| Quiz engine | `quizengine.py` / `quiz.py` | ⬜ | ⬜ | Multiple-choice quiz framework. |
| Quiz: General | `quiz_general.py` | ⬜ | ⬜ | Trivia deck. |
| Quiz: History | `quiz_history.py` | ⬜ | ⬜ | Trivia deck. |
| Quiz: Math | `quiz_math.py` / `math_test.py` | ⬜ | ⬜ | Arithmetic questions. |
| Quiz: Melody | `quiz_melody.py` | ⬜ | ⬜ | Name the tune / instrument. |
| Quiz: Picture | `quiz_picture.py` | ⬜ | ⬜ | Identify the picture. |
| Quiz: Royal | `quiz_royal.py` | ⬜ | ⬜ | Trivia deck (regional). |
| Quiz: Sayings | `quiz_sayings.py` | ⬜ | ⬜ | Complete the proverb. |
| Quiz: Text | `quiz_text.py` | ⬜ | ⬜ | Text comprehension. |
| Quiz: Personal / Regional | `quiz_personal.py`, `quiz_regional.py` | ⬜ | ⬜ | Configurable local trivia decks. |

---

_Last updated: 2026-08-29 — 5 game scenes live on both targets (Memory,
Falling Letters, Sound Memory, PackId, Billiard); Memory's letter/number
decks and everything else still to do._
