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
| Quiz suite (shared engine + 5 decks) | 6 | ✅ 6 | ✅ 6 |

**Every classic Childsplay activity, nine extras, and the Quiz suite are
ported on both targets, at feature parity.** Daily Training, Photo Album,
Spin the Bottle and `birthday.py` are **out of scope** (see the end of
this file).

### Menu structure

The main dashboard has **20 tiles**: Memory, Falling Letter, Find Sound, Puzzle, Find It, Aquarium, Pong, Four in a Row, Flashcards, Block Breaker, Simon, Electro, Tic Tac Toe, Wipe, Image Changer, Numbers, Word Maker, Packid, Billiards, Quiz.
The **Quiz** tile opens a deck picker (`quiz-menu.js` / `QuizMenu.tscn`)
routing to the shared engine (`quiz.js` / `Quiz.tscn`) with a `deck` id.
The **Memory** tile opens a sub-menu (`MemoryMenu.tscn` / `memory-menu.js`)
with five decks — **Pictures, lowercase, UPPERCASE, Numbers, Sounds** —
routing to `Memory.tscn`/`memory.js` (with a `variant`) or, for Sounds, to
`SoundMemory.tscn`/`soundmemory.js`. Sound Memory no longer has its own
top-level tile.

---

## Classic Childsplay activities (the shipped 14)

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
| **Falling Letters** | `fallingletters.py` / `dltr.py` | ✅ | ✅ | Type the letter on each balloon before it hits the danger line. **6-tier `LEVELS` table** (gentle "Warm up" first level, monotonic ramp, 12 pops/level); out of lives just replays the level — no game-over ejection (§H.1.3). **Dual keyboard** (§I.3), both targets: the device OS keyboard (hidden `<input>` web / `virtual_keyboard_show` Godot) is primary on touch, the in-canvas QWERTY stays as the accessibility path, a `⌨` toggle switches between them (persisted). |
| **Puzzle** | `puzzle.py` | ✅ | ✅ | Drag the pieces of a painting into the frame. **10 levels**: 3 regular grids (`easy`), 4 free-cut irregular-rectangle levels (`med`), 3 fine-cut levels (`hard`). Each level's picture is drawn from the shared `backgrounds` pool **filtered by the level's difficulty tier** (`assets/data/backgrounds.json`), with session no-repeat shared with Wipe (§B). `Puzzle.tscn` / `puzzle.js`. |
| **Find Sound** | `findsound.py` | ✅ | ✅ | Hear a clip, tap the picture it belongs to; themed levels (animals, vehicles, instruments, noises), "Play again" button, wrong taps just wobble. Levels + spoken-label overrides load from the hand-editable `assets/data/findsound.json` (§J). A **say-the-names** toggle (§E.3) speaks the picture on a correct tap. `FindSound.tscn` / `findsound.js`. |
| **Flashcards** | `flashcards.py` | ✅ | ✅ | Picture + word cards for 12 animals (reusing Memory / Find Sound art). **English is spoken by OS / browser text-to-speech** (`DisplayServer.tts_*` / `speechSynthesis`); **Deutsch / Nederlands / Français / Español** play the recorded Childsplay clips we ship, with a TTS fallback in that language. No audio at all → the card still shows the picture + word. `Flashcards.tscn` / `flashcards.js`. |
| **Pong** | `pong.py` | ✅ | ✅ | Bat and ball versus a gentle AI paddle; first to 5; 3 levels of AI speed. Pointer / arrow-key paddle, ball speeds up per hit with spin from the contact point. A **court-style picker** (§D.5): Modern / Retro (Atari B&W) / 90s Neon / Y2K — each ships its own light + dark, the global light/dark toggle applies on top. `Pong.tscn` / `pong.js`. |
| **PackId** | `packid.py` | ✅ | ✅ | Open pillar maze, grid-snapped player, fruit "ghosts" with non-reversing AI, arrow **and** swipe steering, cherry pickup, friendly bump→reset (no game over), 3 sizes. |
| **Billiard** | `billiard.py` | ✅ | ✅ | 2D ball physics (damping, elastic ball-ball, cushion restitution), drag-to-aim with a power line, 6 pockets, cue-scratch respawn, 3/6/10-ball racks. Godot uses `RigidBody2D`; web uses a substepped custom solver. |

### What's next

Nothing outstanding. The classic 14, the nine shipped extras, and the Quiz
suite are all done on both targets, and every playtest §L row in
[Design-Policy.md](Design-Policy.md) is closed. Daily Training, Photo
Album, Spin the Bottle and `birthday.py` are **out of scope** (rationale
at the end of this file).

The only remaining task is a **visual-QA pass on a real device and
browser** — every game is verified headless (script parse + scene load),
but the rendered output hasn't been eyeballed.

---

## Extended activities — shipped

Not part of the stock kid menu, but converted from the extended legacy
catalogue and wired into the launcher on both targets. All at feature
parity.

| Activity | Legacy module | Godot | Web | What it is |
| --- | --- | :---: | :---: | --- |
| Numbers | `numbers_sp.py` | ✅ | ✅ | Numbered tiles scattered on the board; study them, press Start, they go blank, then tap them in order 1→N from memory. A wrong tap flashes red and peeks the whole board for a moment — no progress lost. Six levels, 4→9 tiles. One-row HUD (§G.2). `Numbers.tscn` / `numbers.js`. |
| Electro | `electro_sp.py` | ✅ | ✅ | The wiring board — animal pictures down the left, their names (shuffled) down the right; drag a wire from each picture to its name. Correct wires lock green, wrong ones buzz and fall away. Six levels, 3→8 pairs. Drag targets are fingertip-sized (§I.2): pick up a wire from within 46 px of a node, release snaps to the **nearest** node in the other column within 120 px, with a finger halo + a snap-target ring. Picture↔name pairs load from the hand-editable `assets/data/electro.json` (17 shipped; `tools/gen-electro-data.sh` regenerates from the art), with a baked-in fallback. A **say-the-names** toggle (§E.3) speaks the animal when you pick up its wire. `Electro.tscn` / `electro.js`. |
| Fourrow / Four in a Row | `fourrow.py` | ✅ | ✅ | Connect Four vs the computer (3 AI levels: random → win/block → win/block + centre bias), **or a local Pass & Play 2-player game** (§K) — a 1P/2P button before the first move, persisted; turn/colour HUD, "Red wins!" / "Yellow wins!". `FourRow.tscn` / `fourrow.js`. |
| Tic Tac Toe | `TicTacToe.py` | ✅ | ✅ | Noughts and crosses vs the computer (Easy random / Medium win-block-centre / Hard perfect minimax), **or local Pass & Play** (§K) — 1P/2P button before the first move, persisted; "Blue wins!" / "Orange wins!". `TicTacToe.tscn` / `tictactoe.js`. |
| Simon | `simon_sp.py` | ✅ | ✅ | Repeat the growing colour-and-tone sequence; **ten levels, target length 2→11**. Tones are synthesised (WebAudio oscillator / procedural `AudioStreamWAV`), so no audio assets. A wrong tap just replays the same sequence — no lives, no game-over. `Simon.tscn` / `simon.js`. |
| Block Breaker | `BlockBreaker.py` | ✅ | ✅ | Gentle Breakout — slide the paddle, bounce the ball, clear six walls of bricks. Tough (grey) bricks take two hits; losing the ball costs one of three lives, then you just replay the wall. Pointer / drag / arrow-key paddle, paddle-relative bounce angle. `BlockBreaker.tscn` / `blockbreaker.js`. |
| Image Changer | `ichanger.py` | ✅ | ✅ | Study the row of pictures, press Start; the cards flip down and back and one picture has changed — tap it. Four levels (3 cards, 3 + position shuffle, 4 cards, 4 + shuffle), three rounds each. Reuses the Memory animal art. A **say-the-names** toggle (§E.3) speaks a card while studying, and the changed card on a correct guess. `ImageChanger.tscn` / `ichanger.js`. |
| Wipe | `wipe.py` | ✅ | ✅ | A painting hidden under a grey cover; drag the sponge to wipe the cover away. **12 levels**, target fraction 0.65→0.99, sponge 54→26 px. Each level's picture is drawn from the shared 17-painting `backgrounds` pool **by difficulty tier** (`assets/data/backgrounds.json`), no-repeat shared with Puzzle (§B). Cover is a fine cell grid (portable + progress survives a resize). `Wipe.tscn` / `wipe.js`. |
| Word Maker | `synonyms.py` | ✅ | ✅ | Adapted from the senior `synonyms` drill for young English readers: given a starting letter, build words with the on-screen keyboard (or type). Scored against the bundled ~1235-word kid dictionary `assets/data/wordlist.json` (edit `tools/gen-wordlist.py` to extend). Spoken prompt on open; a **Hint** button reveals an unused word (2 per level); a `⌨` toggle switches between the device keyboard and the on-screen one (§I.3), both targets. Five letters (S/B/C/T/P), 3→5 words. `WordMaker.tscn` / `synonyms.js`. |

---

## Quiz suite

A shared multiple-choice engine (`web-canvas/js/games/quiz.js` /
`desktop-godot/scenes/games/Quiz.tscn` + `Quiz.gd`) behind one **Quiz**
menu tile that opens a deck picker (`quiz-menu.js` / `QuizMenu.tscn` — the
§F.3.4 "bundle a family behind one tile" pattern). The engine loads
`assets/data/quiz/<deck>.json`, groups questions by `level`, shuffles the
answer order, speaks the question through TTS (🔊 re-read button), runs a
one-row HUD (§G), and never penalises a wrong tap — it just shakes
(§H.1.3). Clear a level's questions to advance; clear the last to win.

Decks are hand-editable JSON (§J): `{ name, prompt, questions:[{ level,
q, choices, answer, image? }] }`.

| Piece | Legacy module | Godot | Web | What it is |
| --- | --- | :---: | :---: | --- |
| **Quiz engine** | `quizengine.py`, `quiz.py` | ✅ | ✅ | Shared framework above + the deck picker. Not itself a tile. |
| Quiz: General | `quiz_general.py` | ✅ | ✅ | Kid-friendly general knowledge, 5 levels. `assets/data/quiz/general.json`. |
| Quiz: Pictures | `quiz_picture.py` | ✅ | ✅ | "Which animal is this?" over the shared `animals` art, 5 levels. `quiz/picture.json`. |
| Quiz: Math | `quiz_math.py`, `math_test.py` | ✅ | ✅ | Arithmetic, counting → add/subtract → mixed, 5 levels. `quiz/math.json`. |
| Quiz: Words | `quiz_text.py` | ✅ | ✅ | Rhymes, opposites, first sounds, categories, 3 levels. `quiz/words.json`. |
| Quiz: Sayings | `quiz_sayings.py` | ✅ | ✅ | Finish the common saying, 3 levels. `quiz/sayings.json`. |

Not shipped (each needs content the port can't synthesise): **Melody**
(needs an audio deck), **History** (per-language decks + decade photos),
**Royal** (regional trivia), **Personal / Regional** (need a user-supplied
config file). Adding any of them is now just a JSON file — the engine and
picker already handle it.

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
Maker). Summary table reworked to the three groups.

2026-08-30 (playtest build): worked the playtest punch-list. Infra —
SVG-first asset resolution on both targets (Godot `IMAGE_EXTS` reorder +
priority-aware collision + `/pools/` tiebreak), a `themes/<style>/`
alternate-art overlay with a launcher **artwork toggle** (classic/modern),
`assets/data/backgrounds.json` difficulty tiers with `tierBag` /
`draw_tiered`. **Godot menu rebuilt to §F** — square tiles, responsive +
paginated grid, flat `icons/<id>` pool art, light/dark + artwork + sound
chrome. Web menu tiles enlarged. **Falling Letter**: 6-tier LEVELS table +
dual keyboard (device OS keyboard via hidden input, in-canvas kept for
a11y, ⌨ toggle) + no-eject level replay. **Word Maker**: same ⌨ toggle.
**Puzzle**: 10 levels, tier-tagged painting draw. **Wipe**: tier steps +
full 17-painting shared pool. **Pong**: Modern/Retro/Neon/Y2K court
styles, each light+dark, picker on both targets. **Aquarium**: last five
fish named, Material-3 parallax backdrop (SVG fish drop-in ready).
**Numbers** HUD overlap already fixed earlier — verified one-row.
Every game filed a `docs/assets/<id>.assets.md` (§A.7).

2026-08-30 (playtest follow-through — all §L rows closed):
- **Godot letter-game parity** — `FallingLetter.gd` gained the 6-tier
  `LEVELS` table + a Button-row on-screen keyboard + the `⌨` toggle it was
  missing (web-only before); out-of-lives now replays the level.
  `WordMaker.gd` got the `⌨` toggle (it already had a drawn keyboard).
- **Electro (Godot) §I.2** — `_node_hit()` returns the nearest node within
  a reach radius (46 px pick-up / 120 px release), plus a finger halo and
  a snap-target ring. The web board already had this.
- **Simon** — 8 → 10 levels, sequence length 2 → 11 (§H.2), both targets.
- **Four in a Row + Tic Tac Toe (Godot)** — local **Pass & Play** (§K):
  a 1P/2P button before the first move, persisted to `settings.cfg`; AI
  skipped, alternating human turns, colour-named win text. Web already
  had it.
- **Spoken picture labels (§E.3)** — a "say the names" pill for Memory
  (pictures), Find Sound, Electro and Image Changer, both targets:
  web `util.js makeNameToggle`, Godot `GameContext.name_toggle_*` +
  `draw_name_pill`. OFF by default, persisted, hidden where there is no
  speech. (Aquarium and Flashcards already spoke names.)
- **Find Sound → data file (§J)** — `assets/data/findsound.json` (levels +
  spoken-label overrides), loaded via `loadData` / `load_json` with an
  offline fallback.
- **Godot HUD-bar contrast parity (§G)** — new `GameContext.style_hud_bar()`
  paints a themed `hud` surface + `line` divider behind the top chrome and
  recolours the HUD labels to `hud_text` / `hud_muted` (fixing fixed
  colours that vanished in light mode). Wired into 16 games; re-applied on
  `theme_changed`.
- **Quiz suite** — the shared multiple-choice engine (`quiz.js` /
  `Quiz.tscn` + `Quiz.gd`) behind one **Quiz** tile → a deck picker
  (`quiz-menu.js` / `QuizMenu.tscn`), with 5 hand-editable JSON decks
  (General / Pictures / Math / Words / Sayings). `AssetLoader.has_stream()`
  added so dynamic spoken text no longer logs "missing sound" warnings on
  its way to live TTS. Dashboard is now 20 tiles.
- The one-session web menu tile-size tweak was reverted — the original
  2-row layout with page arrows was better.

Verified: Godot editor parse + headless scene-load of every game clean;
`node --check` clean on every web module. Not yet visually QA'd on a real
device / browser._

2026-08-31 (asset-layout cleanup — Design Policy §A migration finished):
- **New `docs/ASSETS.md`** — the source-of-truth doc: the three asset
  trees (`/assets/` canonical, `desktop-godot/assets/` git-ignored mirror,
  `web-canvas/assets/` committed web build), the sync/build flow, and the
  runtime-resolution rules. README head now points at it.
- **Godot `sync-assets.sh` rewritten to curate** — mirrors only
  `graphics/{pools,themes}` + `audio/{sfx,voice,soundmemory,flashcards}` +
  `fonts` + `data`, with a prune step for stale legacy dirs. The mirror
  drops **65 MB → 9.4 MB** and `AssetLoader`'s duplicate-filename warning
  goes **1668 → 3** (known pool-vs-pool overlaps).
- **Audio pool migration** — new `tools/migrate-audio.sh` builds
  `assets/audio/sfx/` (21 clips), `assets/audio/soundmemory/` (the 36
  shared Find Sound / Sound Memory clips) and `assets/audio/flashcards/`
  (12 animal names × de/nl/fr/es) from the legacy dumps. Both
  `sync-assets.sh` scripts now read those instead of
  `assets/audio/lib/CPData/…` long paths. `audio/lib/` and
  `audio/alphabet-sounds/` stay for provenance, unsynced (twins of
  `graphics/lib/`).
- **Flashcard audio is flat + language-suffixed** — `flashcards/<word>_<lang>.ogg`
  (`cow_fr.ogg`), one folder, every name globally unique. Both games build
  the key as `"%s_%s.ogg" % [word, code]`; adding a language is "drop the
  `_<code>` clips + a `LANGS` entry". This removes the earlier
  `AssetLoader.SCAN_SKIP_DIRS` special case — flashcards now index like
  any other clip.
- **Code repoints** — the 4 hard-coded `res://assets/graphics/lib/…` paths
  in `Packid.tscn` / `Aquarium.tscn` now point at pool twins;
  `Aquarium.gd` `BUBBLE_TEX`/`SND_AMBIENT` and `FourRow.gd`
  `SND_WIN`/`SND_LOSS` renamed to the pool names; `Flashcards.gd` /
  `flashcards.js` load `flashcards/<word>_<lang>.ogg` via the normal
  loader.
- `tools/migrate-assets.sh` gains `ui/soundbut.png` (Sound Memory card
  face, previously served only from `lib/`).
- Web build is byte-identical after the change apart from `manifest.json`
  (+`ui/soundbut`) and the new `ui/soundbut.png`.

Verified: `godot --headless` import pass clean; headless scene-load of all
20 games + 3 menus clean (`fails: 0`); both `sync-assets.sh` + both
`migrate-*.sh` run clean; every `sfx/*` path referenced in web JS resolves.
Still not visually QA'd on a real device / browser._

2026-08-31 (voice pack — natural voices):
- **`gen-voice.sh` rewritten** — each `v_<slug>.ogg` is sourced
  best-first: an original **human recording** (`HUMAN_SRC` map), else a
  synthesiser picked by `TTS=`: **google** (Google Translate TTS —
  natural, no install, needs network), **piper** (offline neural), or
  **espeak** (robotic fallback). A google/piper run re-bakes the
  synthetic clips; espeak only fills gaps. `FORCE=1` / `NO_HUMAN=1`
  modifiers. Re-runs are idempotent (was churning bytes via non-repro
  libvorbis).
- **All ~70 synthetic phrase clips re-baked with Google TTS** — the
  espeak "robot voice" is gone. The 36 human en_GB letter/digit clips
  (`v_a`…`v_z`, `v_0`…`v_9`) are kept untouched.
- **en_GB letters + digits folded in** earlier this day — GPL human
  recordings, re-encoded to the pack's 22 kHz mono, so `say("a")` /
  `say("3")` get a real voice.
- **Flashcards English routing** fix means the baked `v_<word>.ogg` is
  actually reached now: baked clip → live TTS → silence.
- Design-Policy **§E.4 marked SUPERSEDED** — every phrase needs a baked
  `.ogg` and it plays first.
- Voice pack 106 files (~1.2 MB). Both `sync-assets.sh` re-run.
- For a fully offline / reproducible pack: `TTS=piper tools/gen-voice.sh`
  on a machine with piper + a voice model.

Verified: all 106 clips valid audio; exactly the 70 synthetic clips
changed (0 human); `godot --headless` import + boot clean (211 audio
indexed); both `sync-assets.sh` clean; web + Godot voice dirs both 106._

2026-08-31 (voice pack — cover the names that had no clip):
- **12 spoken names had no baked clip** and were falling through to live
  (robot) TTS: the 5 fish added late to Aquarium's `SPECIES` (emperor
  angelfish, Moorish idol, bass, pomfret, snapper) and 7 animal-pool
  names Memory / Image Changer speak via `nameFromId` (turtle, chicken,
  redbird, bluebirds, gnu, bluebaby, greenbaby). Added to `gen-voice.sh`
  `PHRASES` and baked with Google TTS. Pack 106 → 118.
- **`gen-voice.sh` keep-semantics simplified** — a plain run now keeps
  every existing clip and only renders new/missing phrases (no engine
  special-case). `FORCE=1` re-bakes the whole pack; `NO_HUMAN=1`
  unchanged.

Verified: 12 new clips valid audio, 0 existing clips re-churned; both
`sync-assets.sh` clean; `godot --headless` import + boot clean (223 audio
indexed); web + Godot voice dirs both 118._

2026-08-31 (spoken-name overrides):
- `nameFromId` (`util.js`) / `name_from_id` (`GameContext.gd`) gain a
  `NAME_OVERRIDES` map for pool ids whose auto-name reads oddly. First
  entries: `bluebaby` → "baby blue bird", `greenbaby` → "baby green
  bird" (the `19_/20_` baby-bird sprites in the Memory / Image Changer
  deck). `gen-voice.sh` bakes the friendly phrases; the `v_bluebaby.ogg`
  / `v_greenbaby.ogg` clips are removed. Pack stays 118._
