# Game conversion status

Tracks every activity from the original **Childsplay**
(`legacy-sources/childsplay-legacy/`) against the two modern targets:

- **Godot** — `desktop-godot/scenes/games/*.tscn` (+ `scripts/games/*.gd`),
  wired into `desktop-godot/scripts/MainMenu.gd`
- **Web** — `web-canvas/js/games/*.js`, wired into `web-canvas/js/games/index.js`

Update this file in the same commit that adds or finishes a game.

## Design Policy

Every game on both targets MUST follow **[docs/Design-Policy.md](Design-Policy.md)**
— the universal rules written after the first play-test: flat purpose-named
asset pools with tag-based difficulty, shared picture pools with session
no-repeat, `svg → png → jpg` format fallback, a mandatory light/dark palette
with WCAG contrast, "no audio outlives its scene" + a 🔊 read-instructions
button in every game, a one-row HUD contract (`HUD_H = 64`, no gameplay above
it), ≥ 5 monotonically-ramping levels, ≥ 44 px touch targets with
snap-to-nearest, content in `assets/data/` files, and optional local
2-player for turn-based games. New games build to it from the start; existing
games carry a per-game migration checklist in §L of that doc. The per-game
graphics declaration uses **[docs/templates/ASSETS.template.md](templates/ASSETS.template.md)**.

## Legend

| Mark | Meaning |
| --- | --- |
| ✅ | Done — playable and wired into the launcher |
| 🟡 | Partial — the engine exists but a content set or feature is missing |
| 🔜 | Planned — next up |
| ⬜ | Not started |

## Summary

| Group | Rows | Godot | Web |
| --- | :---: | :---: | :---: |
| Classic Childsplay activities | 14 | ✅ 14 | ✅ 14 |
| Extended activities — shipped | 9 | ✅ 9 | ✅ 9 |
| Quiz suite (engine + 10 decks) | 11 | 🔜 0 | 🔜 0 |

**Every classic Childsplay activity plus nine extras is ported on both
targets, at feature parity.** The only outstanding committed work is the
**Quiz suite** below. Daily Training, Photo Album, Spin the Bottle and
`birthday.py` are **out of scope** (see the end of this file).

### Menu structure

The main dashboard has **19 tiles**: Memory, Falling Letter, Find Sound, Puzzle, Find It, Aquarium, Pong, Four in a Row, Flashcards, Block Breaker, Simon, Electro, Tic Tac Toe, Wipe, Image Changer, Numbers, Word Maker, Packid, Billiards.
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

The classic 13 and the nine shipped extras are all done. The only
outstanding committed work is the **Quiz suite** below — one shared engine
plus ten decks. Daily Training, Photo Album, Spin the Bottle and
`birthday.py` are **out of scope** (rationale at the end of this file).

---

## Extended activities — shipped

Not part of the stock kid menu, but converted from the extended legacy
catalogue and wired into the launcher on both targets. All at feature
parity.

| Activity | Legacy module | Godot | Web | What it is |
| --- | --- | :---: | :---: | --- |
| Numbers | `numbers_sp.py` | ✅ | ✅ | Numbered tiles scattered on the board; study them, press Start, they go blank, then tap them in order 1→N from memory. A wrong tap flashes red and peeks the whole board for a moment — no progress lost. Six levels, 4→9 tiles. `Numbers.tscn` / `numbers.js`. |
| Electro | `electro_sp.py` | ✅ | ✅ | The wiring board — animal pictures down the left, their names (shuffled) down the right; drag a wire from each picture to its name. Correct wires lock green, wrong ones buzz and fall away. Six levels, 3→8 pairs. Picture↔name pairs load from the hand-editable `assets/data/electro.json` (17 shipped; `tools/gen-electro-data.sh` regenerates from the art), with a baked-in fallback. `Electro.tscn` / `electro.js`. |
| Fourrow / Four in a Row | `fourrow.py` | ✅ | ✅ | Connect Four vs the computer (3 AI levels: random → win/block → win/block + centre bias). `FourRow.tscn` / `fourrow.js`. |
| Tic Tac Toe | `TicTacToe.py` | ✅ | ✅ | Noughts and crosses vs the computer. Three opponents: Easy (random), Medium (win / block / centre), Hard (perfect minimax). You are X and move first; beat Easy and Medium to advance, hold the perfect computer to a draw to finish. `TicTacToe.tscn` / `tictactoe.js`. |
| Simon | `simon_sp.py` | ✅ | ✅ | Repeat the growing colour-and-tone sequence; six levels, target length 2→7. Tones are synthesised (WebAudio oscillator / procedural `AudioStreamWAV`), so no audio assets. A wrong tap just replays the same sequence — no lives, no game-over. `Simon.tscn` / `simon.js`. |
| Block Breaker | `BlockBreaker.py` | ✅ | ✅ | Gentle Breakout — slide the paddle, bounce the ball, clear six walls of bricks. Tough (grey) bricks take two hits; losing the ball costs one of three lives, then you just replay the wall. Pointer / drag / arrow-key paddle, paddle-relative bounce angle. `BlockBreaker.tscn` / `blockbreaker.js`. |
| Image Changer | `ichanger.py` | ✅ | ✅ | Study the row of pictures, press Start; the cards flip down and back and one picture has changed — tap it. Four levels (3 cards, 3 + position shuffle, 4 cards, 4 + shuffle), three rounds each. Reuses the Memory animal art. `ImageChanger.tscn` / `ichanger.js`. |
| Wipe | `wipe.py` | ✅ | ✅ | A painting hidden under a grey cover; drag the sponge to wipe the cover away. Clear the target fraction to finish — six paintings (the GPL `WipeData` set), rising target 55→84% and a shrinking sponge. Cover is a fine cell grid (portable + progress survives a resize). `Wipe.tscn` / `wipe.js`. |
| Word Maker | `synonyms.py` | ✅ | ✅ | Adapted from the senior `synonyms` drill for young English readers: given a starting letter, build words with the on-screen keyboard (or type). Scored against the bundled ~1235-word kid dictionary `assets/data/wordlist.json` (edit `tools/gen-wordlist.py` to extend). Spoken prompt on open; a **Hint** button reveals an unused word (2 per level). Five letters (S/B/C/T/P), 3→5 words. `WordMaker.tscn` / `synonyms.js`. |

---

## Quiz suite — planned

The original ships a shared quiz engine (`quizengine.py` → `quiz.py`) and a
family of multiple-choice decks: a question at the top of the screen, tap
the correct answer from the choices below. **One engine port unlocks every
deck**, so this is tracked as a single body of work rather than eleven
separate ports.

**Engine port plan** — `QuizEngine.tscn` / `quiz.js`, built to the Design
Policy: load a deck, shuffle questions and answers, N answer buttons,
score + monotonic level ramp, the question spoken through TTS, 🔊
read-aloud button, one-row HUD. Legacy content in `lib/CPData/Quiz*Data/`
(`general_knowledge.xml`, per-language `.rc` files, the history photos)
gets converted into hand-editable `assets/data/quiz/*.json`, one file per
deck, with a `tools/gen-quiz-data.*` regenerator.

| Piece | Legacy module | Godot | Web | What it is |
| --- | --- | :---: | :---: | --- |
| **Quiz engine** | `quizengine.py`, `quiz.py` | 🔜 | 🔜 | Shared framework described above. Not a menu tile itself — each deck below is a tile that boots the engine with its `deck` id. |
| Quiz: General | `quiz_general.py` | 🔜 | 🔜 | General-knowledge trivia. 6 levels. Source: `general_knowledge.xml`. |
| Quiz: Math | `quiz_math.py`, `math_test.py` | 🔜 | 🔜 | Generated arithmetic questions, order-of-operations aware. `math_test.py` is the timed-drill variant of the same content. |
| Quiz: Picture | `quiz_picture.py` | 🔜 | 🔜 | Identify what is shown in a picture. 6 levels. Can reuse the Memory / Find Sound art pools. |
| Quiz: Melody | `quiz_melody.py` | 🔜 | 🔜 | A short clip plays; name the tune or instrument. Needs an audio deck. |
| Quiz: Sayings | `quiz_sayings.py` | 🔜 | 🔜 | Finish the proverb / common saying. |
| Quiz: Text | `quiz_text.py` | 🔜 | 🔜 | Short reading-comprehension questions. |
| Quiz: History | `quiz_history.py` | 🔜 | 🔜 | "Which decade?" — place a photo or fact in its period. 2 levels; per-language decks (de/en/fr/nl/sv) + decade photos. |
| Quiz: Royal | `quiz_royal.py` | 🔜 | 🔜 | Trivia about royalty. 2 levels. Regional interest — low priority. |
| Quiz: Personal | `quiz_personal.py` | 🔜 | 🔜 | Questions about the player. Needs a user-supplied config file; ships with an empty deck. |
| Quiz: Regional | `quiz_regional.py` | 🔜 | 🔜 | Local-area trivia. Needs a user-supplied config file; ships with an empty deck. |

---

## Out of scope

Deliberately not ported — these don't fit a pick-and-play kids' activity
launcher. Listed so the decision is on the record.

| Activity | Legacy module | Why not |
| --- | --- | --- |
| Daily Training | `dltr.py` | Not a game — a meta-runner that plays a fixed scripted sequence of the other activities. The launcher already lets a child pick freely, so it adds nothing. |
| Photo Album | `photoalbum.py` | A slideshow of a bundled photo set — no interaction, no goal. |
| Birthday | `birthday.py` | A "days until your birthday" reminder screen. Unrelated to the activities and needs a stored birth date. |
| Spin the Bottle | `spinbottle.py` | Overlaps **Word Maker** (name dictionary words starting with a given letter). If wanted, it returns as a Word Maker mode, not a standalone tile. |

---

_Last updated: 2026-08-30 — §D light/dark palette sweep DONE on the web
target: all 18 remaining games now paint from the theme.* roles instead of
colour literals, so light mode is usable everywhere. HUD chrome stays fixed
dark (§G) with fixed-light DARK.* text on it. Iconic/decorative palettes
(Simon pads, billiard balls, brick tints, pong/packid/aquarium atmosphere)
kept as literals by design. WCAG: every text/surface role pair ≥4.5:1 in
both palettes; transient wrong-answer flashes reworked to a border so text
contrast holds. Godot parity DONE too: the 12 `_draw()` games now paint
from `GameContext.c(role)` and repaint live on `theme_changed`; iconic
palettes (Simon pads, brick tints, Four-in-a-Row discs → p1/p2) kept as
literals. Verified: headless instantiate + render of every themed scene in
both palettes, clean. Godot 3-way sound popover DONE: the menu's Sound
button now opens a Music / Effects / Voice panel that mutes the matching
audio bus, persists to settings.cfg `[audio]`, reloads on boot, and gates
live TTS on the Voice channel — the desktop twin of the web popover
(§E.3).

2026-08-30 (canvas playtest round 2): contrast rework — the HUD bar is now
a real themed surface (`hud` role + divider) instead of a near-invisible
scrim, HUD text follows the theme, and puzzle / packid / fallingletter got
the light/dark pass they were still missing. New roles: hud / card /
board. Flashcards + Image Changer cards stay white in both themes on a
`surface_alt` backdrop; Pong + Block Breaker play on a framed dark
"screen". Electro's picture↔name pairs moved to a hand-editable
assets/data/electro.json (both targets, +tools/gen-electro-data.sh). Word
Maker rebuilt: ~1235-word bundled dictionary (assets/data/wordlist.json,
tools/gen-wordlist.py), spoken intro, and a 2-per-level Hint button; Godot
in parity. Next §L items: Godot HUD-bar contrast parity, native device
keyboard for Falling Letter / Word Maker, §A/§C audio-pool migration,
Pong era themes.

2026-08-30 (scope): quizzes promoted from "tracked for completeness" to
committed work — new **Quiz suite — planned** section: one shared engine
(`quizengine.py`/`quiz.py` → `QuizEngine.tscn`/`quiz.js`) plus ten decks,
all 🔜, content to be converted into `assets/data/quiz/*.json`. The nine
already-shipped extras split out into their own **Extended activities —
shipped** table. New **Out of scope** section records the four dropped
activities and why: Daily Training (`dltr.py`, meta-runner, not a game),
Photo Album (`photoalbum.py`, no interaction), Birthday (`birthday.py`,
reminder screen), Spin the Bottle (`spinbottle.py`, redundant with Word
Maker). Summary table reworked to the three groups._
