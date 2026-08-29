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
| Godot (of the classic-activity rows below) | 14 | 0 | 0 |
| Web (of the classic-activity rows below)   | 14 | 0 | 0 |

**Every classic Childsplay activity is now ported on both targets** (plus
**Four in a Row** from the extended catalogue).

Both targets are at feature parity.

### Menu structure

The main dashboard has **11 tiles**: Memory, Falling Letter, Find Sound, Puzzle, Find It, Aquarium, Pong, Four in a Row, Flashcards, Packid, Billiards.
The **Memory** tile opens a sub-menu (`MemoryMenu.tscn` / `memory-menu.js`)
with five decks — **Pictures, lowercase, UPPERCASE, Numbers, Sounds** —
routing to `Memory.tscn`/`memory.js` (with a `variant`) or, for Sounds, to
`SoundMemory.tscn`/`soundmemory.js`. Sound Memory no longer has its own
top-level tile.

---

## Classic Childsplay activities (the shipped 13)

These are the activities in the standard Childsplay menu that this project
is committed to porting first.

| Game | Legacy module | Godot | Web | Notes |
| --- | --- | :---: | :---: | --- |
| **Memory — Pictures** | `memory_sp.py` | ✅ | ✅ | Flip/match, grids 2×2 → 5×4, win + next-level flow. `tileset_2` animal deck. Memory sub-menu → "Pictures". |
| **Memory — Lower Case** | `memory_sp.py` | ✅ | ✅ | Same engine, a–z glyph cards drawn on `CP_cardfront`. Memory sub-menu → "lowercase". |
| **Memory — Upper Case** | `memory_sp.py` | ✅ | ✅ | Same engine, A–Z glyph cards. Memory sub-menu → "UPPERCASE". |
| **Memory — Numbers** | `memory_sp.py` | ✅ | ✅ | Same engine, 0–9 glyph cards (10 pairs = the largest grid). Memory sub-menu → "Numbers". |
| **Sound Memory** | `soundmemory.py` | ✅ | ✅ | `?`-tiles play a clip; match by audio id; a match reveals the picture. Grids 2×2 → 4×3. Reached via the Memory sub-menu → "Sounds". |
| **Fishtank** / Aquarium | `fishtank.py` | ✅ | ✅ | Reinterpreted as a calm **Aquarium** toy (no score): ~12 fish with a 2-frame swim cycle wander + bob + bounce; poke a fish for a bubble sound + its floating name + a dart/flip; tap the water for a ripple + food pellet the nearest fish steer toward. Godot uses `GPUParticles2D` bubbles + a looping ambient track. `Aquarium.tscn` + `AquariumFish.tscn` / `aquarium.js`. |
| **Find Characters** / Find It | `findit_sp.py` | ✅ | ✅ | Spot the difference — the painting is shown twice, the right copy has a few coloured spots added; tap them all. Procedural (no authored diff-pairs needed) over the `WipeData` paintings; 3 levels (3/5/6 spots). `FindIt.tscn` / `findit.js`. |
| **Falling Letters** | `fallingletters.py` / `dltr.py` | ✅ | ✅ | Type (physical or on-screen QWERTY keyboard) the letter on each balloon before it hits the danger line; 3 lives; difficulty ramps with score. |
| **Puzzle** | `puzzle.py` | ✅ | ✅ | Drag the pieces of a painting into the frame. **6 levels**: 2x2 / 3x3 / 4x4 regular grids, then 3 harder levels cut into 6 / 9 / 12 **different-sized rectangles** by recursive random splits. Source art: GPL paintings from `WipeData`. `Puzzle.tscn` / `puzzle.js`. |
| **Find Sound** | `findsound.py` | ✅ | ✅ | Hear a clip, tap the picture it belongs to; 6 themed levels (animals, vehicles, instruments, noises), "Play again" button, wrong taps just wobble. `FindSound.tscn` / `findsound.js`. |
| **Flashcards** | `flashcards.py` | ✅ | ✅ | Picture + word cards for 12 animals (reusing Memory / Find Sound art). **English is spoken by OS / browser text-to-speech** (`DisplayServer.tts_*` / `speechSynthesis`); **Deutsch / Nederlands / Français / Español** play the recorded Childsplay clips we ship, with a TTS fallback in that language. No audio at all → the card still shows the picture + word. `Flashcards.tscn` / `flashcards.js`. |
| **Pong** | `pong.py` | ✅ | ✅ | Bat and ball versus a gentle AI paddle; first to 5; 3 levels of AI speed. Pointer / arrow-key paddle, ball speeds up per hit with spin from the contact point. `Pong.tscn` / `pong.js`. |
| **PackId** | `packid.py` | ✅ | ✅ | Open pillar maze, grid-snapped player, fruit "ghosts" with non-reversing AI, arrow **and** swipe steering, cherry pickup, friendly bump→reset (no game over), 3 sizes. |
| **Billiard** | `billiard.py` | ✅ | ✅ | 2D ball physics (damping, elastic ball-ball, cushion restitution), drag-to-aim with a power line, 6 pockets, cue-scratch respawn, 3/6/10-ball racks. Godot uses `RigidBody2D`; web uses a substepped custom solver. |

### What's next

The classic 13 are all done. Remaining work is the **extended catalogue**
below — Tic Tac Toe, Simon, Numbers (counting), Electro, Block Breaker,
Image Changer, Wipe, Synonyms and the Quiz decks — all small and
unblocked.

---

## Extended legacy catalogue (not committed, tracked for completeness)

The original also ships these. None are converted; listed so nothing is lost.

| Activity | Legacy module | Godot | Web | What it is |
| --- | --- | :---: | :---: | --- |
| Numbers (counting) | `numbers_sp.py` | ⬜ | ⬜ | Count the objects on screen and pick the number. |
| Electro | `electro_sp.py` | ⬜ | ⬜ | Match pairs of pictures with wires (a Memory variant). |
| Fourrow / Four in a Row | `fourrow.py` | ✅ | ✅ | Connect Four vs the computer (3 AI levels: random → win/block → win/block + centre bias). `FourRow.tscn` / `fourrow.js`. |
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

_Last updated: 2026-08-29 — Flashcards added on both targets (TTS for
English + recorded de/nl/fr/es packs). **All 13 classic Childsplay
activities are now ported**, plus Four in a Row. Next up: the extended
catalogue._
