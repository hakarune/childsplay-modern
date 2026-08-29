# Childsplay-Modern — Design Policy

**Status: authoritative.** Every game (current and future) on **both** targets
— `web-canvas/` (HTML5 canvas) and `desktop-godot/` (Godot 4) — MUST follow
this document. It was written after the first full play-test; the "Play-test
findings" at the end of each section are the concrete bugs that motivated the
rule.

Audience: ages **2–7**. Most players cannot read. Most play on a **phone or
tablet** in **portrait**. Assume touch, assume no reading, assume a short
attention span, assume an adult is not sitting next to them.

Keywords **MUST / MUST NOT / SHOULD / MAY** are used in the RFC-2119 sense.

Contents:

- [§A Asset directory layout & naming](#a--asset-directory-layout--naming)
- [§B Shared asset pools & no-repeat selection](#b--shared-asset-pools--no-repeat-selection)
- [§C Graphics format resolution (SVG → PNG → JPG)](#c--graphics-format-resolution)
- [§D Theme system — light/dark is mandatory](#d--theme-system--lightdark-is-mandatory)
- [§E Audio lifecycle & text-to-speech](#e--audio-lifecycle--text-to-speech)
- [§F Game-selection menu](#f--game-selection-menu)
- [§G In-game HUD contract](#g--in-game-hud-contract)
- [§H Difficulty & levels](#h--difficulty--levels)
- [§I Touch targets & text input](#i--touch-targets--text-input)
- [§J Content-driven games (data files)](#j--content-driven-games)
- [§K Local multiplayer](#k--local-multiplayer)
- [§L Per-game migration checklist](#l--per-game-migration-checklist)

---

## §A — Asset directory layout & naming

### A.1 The problem

The tree under `assets/graphics/lib/CPData/<Foo>Data/tileset_1/…` is the raw
legacy dump, mirrored verbatim. It is **not** an intentional structure. It
forces paths like
`assets/graphics/lib/CPData/WipeData/tileset_1/renoir0.jpg` and makes the
Godot `AssetLoader` report *1668 duplicate filenames* (same name under many
themes/locales, "first match wins" — fragile).

### A.2 Canonical layout (new)

The **only** graphics locations games may reference:

```
assets/graphics/
  backgrounds/     full-scene pictures: paintings, photos, tank scenes, quiz-picture art
  animals/         single-subject animal cutouts (numbered variants)
  objects/         single-subject non-animals: vehicles, instruments, food, tools
  ui/              shared chrome: card_front, card_back, button, sponge, danger_line, bubble, particle
  icons/           one per game id (menu tiles) + menu chrome
  sprites/<game>/  DENSE single-game sprite/frame sets only (packid tiles, billiards balls, fish swim frames)
assets/audio/
  sfx/ voice/ music/    (mirrors the three Godot buses)
assets/data/       content files — see §J
```

Rules:

- **A.2.1** Shared pools (`backgrounds`, `animals`, `objects`, `ui`, `icons`)
  are **flat** — no sub-folders. Every filename in a pool is globally unique.
- **A.2.2** A `sprites/<game>/` sub-folder is the **only** permitted game
  sub-folder, and only for a set that is (a) single-game and (b) more than
  ~6 files. A single-game background still goes in `backgrounds/` with a
  name-prefix (`backgrounds/aquarium_1.jpg`).
- **A.2.3** `assets/graphics/lib/` (raw legacy import) stays for provenance
  but is **no longer synced to either target** after migration.

### A.3 Naming grammar

```
<pool>/<name>[_<variant>][_<difficulty>][_<theme>].<ext>
```

| Token | Values | Notes |
| --- | --- | --- |
| `name` | `[a-z0-9]+` | no spaces, no camelCase. `castle`, `redpanda`, `aquarium` |
| `variant` | `1`..`n`, or a short word | near-duplicates: `frog_1`, `frog_2`, `frog_3`. Themed sets share `name`: `aquarium_1` |
| `difficulty` | exactly one of `easy` `med` `hard` | **omitted = usable at any tier** |
| `theme` | exactly one of `dark` | present only when the asset needs a hand-made dark version (see §D.4). Omitted file = the light/default asset |
| `ext` | `svg` `png` `jpg` `jpeg` `webp` | resolution order in §C |

- **A.3.1** `name` MUST NOT contain a token equal to a reserved word
  (`easy`/`med`/`hard`/`dark`). Parsers tokenise from the right against the
  known tag vocabularies; whatever is left is `name[_variant]`.
- **A.3.2** Difficulty is a **filename tag, never a folder**. `meadow_easy.jpg`,
  `castle_hard.jpg`. (The user's earlier "easy/medium/hard folders" idea is
  explicitly replaced by this.)
- **A.3.3** Themed sets are a **name prefix + numeric variant**:
  `backgrounds/aquarium_1.jpg` … `aquarium_6.jpg`. A game asks the pool for
  `aquarium_*`.

### A.4 How each target resolves it

- **Web** (`sync-assets.sh`): curates the legacy tree into the pools above and
  writes `web-canvas/assets/manifest.json` (see §C.2). Games reference a pool
  path **without extension** (`backgrounds/castle`); `engine.resolveImage()`
  picks the best available.
- **Godot** (`sync-assets.sh`): MUST switch from "rsync the whole legacy tree"
  to "curate the same pools into `res://assets/`". Flat unique names make the
  1668-collision warning go away. `AssetLoader` keeps filename indexing and
  gains: (a) extension-preference on stem collisions (§C.3), (b)
  `pick_from_pool(prefix, {difficulty})` (§B).

### A.5 Migration plan (one-time)

1. Add `tools/migrate-assets.sh` (or a `migrate` mode in `sync-assets.sh`)
   that copies+renames legacy files into `assets/graphics/{backgrounds,animals,…}`
   per a mapping table kept in that script. Keep the table in the script so it
   is reviewable.
2. Point **both** `sync-assets.sh` scripts at the new pools only.
3. Rewrite each game's asset paths to pool paths (mechanical; do it per game
   as that game is touched for other policy items).
4. Delete the per-game curated dirs (`web-canvas/assets/puzzle/`, `/memory/`, …)
   — they become `backgrounds/`, `animals/`, etc.
5. Leave `assets/graphics/lib/` in the repo, drop it from the sync globs.

### A.6 First mapping decisions (do these first — they unblock §B/§H)

| New pool file | From |
| --- | --- |
| `backgrounds/*.jpg` (paintings) | `CPData/WipeData/tileset_1/*.jpg` **and** `CPData/PuzzleData/childsplay/*` — merge, dedupe |
| `backgrounds/aquarium_*.jpg` | `CPData/FishtankData/backgrounds/childsplay/*.jpg` |
| `animals/*` | `Memory_spData/tileset_2`, `IchangerData/images`, `FindsoundData/Images/level*` (dedupe; number collisions `frog_1..n`) |
| `objects/*` | remaining `FindsoundData` non-animals |
| `ui/card_front`,`ui/card_back`,`ui/sponge`,`ui/bubble` | `Memory_spData`, `WipeData/sponge.png`, `FishtankData/blub0.png` |
| `icons/<id>.png` | `SPData/themes/*/menuicons/*` (already renamed by `sync-assets.sh`) |
| `sprites/packid/*`,`sprites/billiards/*`,`sprites/aquarium/*` | `PackidData`, `BilliardData`, `FishtankData/*_0.png`/`*_1.png` |

### A.7 Every game MUST ship a graphics declaration

`docs/assets/<gameid>.assets.md`, from `docs/templates/ASSETS.template.md`:
logical name, pool path, formats present, native px, target box in world
units, aspect/fit, difficulty tag, licence/source. Updated in the same commit
as any art change. A game that only uses shared pools still files one (it just
lists the pools).

> **Play-test findings addressed:** "the puzzle folder has images but they
> weren't in the game, puzzle was using wipe's tileset"; "universal asset
> image location"; "universal animals folder, number the variants";
> "`…/WipeData/tileset_1` is an arbitrary long path"; "aquarium backgrounds
> labelled `aquarium_#`"; "difficulty by tag not folder".

---

## §B — Shared asset pools & no-repeat selection

### B.1 Rules

- **B.1.1** Any game that shows "a picture" (Puzzle, Wipe, Photo Album,
  Find It, quiz-picture, …) MUST draw it from a **shared pool** filtered by
  the level's difficulty tier — **never** a hard-coded per-level filename.
- **B.1.2** Selection is **random** within the eligible set.
- **B.1.3** Selection has **session no-repeat memory**: a picture is not
  reused until the eligible set is exhausted, then the set reshuffles.
- **B.1.4** Difficulty tiers map to the level index. Default: split the level
  count into thirds → `easy` / `med` / `hard`. Games state their exact map in
  `LEVELS`.

### B.2 Where the state lives

- **Web**: `web-canvas/js/util.js` gains `class Bag`:

  ```js
  // draw-without-replacement; auto-reshuffle on exhaustion
  const bag = new Bag(items);          // items: string[]
  bag.filter = (x) => x.endsWith('_easy') || !/_(easy|med|hard)/.test(x);
  bag.draw();                          // one item, never repeats until pool empty
  bag.drawN(3);                        // n distinct (refills mid-draw only if pool < n)
  ```

  A module-level `Map<poolKey, Bag>` keeps bags **per game session** (survives
  level restarts within one playthrough; a fresh game instance gets fresh
  bags). `poolKey = gameId + ':' + tier`.

- **Godot**: `GameContext` autoload gains
  `func draw_from_pool(pool: String, tags := {}, n := 1) -> Array` backed by a
  `Dictionary` of shuffled arrays keyed by `pool + JSON(tags)`. Same
  semantics. `AssetLoader.pool_entries(prefix, tags)` returns the candidate
  filenames.

### B.3 Algorithm (normative)

```
candidates = pool entries whose difficulty tag ∈ {tier, none}
key        = gameId + ':' + tier
if bag[key] is empty or missing:
    bag[key] = shuffle(candidates.copy())
result = []
repeat n times:
    if bag[key] is empty: bag[key] = shuffle(candidates.copy())
    result.push(bag[key].pop())
return result
```

### B.4 Concrete retargets

- **Puzzle**: `LEVELS[i].img` → `backgrounds` pool, tier by level. Levels 1–3
  `easy`, 4–6 `med`, 7–10 `hard` (see §H — Puzzle also needs more levels).
- **Wipe**: same `backgrounds` pool, **shared with Puzzle** (a session
  playing both should not see the same painting twice). Both call the same
  `Bag('backgrounds:'+tier)` — so make the poolKey `backgrounds:<tier>`
  (no `gameId` prefix) for this shared pool specifically.

> **Play-test findings addressed:** "Puzzle images are always the same for
> each level, gets boring"; "tier folders chosen at random by level, with
> temp permanence so pic1 isn't reused"; "wipe and puzzle sharing background
> images is a great idea".

---

## §C — Graphics format resolution

### C.1 The upgrade path

Art will be progressively replaced with **SVG**; originals (`png`/`jpg`) must
keep working untouched so a newer `castle.svg` dropped next to `castle.jpg`
just wins. Games therefore reference assets **without an extension**.

### C.2 Resolution order (normative)

```
svg → png → jpg → jpeg → webp
```

- **Web**: `sync-assets.sh` emits `web-canvas/assets/manifest.json`:
  `{ "backgrounds/castle": "backgrounds/castle.jpg", … }` (best ext per stem).
  `engine.resolveImage(base)` = manifest lookup; `loadImage`/`img` accept a
  base and resolve internally. A base that already has an extension is used
  as-is (escape hatch).
- **Godot**: reorder `AssetLoader.IMAGE_EXTS` to
  `["svg","png","jpg","jpeg","webp"]` **and** change `_register` so that on a
  stem collision it keeps the **higher-priority extension**, not merely the
  first seen. `get_texture("backgrounds/castle")` (stem, no ext) already
  resolves via stem-indexing; make it return the best ext.

### C.3 SVG caveats (Godot 4)

SVG imports rasterise at import time. A full-screen SVG imported at 1× looks
soft when scaled up. Therefore:

- **C.3.1** SVGs above ~256 px on a side MUST set an import `scale` (2–4×) in
  their `.import` (or the project default `editor/import/svg` scale).
- **C.3.2** **Large full-scene backgrounds SHOULD stay raster** (PNG/JPG).
  SVG is for icons, line art, cards, game pieces, particles — things that
  scale and recolour.

### C.4 Theme-overlay directory (layered, optional)

The per-asset ext fallback is **always on** and is the baseline. On top of it,
the theme/style selector (§D) MAY point the loader at an overlay dir checked
**before** the base pool:

```
assets/graphics/themes/<themeName>/<pool>/<name>.<ext>
```

Recommendation: ship ext-fallback **now**; add the overlay dir only when the
first alternate art set actually exists. Do not build the overlay machinery
speculatively.

> **Play-test findings addressed:** "everything svg with png/jpg fallback so
> originals can be replaced or left in place"; "or a theme selector that
> switches to newer svg with fallback" — answer: both, layered, ext-fallback
> first.

---

## §D — Theme system — light/dark is mandatory

### D.1 Rules

- **D.1.1** The menu has a **light/dark toggle**. Choice is persisted
  (`localStorage` / Godot `user://settings.cfg`) and defaults to the OS
  preference where detectable (`prefers-color-scheme`; Godot: default dark,
  remember).
- **D.1.2** **Every** game MUST render legibly in **both** modes. A game that
  only looks right in dark is non-compliant.
- **D.1.3** Game code MUST NOT contain colour literals. Colours come from the
  **named palette**. (Literals are allowed **only** inside `theme.js` /
  the palette resources, and inside a game's own `STYLE_THEMES` block.)

### D.2 Where the palette lives

- **Web**: `web-canvas/js/theme.js` exports a live `theme` object and
  `LIGHT` / `DARK` role maps. `setTheme('light'|'dark')` swaps `theme.*` in
  place and stamps `document.documentElement.dataset.theme` + mirrors roles to
  CSS custom properties on `:root`. Games `import { theme } from '../theme.js'`
  and read `theme.bg`, `theme.text`, … each frame (cheap; it's a plain
  object).
- **Godot**: `GameContext` gains `var palette: Dictionary` (role → `Color`),
  swapped on toggle, with `signal theme_changed`. Ship `res://themes/palette_light.tres`
  and `palette_dark.tres`. Games use a one-line helper `_c("bg")` →
  `GameContext.palette["bg"]` and connect `theme_changed` to `queue_redraw`.

### D.3 Required roles

Every palette (global light, global dark, and every style-theme mode) MUST
define all of:

| Role | Use |
| --- | --- |
| `bg` | page / world background |
| `surface` | cards, tiles, panels |
| `surface_alt` | raised/active surface, alt rows |
| `text` | primary text |
| `text_muted` | secondary text, hints |
| `accent` | primary action, focus ring, selected |
| `accent_press` | pressed action |
| `good` | correct / success |
| `bad` | wrong / danger |
| `warn` | caution, "tough" pieces |
| `line` | borders, grid lines, wires |
| `overlay_scrim` | dim behind win/lose overlays (has alpha) |
| `p1`, `p2` | player 1 / player 2 (multiplayer, §K) |

### D.4 Contrast rule (normative — verify the deltas)

- **D.4.1** Body text vs its immediate background: **≥ 4.5:1** (WCAG AA).
- **D.4.2** Large text (≥ 24 px bold or ≥ 19 px), icons, and **essential game
  graphics** (a piece vs its board, a wire vs the felt) vs their immediate
  background: **≥ 3:1**.
- **D.4.3** Adjacent interactive **states** (tile idle/hover/press; player
  piece vs empty cell) MUST differ by **≥ 3:1** in contrast **or ≥ 20 in
  CIE L\***, **and** MUST also differ by a non-colour cue (shape, size,
  elevation, glyph) — colour-blind players and 1-px borders don't count.
- **D.4.4** Provide `contrastRatio(hexA, hexB)` in `util.js` (and a Godot
  equivalent) and a dev-only assertion that walks each palette pairing.

### D.5 Per-game style themes (optional)

A game MAY export extra visual styles without breaking the light/dark
contract:

```js
// pong.js
export const STYLE_THEMES = {
  atari:    { light: {...roles}, dark: {...roles} },   // B/W
  neon:     { light: {...roles}, dark: {...roles} },   // 90s hot/neon
  y2k:      { light: {...roles}, dark: {...roles} },
  material: { light: {...roles}, dark: {...roles} },   // default
};
```

- **D.5.1** Every style MUST define **both** `light` and `dark` and both MUST
  pass §D.4.
- **D.5.2** Missing roles inherit the global palette.
- **D.5.3** The style is chosen on the game's **start/level screen**, persisted
  per game id. The global light/dark toggle still applies on top.

### D.6 Games that currently hard-code colour

**All of them**, plus `menu.js`, `util.js` (`drawButton`, `Overlay`),
`css/style.css` (`--ground`, `--accent`). Migration = replace every literal
with a role. Highest-impact first: `util.js`/`Overlay` (shared by all),
`menu.js`, then FourRow (contrast bug, §G), then the rest as touched.

> **Play-test findings addressed:** "light or dark mode selector on the menu";
> "each game needs light and dark, some need a second asset set"; "check the
> delta difference of colours for legibility"; "Four in a Row blue on dark
> blue/grey was rough on the eyes"; "Pong retro/90s/2000s/modern themes, each
> with light and dark".

---

## §E — Audio lifecycle & text-to-speech

### E.1 No sound may outlive its scene (this is a **bug fix**, mandatory)

Today: web `playSound` clones an `<audio>` node and never tracks it; Godot
`AssetLoader` plays one-shots through a **pool on the autoload** and music
through a player **on the autoload** — both survive `change_scene_to_file`.
Result: animal sounds / BGM keep playing on the menu after you quit.

- **E.1.1 Web** — `engine.js` owns an `AudioManager`:
  - `playSound`/`playLoop` register every live `HTMLAudioElement` in a `Set`.
  - One-shots self-deregister on `ended`.
  - `Game.setState()` and `Scene.exit()` call `audio.stopAll()` →
    `pause(); currentTime = 0;` every registered node, clear the set,
    `window.speechSynthesis?.cancel()`.
  - Loops return a handle; the manager force-stops them on exit regardless of
    whether the scene kept the handle.
- **E.1.2 Godot** — `AssetLoader.stop_all()` stops every pooled SFX player +
  `_music_player` + `DisplayServer.tts_stop()`. Called from
  `MinigameBase._exit_tree()` **and** from `MainMenu._ready()` (belt and
  braces). In-scene `AudioStreamPlayer`s are freed with the scene but SHOULD
  also be `.stop()`-ed in `_exit_tree` for a clean cut.
- **E.1.3** A game MUST NOT start audio from a `setTimeout`/`await`/timer
  callback that can fire after exit without first checking the scene is still
  current.

### E.2 Every game MUST have a "hear the instructions" button

- **E.2.1** In the HUD centre cluster (§G), immediately right of the single
  instruction line: a **🔊** button, min 44×44 (§I).
- **E.2.2** It speaks the **same** text that is displayed, via a shared helper
  `speak(text, langHint?)` — `web-canvas/js/tts.js` (`speechSynthesis`) /
  `GameContext.speak()` (`DisplayServer.tts_*`). Same path Flashcards already
  uses.
- **E.2.3** The instruction is also spoken **once automatically** on level
  start, unless the player has muted voice.
- **E.2.4** Silent-degrade: if `getVoices()` / `tts_get_voices()` is empty,
  **hide** the button (don't show a dead control) and skip auto-speak. The
  game stays fully playable.

### E.3 Spoken-labels toggle (generalised from Aquarium)

- A game with named entities MAY expose a persisted **"say the names"** toggle:
  - **off** — sound effect only (age 2–3).
  - **on** — also `speak(name)` on interaction (age 3+).
- Applies to: Aquarium (fish/shark species), Find Sound, Flashcards, Electro,
  Memory (pictures). Toggle lives on the game's start screen or a small
  in-HUD control; default **off**.

### E.4 Flashcards recorded packs — recommendation

**Keep TTS as the baseline on both targets; treat the recorded `de/nl/fr/es`
`.ogg` packs as an optional enhancement.**

- English already uses TTS. Make de/nl/fr/es default to TTS too.
- If a recorded clip exists it is used (higher quality); if not, TTS in that
  language; if no voice at all, the card still shows picture + word.
- Do **not** add new recorded languages — new languages get TTS only.
- Rationale: `speechSynthesis` (browser) and `speechd`/`espeak` (Linux `.deb`,
  works on an old netbook) cover the need; the packs are 694 KB and already
  vendored, so keeping them costs nothing, but requiring them would block
  every new language.

### E.5 Audio buses / mute

Three logical buses stay: **sfx / voice / music** (Godot already has them; web
should tag `playSound` calls with a `channel`). The menu exposes **mute
music**, **mute sfx**, **mute voice** independently (Godot menu currently has
one master mute; web has none — add it, §F).

> **Play-test findings addressed:** "all games keep playing audio until the
> file ends even after you quit — animal sounds / BGM still going on the menu";
> "most 2–6 year-olds can't read, add a TTS speak button next to instructions
> for all games"; "Aquarium: a second audio mode that reads the fish names —
> mode 1 for 2–3 y/o, mode 2 for 3+"; "Flashcards: do we need the audio files
> or can both targets use a TTS engine even on an old netbook".

---

## §F — Game-selection menu

### F.1 Tile geometry

- **F.1.1** Tiles are **1:1 squares** (the icons are 1:1 — the current ~5:4
  rectangles waste space around every icon).
- **F.1.2** The icon fills the tile minus a **uniform inner margin** of
  `clamp(tileEdge * 0.10, 12, 28)` world units.
- **F.1.3** The label is a bottom band **inside** the tile (over a subtle
  gradient scrim) or on a strip directly below; it MUST NOT eat into the icon
  margin such that the icon shrinks below F.1.4.
- **F.1.4** Rendered icon edge **≥ 96** world units. If the grid can't give
  every tile ≥ ~120 units, **reduce columns / paginate** (F.3) — never shrink
  past this.

### F.2 Tile background & states (contrast, not borders)

- **F.2.1** Tile `surface` vs page `bg`: **≥ 3:1** (§D.4).
- **F.2.2** State deltas, each ≥ 3:1 contrast **or** ≥ 20 L\* from the
  previous, **and** a non-colour cue:
  - idle → `surface`
  - hover/focus → `surface_alt` (lighter/darker) **+ 3 px `accent` ring**
  - pressed → `accent` fill **+ inset + 4 px scale-down**
  - selected → `accent` ring **+ a corner check glyph**
- **F.2.3** Do **not** rely on the ring alone or on hue alone. Colour-blind
  players must be able to tell tiles and states apart by lightness/shape.

### F.3 Responsive grid

- **F.3.1** `cols = clamp(floor(VIEW_W / TARGET_TILE), 2, 5)` with
  `TARGET_TILE ≈ 260` world units.
- **F.3.2** If the resulting rows overflow the world height at the F.1.4
  minimum size, **paginate**: page dots + swipe / arrow-key / on-screen
  chevrons. Do not shrink tiles below the minimum.
- **F.3.3** Portrait: expect 2–3 columns and 2+ pages. That's fine.
- **F.3.4** **Bundle families behind one tile** (the Memory sub-menu pattern)
  to cut tile count: Memory (already), and — when they land — a single
  **Quiz** tile opening a deck picker. Consider grouping the two-player-
  capable board games or the word games similarly if the grid stays crowded.

### F.4 Menu chrome

- **F.4.1** Top-right cluster: **light/dark toggle** (sun/moon), **fullscreen**
  (exists), **mute** (music/sfx/voice — a small popover). Consistent placement
  on web and Godot.
- **F.4.2** The menu is a `Scene`/`Control` like a game and re-lays-out on
  `resize()`. It is **not** `body.in-game` — it uses the full world, no HUD
  strip.
- **F.4.3** Bigger title area is fine; the game grid is the priority — icons
  and tiles should feel large and tappable on a phone.

> **Play-test findings addressed:** "buttons are large rectangles but icons
> are 1:1 squares → blank space; 10–30 px margin would let buttons be bigger
> and nicer"; "icon BG colour delta too weak, colour-blind users can't tell
> tiles apart and shouldn't rely on the border"; "icons could be bigger";
> "make the selection page dynamic — bigger buttons + paginate on a phone, or
> bundle games like Memory"; "light/dark selector on the menu".

---

## §G — In-game HUD contract

### G.1 One HUD height, everywhere

- **G.1.1** `HUD_H = 64` world units for **every** game. (Kill the current
  56/64/`HUD_H` split.) The band is `y ∈ [0, 64)`.
- **G.1.2** **No gameplay drawing with `y < HUD_H`.** No exceptions.

### G.2 One row, three clusters

| Cluster | x anchor | Content |
| --- | --- | --- |
| left | 24 → | `Level n/N` · score / progress (`3/8 wired`, `Wall 2/6`) |
| centre | centred | **exactly one** instruction line + the 🔊 button (§E.2) right of it |
| right | → VIEW_W−24 | lives / status / timer (`● ● ○`, `your turn`) |

- **G.2.1** A game MUST NOT draw a **second** text line in the band. Numbers
  currently prints a "study / peek / tap number N" line **and** the
  level/score line — fold the state hint into the single centre line.
- **G.2.2** The centre instruction is the string §E.2 speaks.
- **G.2.3** HUD text vs the HUD background MUST pass §D.4.1 (4.5:1).

### G.3 Relationship to the HTML chrome strip

Two distinct bands, both off-limits for gameplay:

1. **HTML `--hud-h` strip** (52 px + safe-area, web only): Back button,
   activity name, fullscreen. Outside the canvas. `body.in-game` reserves it.
2. **In-canvas `HUD_H` band** (64 world units, both targets): the §G.2 row.
   Inside the world, below strip 1.

Document both in each game's header comment so nobody draws a score at `y=10`.

> **Play-test findings addressed:** "Numbers — the top instructions overlap
> the level score section"; "Four in a Row assets/background need enough
> delta to be seen" (colour → §D; layout → here).

---

## §H — Difficulty & levels

### H.1 Rules

- **H.1.1** Every game that is not a free-play toy (**exempt: Aquarium,
  Flashcards, Photo Album**) MUST have **≥ 5 levels** defined in a readable
  `LEVELS` table — an array of plain param objects a non-coder can tune:

  ```js
  const LEVELS = [
    { tier: 'easy', speed: 90,  spawn: 1.9, lives: 3 },
    …
  ];
  ```

- **H.1.2** Every difficulty knob MUST ramp **monotonically** across the
  table (more items / faster / higher threshold / smaller target / smaller
  sponge). No "level 3 easier than level 2".
- **H.1.3 House style — no punishing failure.** No lives-to-zero game-over
  that ejects the player. Allowed patterns: infinite retry (Simon), lose a
  life then **replay the same level** (Block Breaker's "lost the wall"),
  wrong answer costs **time/hint** not progress (Numbers' peek). A level ends
  only by success or the player choosing Menu.
- **H.1.4** `LEVELS` maps to difficulty tiers for §B (default: even thirds
  easy/med/hard; state the exact rows).

### H.2 Specific retunes (from play-test)

| Game | Change |
| --- | --- |
| **Wipe** | Expand to **10–12 levels**; `target` ramps ~`0.65 → 0.99` roughly linear; `sponge` `54 → 26`. Current 6 levels at 0.55–0.84 are too easy and too few. |
| **Simon** | Expand to **8–10 levels** (sequence length 2 → 11). |
| **Falling Letter** | Add a real `LEVELS` table (≥ 6 tiers: `spawnInterval`, `fallSpeed`, `lives`). Keep the small score-based ramp **within** a tier. Starting speed on level 1 MUST be gentle enough for a 4-year-old on a phone. |
| **Puzzle** | Add levels (target ~10) so §B has room: 1–3 grid/`easy`, 4–7 free-cut/`med`, 8–10 free-cut many-piece/`hard`, images from the shared `backgrounds` pool. |

> **Play-test findings addressed:** "Falling letter has no levels and falls
> too fast after a few letters on a phone"; "Wipe goal percentages too low —
> L1 ~70–75 %, L6 ~90 %, or more levels 65 % → 99 %"; "Simon — make more
> levels"; "Puzzle — same images every level, gets boring" (levels + §B).

---

## §I — Touch targets & text input

### I.1 Minimum interactive size

- **I.1.1** Any tappable target: **≥ 44×44** CSS px. Express in game code as
  `MIN_TAP = 44` world units (≥ 44 CSS at scale ≥ 1; at the portrait
  down-scale it is still close — if a game's world scale drops below ~0.8,
  bump primary targets).
- **I.1.2** Primary / one-per-screen targets (Start, Next, a big multiple-
  choice answer, a colour pad): **≥ 72**.
- **I.1.3** The **visual** mark MAY be smaller than the **hit box**. Hit box =
  `max(MIN_TAP, visualSize + 24)`.

### I.2 Draggable connectors / small nodes

- **I.2.1** Hit radius ≥ `MIN_TAP/2` regardless of dot size.
- **I.2.2** On drag-release, **snap to the nearest eligible node within
  `SNAP_TOL ≈ 60`** world units. Do not require landing on the pixel.
- **I.2.3** Draw a **fat halo / highlight** under the finger and on the
  nearest snap candidate while dragging.
- **Electro** violates all three (`NODE_R = 13`, hit ≈ 29, no snap). Fix:
  hit radius ≥ 44, snap-to-nearest, halo.

### I.3 Text entry — dual keyboard (normative)

Any game needing letters (**Falling Letter**, **Word Maker**, future
spellers):

- **I.3.1 On a touch device**, the **primary** input is the **OS keyboard**:
  a hidden `<input>` focused on demand (web) / `DisplayServer.virtual_keyboard_show`
  (Godot). Big, familiar, autocorrect-off.
- **I.3.2** The **in-canvas keyboard stays available** as the **accessibility
  path** (switch access, no-hands, kiosk with no OS keyboard) — a visible
  "⌨ keyboard" toggle switches between the two.
- **I.3.3 On non-touch**, physical keyboard is primary; in-canvas is the
  fallback.
- **I.3.4** Any in-canvas keyboard: keys ≥ 44, laid out to fit the **portrait
  width**, QWERTY (not alphabetical).

### I.4 Portrait

Every interactive element MUST be reachable and ≥ its minimum size in the
**portrait fit** (world fixed 16:9, scaled to width). Test every game at
`393×852` before merge.

> **Play-test findings addressed:** "Electro tiny dots need pixel-exact hits —
> add margin"; "Falling Letter on-screen keyboard is tiny on a phone — offer
> the device's native keyboard, keep an in-canvas one for accessibility";
> "games stuck at computer screen ratios, can't fill portrait".

---

## §J — Content-driven games

### J.1 Rules

- **J.1.1** A game whose content is a **list** (match pairs, word lists,
  letter sets, quiz questions) MUST read it from a **data file**, not an
  inline array > ~8 entries.
- **J.1.2** Data files live in **`assets/data/`** and are synced to both
  targets like graphics.

### J.2 Formats

| Shape | Format |
| --- | --- |
| flat list / simple pairs | **`.txt`** — one item per line, `#` comments, ` \| `-separated fields, blank lines ignored |
| nested (quiz decks, level tables with many knobs) | **`.json`** |

### J.3 Examples

`assets/data/electro.txt` — pairs (left label ` | ` asset base; resolved via §C):

```
# animal → its name.  Both sides same asset unless a 3rd/4th field is given.
sheep   | animals/sheep
frog    | animals/frog_1
dog     | animals/dog | Puppy | animals/puppy      # asymmetric pair
```

`assets/data/words-en.txt` — one word per line (Word Maker).
`assets/data/wordmaker.txt` — `letter | target` per line.
`assets/data/quiz-animals.json` — `[{ q, img, choices:[…], answer }]`.

### J.4 Loader

Shared `loadData(name)` on each target returns parsed rows (array of arrays
for `.txt`, parsed object for `.json`). Games call it in `enter()`.

> **Play-test findings addressed:** "make Electro pull matches from a list
> MD/txt file (`sheep, sheep.jpg/png/svg`) so it's easy to add more".

---

## §K — Local multiplayer

- **K.1** Turn-based games — **Four in a Row**, **Tic Tac Toe** (and
  optionally Memory / Sound Memory) — SHOULD offer **local "Pass & Play"
  2-player**. (Pong is real-time and already effectively 2-player-capable via
  a second paddle — that's a separate toggle, not this one.)
- **K.2** Toggle on the **start / level screen**: `1 Player` / `2 Players`.
- **K.3** In 2-player: **AI disabled**; players use the `p1` / `p2` palette
  roles; a persistent turn banner names whose turn ("Red's turn" /
  "Blue's turn") and the 🔊 button reads it; the win overlay names the winner.
- **K.4** No networking — same device, one after the other.

> **Play-test findings addressed:** "Four in a Row — interested in a 2-player
> mode since it's turn-based."

---

## §L — Per-game migration checklist

Legend: **A** layout/naming · **B** pool+no-repeat · **C** format resolve ·
**D** palette/contrast · **E** audio-stop + TTS button · **F** menu (n/a per
game) · **G** HUD (`HUD_H=64`, one row) · **H** levels/ramp · **I** touch/hit ·
**J** data file · **K** multiplayer.

| Game | Must change |
| --- | --- |
| **menu** (`menu.js` / `MainMenu.*`) | D (all literals → palette), F (square tiles, margins, state contrast, paginate, light/dark + mute chrome) |
| **memory** / **soundmemory** / **memory-menu** | D, E (audio-stop, TTS button), G (HUD row), A/C (card art → `ui/` + `animals/` pools), E.3 spoken-labels (pictures) |
| **fallingletter** | **H** (add LEVELS table, gentle L1), **I.3** (OS keyboard primary on touch, keep in-canvas as a11y), D, E (stop + TTS), G |
| **findsound** | D, E (stop + TTS + spoken-labels), G, **J** (sound/label list → data file), A/C (pool paths) |
| **puzzle** | **B** (shared `backgrounds` pool, no-repeat), **H** (~10 levels, tiers), D, E, G, A/C |
| **findit** | **B** (pool), D (piece vs board contrast), E, G (`HUD 64` already), A/C |
| **aquarium** | E (**stop ambient + fish sfx on exit** — main offender), **E.3** (say-the-names mode 1/2), D, A/C (`sprites/aquarium/`, `backgrounds/aquarium_*`). Toy → exempt from H. |
| **pong** | D, **D.5** (Atari/neon/y2k/material style themes, each light+dark), E, G, K (2-player paddle toggle) |
| **fourrow** | **D** (blue-on-blue contrast — primary offender), G, **K** (Pass & Play), E (stop + TTS), A/C |
| **flashcards** | **E.4** (TTS baseline for de/nl/fr/es, packs optional), E (stop + TTS button), D, G. Toy → exempt from H. |
| **blockbreaker** | D, E (stop + TTS), G, C. (H already good — 6 walls, lose-wall replay is the model pattern.) |
| **simon** | **H** (8–10 levels), D, E (stop + TTS), G |
| **electro** | **I.2** (hit radius ≥44, snap-to-nearest, finger halo — primary offender), **J** (pairs → `assets/data/electro.txt`), D, E (stop + TTS + spoken-labels), G, B (animal art pool) |
| **tictactoe** | **K** (Pass & Play), D, E (stop + TTS), G |
| **wipe** | **H** (10–12 levels, target 0.65→0.99, sponge 54→26), **B** (shared `backgrounds` pool with Puzzle, no-repeat), D, E, G, A/C |
| **ichanger** | **B** (animal pool + no-repeat), D, E (stop + TTS + spoken-labels), G, H (has 4 levels×3 rounds — bump to ≥5 levels or document as compliant) |
| **numbers** | **G** (fold the study/peek hint into the single centre line — overlap bug), D, E (stop + TTS), H (has 6 — ok) |
| **synonyms** (Word Maker) | **I.3** (OS keyboard primary on touch), **J** (`words-en.txt` + `wordmaker.txt`), D, E (stop + TTS), G, H (5 → ≥5 ok, verify ramp) |
| **packid** | D, E (stop + TTS), G (`HUD_H` rename from `HUD_H=64` — already 64, just the name), A/C (`sprites/packid/`) |
| **billiards** | D, E (stop + TTS), G, A/C (`sprites/billiards/`). (Play-tested clean otherwise.) |

New games (Photo Album, Spin the Bottle, Quiz engine + decks) build to this
policy from the start; Quiz decks are content files (§J) behind one bundled
menu tile (§F.3.4).

---

_Owner: whoever touches a game next implements the rows above for that game in
the same PR. Cross-cutting infra (palette module, AudioManager, `Bag`,
`loadData`, manifest, menu rework) lands first as its own change._
