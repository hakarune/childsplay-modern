# Childsplay-Modern

A modern re-implementation of **[Childsplay](https://codeberg.org/childsplay/childsplay)**,
the classic suite of small educational games for children **ages 2–7**
(letter and number recognition, memory, listening skills, hand–eye
coordination). The original is a Python/Pygame application; Childsplay-Modern
rebuilds the core activities as a single **Godot 4** project, exported to
every platform from one codebase and one asset tree.

**20 activities** (including **Quizzes**, a five-deck multiple-choice
picker), a **light / dark theme**, **spoken instructions baked in** (no
text-to-speech engine required), **per-channel sound** (music / effects /
voice), and **local 2-player** for the board games. Everything runs
offline.

**Status:** every classic Childsplay activity, nine extras and the Quiz
suite are done at feature parity across platforms. `v0.5.0` is released
(browser + `.deb` + Windows `.zip`); `main` carries a batch of
post-release playtest fixes, new activity-icon art and a headless
scene-load smoke run in CI. The one open item is a visual-QA pass on real
devices — everything is verified headless, not yet eyeballed. Full detail
in [`docs/GAME-STATUS.md`](docs/GAME-STATUS.md).

* **Play in a browser:** <https://hakarune.github.io/childsplay-modern>
* **Install on Linux:** grab the `.deb` from
  [**Releases**](https://github.com/hakarune/childsplay-modern/releases)

[![CI](https://github.com/hakarune/childsplay-modern/actions/workflows/ci.yml/badge.svg)](https://github.com/hakarune/childsplay-modern/actions/workflows/ci.yml)
[![Release](https://github.com/hakarune/childsplay-modern/actions/workflows/release.yml/badge.svg)](https://github.com/hakarune/childsplay-modern/actions/workflows/release.yml)
[![Pages deploy](https://github.com/hakarune/childsplay-modern/actions/workflows/pages.yml/badge.svg)](https://github.com/hakarune/childsplay-modern/actions/workflows/pages.yml)

---

## Architecture

One Godot 4 project (`godot/`, GL Compatibility renderer) exports to every
target. There is no separate web codebase and no asset-copy step:

| Target | How it's built | Distribution |
| --- | --- | --- |
| **Linux** | `godot --export-release "Linux"` | `.deb` package (GitHub Releases) |
| **Windows** | `godot --export-release "Windows Desktop"` (cross-exported from Linux) | `.zip` containing the `.exe` (GitHub Releases) |
| **Web** | `godot --export-release "Web"` — single-threaded, `progressive_web_app/enabled` | Static files (GitHub Pages), installable/offline as a PWA |

```
        godot/assets/   (the ONLY art/audio/data tree — res://assets/...)
                    │
     Godot's exporter bundles the whole tree into every build
                    │
        ┌───────────┼────────────────┐
        ▼           ▼                ▼
    Linux .deb   Windows .exe    Web index.pck/.wasm/.js
```

`godot/assets/` is loaded from *and* shipped from the same place — see
[**docs/ASSETS.md**](docs/ASSETS.md) for the full layout and naming rules,
and read it before moving or adding any art or audio. Until 2026-09 the web
target was a second, hand-written HTML5/canvas codebase (`web-canvas/`)
with its own asset copy; it's been retired in favour of exporting this
same project to Web (see `docs/Design-Policy.md`'s 2026-09-01 note for
why, and what changed).

---

## Install

### Play in a browser (nothing to install)

Open <https://hakarune.github.io/childsplay-modern>. It works on phones,
tablets, Chromebooks and desktops, and can be "Added to Home screen" /
installed from the browser menu for a full-screen, offline-capable app.

### Linux desktop (`.deb`)

Download the latest `childsplay-modern_<version>_amd64.deb` from
[**Releases**](https://github.com/hakarune/childsplay-modern/releases), then:

```sh
sudo apt install ./childsplay-modern_0.5.0_amd64.deb
#   or:  sudo dpkg -i childsplay-modern_0.5.0_amd64.deb && sudo apt -f install
```

It's an x86_64 build with an embedded data pack (~130 MB installed).
Dependencies (all standard): `libc6 libgl1 libx11-6 libxcursor1
libxinerama1 libxrandr2 libxi6`. On Ubuntu 24.04+ the optional
`libasound2` recommend is named `libasound2t64` — it's only a recommend, so
the install still succeeds.

Launch it from your desktop menu ("Childsplay Modern") or run
`childsplay-modern`. Remove with `sudo apt remove childsplay-modern`.

---

## Repository layout

```
childsplay-modern/
├── godot/                      Godot 4 project — the only codebase, every platform
│   ├── project.godot             1280×720, canvas_items/keep stretch, Compatibility
│   ├── export_presets.cfg        Linux / Windows Desktop / Web (PWA) — committed, shared by CI
│   ├── default_bus_layout.tres   Master / Music / SFX / Voice audio buses
│   ├── assets/                   THE ONLY ART/AUDIO/DATA TREE — res://assets/..., see docs/ASSETS.md
│   │   ├── graphics/pools/         Flat, purpose-named art the games read from
│   │   │   ├── backgrounds/          kid scene art + aquarium_1..6 (`_tier` filename tag)
│   │   │   ├── animals/              plain-named cutouts (cat, cow, dog, bird, …)
│   │   │   ├── ui/                   card faces, sponge, bubble, soundbut
│   │   │   ├── vehicles/ instruments/ sounds/  Find the sound level pools
│   │   │   ├── icons/                one <game-id>.png per menu tile
│   │   │   └── sprites/<game>/       packid / billiards / aquarium sprite sheets
│   │   ├── audio/
│   │   │   ├── sfx/                 Flat effect clips (referenced by bare filename)
│   │   │   ├── voice/               Baked spoken lines: v_<slug>.ogg
│   │   │   ├── soundmemory/         Shared Find the sound / Sound Memory clip set: <id>.ogg
│   │   │   └── flashcards/          Recorded animal names, <word>_<lang>.ogg (de/nl/fr/es)
│   │   ├── data/                    Editable game content (see "Customising content")
│   │   │   ├── electro.json           ImageLink picture↔name pairs
│   │   │   ├── wordlist.json          StartsWith dictionary (~1200 words)
│   │   │   └── quiz/*.json            One deck per Quiz (general/picture/math/words/sayings)
│   │   └── fonts/                   DejaVu Sans Condensed (UI font)
│   ├── scenes/                   MainMenu.tscn, MemoryMenu.tscn, QuizMenu.tscn, games/*.tscn
│   ├── scripts/                  AssetLoader + GameContext (autoloads), MenuTile, menus, games/*
│   └── tests/                    smoke.sh + scene_smoke.gd — headless load every scene
├── assets/                     Repo-root — EDITABLE ORIGINALS ONLY, never loaded/shipped
│   ├── designing/                 .afdesign / layered exports / working SVGs (sync between machines)
│   ├── activity_dev/              Scratch art for WIP activities, not yet promoted to a pool
│   └── audio/human/               Raw human recordings — a gen-voice.sh input, not loaded by the game
├── tools/                      Content generators (read godot/assets/, write back into it)
│   ├── gen-voice.sh              Bake spoken lines → godot/assets/audio/voice/*.ogg (human → google/piper → espeak-ng)
│   ├── gen-electro-data.sh       Rebuild godot/assets/data/electro.json from the animals pool
│   ├── gen-wordlist.py           Rebuild godot/assets/data/wordlist.json
│   ├── ci_setup_godot.sh         Download Godot + export templates in CI
│   └── package_deb.sh            Wrap an exported Linux binary into a .deb
├── docs/
│   ├── ASSETS.md                 Where assets live and the naming rules (source of truth)
│   ├── Design-Policy.md          The cross-cutting rules every game follows (§A–§L)
│   ├── GAME-STATUS.md            Per-activity conversion tracker + changelog
│   ├── assets/<id>.assets.md     Per-game graphics declaration (§A.7)
│   └── templates/ASSETS.template.md
├── .github/workflows/
│   ├── ci.yml                   Headless smoke on push/PR, then a package job (deb/exe/web artifacts)
│   ├── pages.yml                Exports the Web preset and deploys it to GitHub Pages on push to main
│   └── release.yml              Build .deb + Windows .zip + Web zip + SHA256SUMS on a v*.*.* tag
├── legacy-sources/             Upstream checkout for asset extraction (git-ignored)
├── LICENSE                     GPL-3.0
└── README.md
```

---

## Features

* **Light / dark theme** — the **Theme** button in the main-menu top bar.
  Every screen repaints from a shared 20-role palette
  (`GameContext.PALETTE_*`); the choice is remembered. Contrast is
  WCAG-checked in both themes.
* **Spoken instructions, baked in** — short lines ("drag a wire from each
  picture to its name", number and animal names, …) are pre-rendered to
  `godot/assets/audio/voice/v_<slug>.ogg` and ship in every export, so
  pre-readers get audio help even with **no TTS engine installed**. Clips
  are sourced best-first: an original human recording (the GPL en_GB
  letters + digits), else a synthesiser (`TTS=google` natural / `piper`
  offline-neural / `espeak-ng` fallback). Each
  game's HUD has a 🔊 button that re-speaks the current prompt; live
  OS/browser TTS is used only as a fallback. Games with named
  pictures (Memory Games, Find the sound, ImageLink, What changed,
  Aquarium) have a **"say the names"** toggle — off by default, on speaks
  the picture on interaction.
* **Per-channel sound** — Music / Effects / Voice, each independently
  muteable via the **Sound** button's three-way panel. The setting
  persists (`user://settings.cfg`).
* **No-repeat asset pools** — Puzzles / Memory Games / Picture Wipe /
  Picture Find draw pictures from shared "bags" so the same image doesn't
  recur within a session; Puzzles and Picture Wipe share a
  **per-difficulty-tier** scene-art bag (the tier is an
  `_easy/_med/_hard` tag on the filename).
* **Drop-in SVG art** — every image is referenced without an extension, so
  a newer `.svg` next to a `.png` / `.jpg` wins automatically
  (`svg → png → jpg → jpeg → webp`). A dormant **Art** menu toggle
  switches to a `godot/assets/graphics/themes/<style>/` overlay set once
  one exists — the button only appears when overlay art is present.
* **Typing games** — Falling Letters and StartsWith take a physical
  keyboard, the device's on-screen keyboard, **or** an in-canvas QWERTY
  kept as the accessibility path; a `⌨` button switches between the last
  two.
* **Responsive** — a fixed 1280×720 world is aspect-fit into any screen;
  portrait phones play fit-to-width with the game ratio preserved.
* **Local 2-player** — Connect Four and Tic-Tac-Toe ask **1 Player /
  2 Players** (Pass & Play) up front, before the first move.

---

## Customising content

Game content lives in plain files under `godot/assets/`. Edit, regenerate
if there's a helper, then commit — there is no sync/copy step. All
generators need only `bash` + `python3` unless noted.

### ImageLink (`electro`) — picture ↔ name matches

`godot/assets/data/electro.json` — one `{ "img", "say" }` per line:

```json
{ "pairs": [
  { "img": "cat", "say": "cat" },
  { "img": "dog", "say": "dog" }
] }
```

* `img` is a filename **stem** in `godot/assets/graphics/pools/animals/`
  (no extension).
* `say` is the printed + spoken word.
* To add a match: drop the picture in
  `godot/assets/graphics/pools/animals/`, add a line here, and — so it's
  spoken without live TTS — add the word to the `PHRASES` list in
  `tools/gen-voice.sh` and re-bake (below).
* `tools/gen-electro-data.sh` rebuilds this file from **every** picture in
  the animals pool (turns `_`/`-` into spaces). Run it after adding art if
  you want all of it in play; it **overwrites** hand edits.

The game falls back to a built-in list if the file is missing.

### StartsWith (`synonyms`) — the dictionary

The ~1200-word kid dictionary is `godot/assets/data/wordlist.json`. Don't
edit the JSON directly — edit the `WORDS` blob in
**`tools/gen-wordlist.py`** (any whitespace/newlines are fine) and run it:

```sh
python3 tools/gen-wordlist.py      # -> godot/assets/data/wordlist.json
```

Rules enforced by the generator: lowercased, `a–z` only, length 2–8,
de-duplicated, sorted. Keep it kid-safe and avoid proper nouns. The
per-level starting letters and word targets are in `LEVELS` in
`godot/scripts/games/WordMaker.gd`.

### Find the sound (`findsound`) — levels

A level is a graphics pool folder (`animals` / `vehicles` / `instruments`
/ `sounds`); its cards are the pictures in that pool that have a matching
`godot/assets/audio/soundmemory/<stem>.ogg`. Picture and clip pair by
identical stem, and the stem (`-` → space) is the spoken word. To add a
card, drop `godot/assets/graphics/pools/<pool>/<stem>.png` +
`godot/assets/audio/soundmemory/<stem>.ogg` — no data file, no label map.
To add a level, make a new pool folder and add its name to the short level
array in `FindSound.gd`.

### Quizzes (`quiz`) — decks

One file per deck in `godot/assets/data/quiz/` (`general`, `picture`,
`math`, `words`, `sayings` ship):

```json
{ "name": "Animals", "prompt": "which animal is this?",
  "questions": [
    { "level": 1, "q": "How many legs does a dog have?",
      "choices": ["Two", "Four", "Six"], "answer": 1 },
    { "level": 2, "image": "animals/lion", "q": "Which animal is this?",
      "choices": ["Lion", "Tiger", "Cat"], "answer": 0 }
  ] }
```

`answer` is the index into `choices` (the engine shuffles the display
order). `image` is an extension-less pool stem (optional). Questions are
grouped by `level`. Each answer is **tapped twice** — the first tap speaks
the choice, the second locks it in — so `tools/gen-voice.sh` scans
`godot/assets/data/quiz/*.json` and bakes every distinct answer string,
keeping choices voiced with no live TTS. To add a whole new deck: drop the
JSON in, add a `{ deck, label }` entry to the picker list in
`godot/scripts/QuizMenu.gd`, then re-bake the voice pack.

### Puzzles / Picture Wipe — scene-art difficulty

Difficulty is a trailing `_easy` / `_med` / `_hard` tag on the background
filename (`castle-dragon_easy.jpg`); an untagged file is eligible at every
tier. The level → tier map is in the `LEVELS` tables of `Puzzle.gd` and
`Wipe.gd`. Drop a new `backgrounds/*.jpg` in and it's picked up
automatically.

### Spoken lines (voice pack)

`godot/assets/audio/voice/v_<slug>.ogg`, produced by
**`tools/gen-voice.sh`** (needs `ffmpeg`). Add strings to the `PHRASES`
array and run:

```sh
TTS=google tools/gen-voice.sh          # natural voice, no install (needs network)
# or, best quality, offline:
PIPER_MODEL=~/.local/share/piper/en_US-lessac-medium.onnx tools/gen-voice.sh
# no engine chosen and no piper model → espeak-ng (robotic) fallback
```

Each clip is sourced **best-first**: an original human recording if
`HUMAN_SRC` has one (the GPL en_GB letters `a`–`z` and digits `0`–`9`),
otherwise a synthesiser chosen by `TTS=`:

- `TTS=google` — Google Translate TTS. Natural, no install, needs
  network + `curl`; unofficial endpoint but fine for a one-time bake.
  `GTTS_LANG` (default `en`) picks `en` / `en-GB` / `en-AU` / …
- `TTS=piper` — offline neural, best quality (`PIPER_MODEL` / on `PATH`).
- `TTS=espeak` — offline, robotic, always there.
- default `auto` = piper if a model is present, else espeak.

A plain run **keeps every existing clip** and only renders new / missing
phrases — so adding a line to `PHRASES` is a one-command no-churn update.
`FORCE=1` re-bakes the whole pack with the chosen `TTS=` engine (and
re-pulls `HUMAN_SRC`). `NO_HUMAN=1` ignores `HUMAN_SRC` for a fully
uniform pass.

Commit the regenerated `.ogg`s — they're already in `godot/assets/`, the
one place the game loads from.

The slug is `lowercase, non-alphanumerics → "-", trimmed, 48 chars` — the
same rule in `gen-voice.sh` and `GameContext._slug()`, so `say("Tap
number 3")` finds `v_tap-number-3.ogg` automatically. If a clip is missing
the games fall back to live TTS, then to silence.

### Asset pools

`godot/assets/graphics/pools/` and
`godot/assets/audio/{sfx,soundmemory,flashcards,voice}/` are the
**hand-maintained source of truth** — the purpose-named pools every game
reads from (see [`docs/ASSETS.md`](docs/ASSETS.md) for the recipes and
`docs/Design-Policy.md` §A for the naming rules). To add or swap an asset,
drop a correctly-named file straight into the pool folder and commit it
(plus its generated `.import` sidecar). There is no sync step — that tree
is loaded from *and* shipped from the same place.

The repo-root `assets/` folder is **only** for editable originals
(`.svg` / `.afdesign` / layered exports) and generator inputs
(`assets/audio/human/`): things the game never loads and no build ever
ships.

---

## Develop

### Run it

```sh
godot --path godot                 # boots res://scenes/MainMenu.tscn
godot/tests/smoke.sh               # headless: load every scene, exit != 0 on failure
```

`AssetLoader` (autoload) indexes `res://assets/` and exposes
`get_texture(name)` / `play_sound(name)` (SVG-first, with an optional
artwork overlay). `GameContext` (autoload) owns the palette (`c("role")`),
the no-repeat pools (`draw_from_pool` / `draw_tiered`), `load_json()`,
`speak()`, `style_hud_bar()` / `name_toggle_*`, and the theme / artwork /
sound settings. The launcher (`MainMenu.gd` + `MenuTile.gd`) is a
responsive, paginated square-tile grid; `MemoryMenu` and `QuizMenu` are
deck pickers.

### Build the packages

`godot/export_presets.cfg` (committed) carries the **Linux**, **Windows
Desktop** and **Web** presets. With Godot 4 and the matching export
templates installed:

```sh
cd godot
godot --headless --export-release "Linux"           ../dist/childsplay-modern.x86_64
godot --headless --export-release "Windows Desktop"  ../dist/childsplay-modern.exe
godot --headless --export-release "Web"              ../dist/web/index.html
cd .. && sh tools/package_deb.sh dist/childsplay-modern.x86_64 dist   # -> dist/childsplay-modern_<version>_amd64.deb
```

`tools/package_deb.sh` needs `dpkg-deb` and, for the hicolor icon, one of
`rsvg-convert` / `inkscape` / `convert` (a missing rasteriser just omits
the icon). `tools/ci_setup_godot.sh` is what CI uses to fetch Godot +
templates; run it locally too if you don't have them.

The Web preset is single-threaded (no COOP/COEP headers needed) with
`progressive_web_app/enabled` — the exported `public/` installs as a
full-screen, offline app on Android / ChromeOS / Windows / macOS and, via
"Add to Home Screen", iOS.

### Release

Bump `config/version` in `godot/project.godot`, commit, then push a
matching tag:

```sh
git tag v0.5.0 && git push origin v0.5.0
```

`.github/workflows/release.yml` verifies the tag matches
`config/version`, exports Linux/Windows/Web, packages the `.deb`, zips the
web build, writes `SHA256SUMS`, and publishes a GitHub Release with all of
it (Godot cross-exports Windows from Linux — no Windows machine needed).

`.github/workflows/ci.yml` runs the headless scene-load smoke on every
push to `main` and every PR — every scene is `load()`ed + `instantiate()`d
headless, so a parse error or a missing resource fails CI before merge —
then a `package` job builds the same deb/exe/web as downloadable
artifacts. `.github/workflows/pages.yml` exports the Web preset and
deploys it to <https://hakarune.github.io/childsplay-modern> on every push
to `main` (Pages "Source" is set to **GitHub Actions**).

---

## Other platforms — is a Windows / Android / Chrome build feasible?

| Target | Status | Notes |
| --- | --- | --- |
| **Windows `.exe`** | **Done** — `godot --headless --export-release "Windows Desktop"` | The `Windows Desktop` preset in `godot/export_presets.cfg` (x86_64, embedded pck), cross-exported from Linux in CI. Release output: `childsplay-modern_<version>_windows_x86_64.zip`. Unsigned, so SmartScreen warns once. |
| **Installable web app (PWA)** | **Done** | The `Web` preset has `progressive_web_app/enabled` — the export generates its own service worker + manifest. The hosted site installs as a full-screen, offline app on **Android, ChromeOS, Windows, macOS and (via "Add to Home Screen") iOS**. |
| **Android `.apk`** | Not built; medium effort | (a) Godot Android export — needs the Android SDK + build-tools + a keystore (~30 min one-time), then exports an APK/AAB. (b) Wrap the Web PWA in a **Trusted Web Activity** — a thin APK pointing at the Pages URL, auto-updating, Play-Store-installable. |
| **macOS `.app` / `.dmg`** | Not built; build easy, ship hard | Godot exports it, but Gatekeeper wants an Apple Developer cert + notarization (and a Mac) for others to run it without right-click-Open. Fine unsigned for personal use. |
| **Chrome App** | Won't do | Chrome packaged apps were removed everywhere except deprecated ChromeOS kiosk. |
| **Chrome Extension** | Won't do | Would just open the page in a tab — no gain over the hosted site or the PWA. |

---

## Included activities

Full conversion status and per-game notes live in
[`docs/GAME-STATUS.md`](docs/GAME-STATUS.md). All 20 below are implemented.

The name shown on the tile is first; the internal id (scene name) follows
in parentheses where it differs.

| Activity | Skill | What you do |
| --- | --- | --- |
| **Memory Games** (`memory`) | Visual memory | Flip-and-match picture pairs. A sub-menu picks the deck: Pictures / lowercase / UPPERCASE / Numbers / Sounds. |
| **Sound Memory** (`soundmemory`) | Listening, memory | `?`-tiles play a clip; match by ear, a matched pair reveals its picture. |
| **Falling Letters** (`fallingletter`) | Letter recognition, keyboard | Type the letter on each balloon (physical, device, or in-canvas keyboard) before it hits the danger line. 6 levels, gentle first; out of lives replays the level. |
| **Find the sound** (`findsound`) | Listening | Hear a clip, tap the picture it belongs to. Themed levels — one per graphics pool folder. |
| **Flashcards** | Vocabulary | Picture + word cards for 12 animals; tap to hear the word. English + Deutsch / Nederlands / Français / Español. |
| **Puzzles** (`puzzle`) | Spatial reasoning | Drag the pieces of a scene into the frame. 10 levels, grids → irregular rectangles; the picture is drawn from a shared pool by the level's difficulty tier. |
| **Picture Find** (`findit`) | Attention | Spot-the-difference — the scene is shown twice, the right copy has coloured spots added; tap them all. |
| **Picture Wipe** (`wipe`) | Fine motor | Drag a sponge to wipe a grey cover off a hidden scene. 12 levels, rising target %, shrinking sponge; picture by difficulty tier. |
| **What changed** (`ichanger`) | Attention, memory | Study a row of pictures; the cards flip and one has changed — tap it. |
| **Aquarium** | Calm play (no score) | A fish tank toy over a Material-3 parallax backdrop: poke a fish for its name + a bubble, tap the water to drop food. Optional "read the fish names" mode. |
| **Pong** | Hand–eye | Bat and ball vs a gentle AI; first to 5; 3 speeds. Framed court with a style picker: Retro (Atari) / 90s Neon / Y2K / Modern. |
| **Block Breaker** (`blockbreaker`) | Hand–eye | Calm Breakout — slide the paddle, clear six brick walls. Tough bricks take two hits; 3 lives. |
| **Billiards** | Aim, fine motor | Drag back from the cue ball to aim + set power. 6 pockets, 3/6/10-ball racks. |
| **PacKid** (`packid`) | Planning, coordination | Steer through an open maze eating dots, avoiding fruit "ghosts". Arrow keys or swipe. Friendly bump-reset, no game over. |
| **Simon** | Sequence memory | Repeat the growing colour-and-tone sequence. 10 levels (length 2→11). Synthesised tones. A miss just replays — no game over. |
| **ImageLink** (`electro`) | Matching, vocabulary | Drag a wire from each animal picture to its name; targets snap to the nearest node. Pairs from `godot/assets/data/electro.json`. 6 levels, 3→8 pairs. |
| **Remember the Number** (`numbers`) | Number order, memory | Study numbered tiles, they blank out, tap them 1→N from memory. A wrong tap peeks the board. 6 levels (4→9 tiles). |
| **Connect Four** (`fourrow`) | Planning | Four-in-a-row vs the computer (3 AI levels) or **local Pass & Play**; asks 1 Player / 2 Players before the first move. |
| **Tic-Tac-Toe** (`tictactoe`) | Planning | Noughts and crosses vs Easy / Medium / perfect-minimax computer, or **local Pass & Play**; asks 1 Player / 2 Players up front. |
| **StartsWith** (`synonyms`) | Early literacy | Given a starting letter, build words on the on-screen or device keyboard. Scored against a ~1200-word dictionary; **2 hints per level**; spoken prompt on open. |
| **Quizzes** (`quiz`) | General knowledge | A spoken multiple-choice question; tap an answer once to hear it, again to lock it in. Deck picker: General / Pictures / Math / Words / Sayings, hand-editable JSON. |

---

## Controls

| Context | Input | Action |
| --- | --- | --- |
| Main-menu top bar | **Theme** button | Toggle light / dark |
| Main-menu top bar | **Sound** button | Music / Effects / Voice mute panel |
| Main-menu top bar | **Art** button | Switch artwork style (only shown when an overlay art set is present) |
| Any activity | 🔊 button in the HUD | Re-speak the current instruction |
| Any activity | `Esc` / **Back** button in the HUD | Back to the dashboard |
| Menu | Click / tap · ← → · swipe | Select · change page |
| Falling Letters / StartsWith | Letter keys, the device keyboard, or the on-screen one; `⌨` toggle | Type · switch keyboard |
| StartsWith | **Hint** button | Reveal a word you haven't found (2 per level) |
| Memory Games / Find the sound / ImageLink / What changed | "names" pill | Toggle spoken picture names |
| Quizzes | Tap an answer (1st = hear it, 2nd = lock in) · 🔊 | Answer · hear the question again |
| Memory Games / Sound Memory / Find the sound / Picture Find / What changed | Click / tap | Flip / pick / tap the target |
| Billiards / Pong / Block Breaker | Click-drag or touch-drag | Aim & power / move the paddle |
| Pong | "Look" button (before serving) | Cycle the court style |
| PacKid | Arrow keys / swipe | Move through the maze |
| ImageLink | Drag between the dots (snaps to nearest) | Wire a picture to its name |
| Connect Four / Tic-Tac-Toe | 1 Player / 2 Players (asked before the first move) | Choose opponent |

The Godot project enables mouse↔touch emulation both ways, so every
activity is playable with a pointer or a touchscreen.

---

## Assets & attribution

All art and audio under `godot/assets/` is derived from the original
Childsplay project and is licensed under the **GPL-3.0**, same as the
original code (`legacy-sources/childsplay-legacy/COPYING`). The baked
voice clips in `godot/assets/audio/voice/` are the GPL en_GB letter/digit
recordings (originals kept at repo-root `assets/audio/human/`) plus short
lines synthesised by `tools/gen-voice.sh` (currently Google Translate TTS;
swappable for piper). Upstream:
<https://codeberg.org/childsplay/childsplay>.

To refresh the upstream checkout used for extraction:

```sh
git clone https://codeberg.org/childsplay/childsplay.git \
  legacy-sources/childsplay-legacy
```

`legacy-sources/` is git-ignored — a working copy for pulling assets, not
part of this repository.

---

## License

Childsplay-Modern is released under the **GNU General Public License v3.0**.
See [`LICENSE`](./LICENSE).
