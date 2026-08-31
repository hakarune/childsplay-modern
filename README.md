# Childsplay-Modern

A modern re-implementation of **[Childsplay](https://codeberg.org/childsplay/childsplay)**,
the classic suite of small educational games for children **ages 2–7**
(letter and number recognition, memory, listening skills, hand–eye
coordination). The original is a Python/Pygame application; Childsplay-Modern
rebuilds the core activities on two independent, self-contained targets that
share one pool of art and audio.

**20 activities** (including a multiple-choice **Quiz** with five decks), a
**light / dark theme**, **spoken instructions baked in** (no text-to-speech
engine required), **per-channel sound** (music / effects / voice), and
**local 2-player** for the board games. Everything runs offline.

* **Play in a browser:** <https://hakarune.github.io/childsplay-modern>
* **Install on Linux:** grab the `.deb` from
  [**Releases**](https://github.com/hakarune/childsplay-modern/releases)

---

## Dual-target architecture

The same set of activities ships through two engines that share nothing at
runtime but draw from one common `assets/` pool.

| Target | Engine | Runs on | Distribution |
| --- | --- | --- | --- |
| **Desktop** | Godot 4 (GL Compatibility renderer) | Native desktop Linux (x86_64) | `.deb` package (GitHub Releases) |
| **Web** | Hand-written HTML5 `<canvas>` + ES modules, no framework | Any modern browser — phones, tablets, Chromebooks, desktops | Static files (GitHub Pages) |

```
                 assets/  (shared raw PNG/SVG/WAV/OGG, flat "pools", data files)
                   /                              \
        desktop-godot/                        web-canvas/
      Godot 4 project  ->  build-deb.sh        index.html + js/ modules
      exported binary  ->  childsplay-modern_*.deb    served as a static site
```

Why two implementations instead of one exported everywhere:

* The **desktop** build wants tight OS integration — a real `.deb`, a
  desktop entry, offline install, predictable performance on low-end Linux
  machines used in schools.
* The **web** build wants zero install and a tiny download so it loads on a
  locked-down Chromebook or a parent's phone. A stripped hand-written canvas
  engine keeps the payload far smaller than a WebAssembly engine export.

`assets/` is the single source of truth they both consume. See
[**docs/ASSETS.md**](docs/ASSETS.md) for the full layout, the sync/build
flow, and the naming rules — read it before moving or adding any art or
audio.

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
sudo apt install ./childsplay-modern_0.4.0_amd64.deb
#   or:  sudo dpkg -i childsplay-modern_0.4.0_amd64.deb && sudo apt -f install
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
├── assets/                     Shared source of truth — see docs/ASSETS.md
│   ├── graphics/
│   │   ├── pools/                Flat, purpose-named art the games actually use
│   │   │   ├── backgrounds/        paintings + aquarium_1..6
│   │   │   ├── animals/            01_cat.png … 21_frog.png, dog/horse/rooster
│   │   │   ├── ui/                 card faces, sponge, bubble, soundbut
│   │   │   ├── soundpics/          Find Sound / Sound Memory pictures
│   │   │   ├── icons/              one <game-id>.png per menu tile
│   │   │   └── sprites/<game>/     packid / billiards / aquarium sprite sheets
│   │   └── lib/                  Untouched legacy dump — provenance only, NOT synced
│   ├── audio/
│   │   ├── sfx/                  Flat effect clips (referenced by bare filename)
│   │   ├── voice/               Baked spoken lines: v_<slug>.ogg
│   │   ├── soundmemory/         Shared Find Sound / Sound Memory clip set: <id>.ogg
│   │   ├── flashcards/<lang>/   Recorded animal names (de/nl/fr/es)
│   │   ├── lib/                  Legacy sound tree — provenance only, NOT synced
│   │   └── alphabet-sounds/     Legacy locale packs — provenance only, NOT synced
│   ├── data/                    Editable game content (see "Customising content")
│   │   ├── electro.json           Electro picture↔name pairs
│   │   ├── findsound.json         Find Sound levels + spoken-label overrides
│   │   ├── backgrounds.json       Difficulty tier per painting (Puzzle + Wipe)
│   │   ├── wordlist.json          Word Maker dictionary (~1200 words)
│   │   └── quiz/*.json            One deck per Quiz (general/picture/math/words/sayings)
│   └── fonts/                   DejaVu Sans Condensed (UI font)
├── desktop-godot/              Godot 4 engine source
│   ├── project.godot             1280×720, canvas_items/keep stretch, Compatibility
│   ├── default_bus_layout.tres   Master / Music / SFX / Voice audio buses
│   ├── sync-assets.sh            Mirror curated ../assets pools → desktop-godot/assets (res://)
│   ├── build-deb.sh             Export + package the .deb (Linux)
│   ├── build-windows.sh        Export + zip the .exe (Windows x86_64)
│   ├── scenes/                   MainMenu.tscn, MemoryMenu.tscn, QuizMenu.tscn, games/*.tscn
│   └── scripts/                  AssetLoader + GameContext (autoloads), MenuTile, menus, games/*
├── web-canvas/                 HTML5 / JS / Canvas implementation (PWA)
│   ├── index.html               Responsive full-viewport canvas + chrome buttons
│   ├── manifest.webmanifest     PWA manifest
│   ├── sw.js                    Service worker (offline, stale-while-revalidate)
│   ├── icons/                   App icons (icon.svg + generated PNGs)
│   ├── sync-assets.sh           (Re)build web-canvas/assets/ from ../assets
│   ├── serve.sh                 Local static server for development
│   ├── assets/                  Web-sized copy of the pools + data files (committed)
│   └── js/                       engine.js, util.js, theme.js, artstyle.js, tts.js,
│                                 textinput.js, menu.js, main.js, games/*
├── tools/                      Content generators (see below)
│   ├── migrate-assets.sh         Build assets/graphics/pools/ from the legacy dump
│   ├── migrate-audio.sh          Build assets/audio/{sfx,soundmemory,flashcards}/ from the legacy dump
│   ├── gen-voice.sh              Bake spoken lines → assets/audio/voice/*.ogg
│   ├── gen-electro-data.sh       Rebuild assets/data/electro.json from the art
│   └── gen-wordlist.py           Rebuild assets/data/wordlist.json
├── build-deb.sh                Thin wrapper → desktop-godot/build-deb.sh
├── docs/
│   ├── ASSETS.md                 Where assets live + the sync/build flow (source of truth)
│   ├── Design-Policy.md          The cross-cutting rules every game follows (§A–§L)
│   ├── GAME-STATUS.md            Per-activity conversion tracker + changelog
│   ├── assets/<id>.assets.md     Per-game graphics declaration (§A.7)
│   └── templates/ASSETS.template.md
├── .github/workflows/deploy-pages.yml   Auto-deploys web-canvas/ to Pages on push
├── legacy-sources/             Upstream checkout for asset extraction (git-ignored)
├── LICENSE                     GPL-3.0
└── README.md
```

---

## Features

* **Light / dark theme** — a toggle in the top bar (☀ / ☾ on web,
  "Theme" on desktop). Every screen repaints from a shared 20-role palette
  (`web-canvas/js/theme.js` / `GameContext.PALETTE_*`); the choice is
  remembered. Contrast is WCAG-checked in both themes.
* **Spoken instructions, baked in** — short lines ("drag a wire from each
  picture to its name", number and animal names, …) are pre-rendered to
  `assets/audio/voice/v_<slug>.ogg` with `espeak-ng` and ship with both
  targets, so pre-readers get audio help even with **no TTS engine
  installed**. Each game's HUD has a 🔊 button that re-speaks the current
  prompt; live OS/browser TTS is used only as a fallback. Games with named
  pictures (Memory, Find Sound, Electro, Image Changer, Aquarium) have a
  **"say the names"** toggle — off by default, on speaks the picture on
  interaction.
* **Per-channel sound** — Music / Effects / Voice, each independently
  muteable. Web: the 🔊 popover in the top bar. Desktop: the **Sound**
  button opens the same three-way panel. The setting persists
  (`localStorage` / `user://settings.cfg`).
* **No-repeat asset pools** — Puzzle / Memory / Wipe / Find It draw
  pictures from shared "bags" so the same image doesn't recur within a
  session; Puzzle and Wipe share a **per-difficulty-tier** painting bag
  (`assets/data/backgrounds.json`).
* **Drop-in SVG art** — every image is referenced without an extension, so
  a newer `.svg` next to a `.png` / `.jpg` wins automatically
  (`svg → png → jpg → jpeg → webp`). A dormant **artwork** menu toggle
  switches to an `assets/graphics/themes/<style>/` overlay set once one
  exists — the button only appears when overlay art is present.
* **Typing games** — Falling Letter and Word Maker take a physical
  keyboard, the device's on-screen keyboard, **or** an in-canvas QWERTY
  kept as the accessibility path; a `⌨` button switches between the last
  two.
* **Responsive** — a fixed 1280×720 world is aspect-fit into any screen;
  portrait phones play fit-to-width with the game ratio preserved.
* **Local 2-player** — Four in a Row and Tic Tac Toe have a 1P/2P toggle
  (Pass & Play) shown before the first move.

---

## Customising content

Game content lives in plain files under `assets/`. Edit, regenerate if
there's a helper, then re-sync the target(s) and commit. All generators
need only `bash` + `python3` unless noted.

### Electro — picture ↔ name matches

`assets/data/electro.json` — one `{ "img", "say" }` per line:

```json
{ "pairs": [
  { "img": "01_cat", "say": "cat" },
  { "img": "dog",    "say": "dog" }
] }
```

* `img` is a filename **stem** in `assets/graphics/pools/animals/` (no
  extension).
* `say` is the printed + spoken word.
* To add a match: drop the picture in `assets/graphics/pools/animals/`, add
  a line here, and — so it's spoken without live TTS — add the word to the
  `PHRASES` list in `tools/gen-voice.sh` and re-bake (below).
* `tools/gen-electro-data.sh` rebuilds this file from **every** picture in
  the animals pool (strips a leading `NN_`, turns `_` into spaces). Run it
  after adding art if you want all of it in play; it **overwrites** hand
  edits.

Both targets fall back to a built-in list if the file is missing.

### Word Maker — the dictionary

The ~1200-word kid dictionary is `assets/data/wordlist.json`. Don't edit the
JSON directly — edit the `WORDS` blob in **`tools/gen-wordlist.py`** (any
whitespace/newlines are fine) and run it:

```sh
python3 tools/gen-wordlist.py      # -> assets/data/wordlist.json
```

Rules enforced by the generator: lowercased, `a–z` only, length 2–8,
de-duplicated, sorted. Keep it kid-safe and avoid proper nouns. The
per-level starting letters and word targets are in `LEVELS` in
`web-canvas/js/games/synonyms.js` and
`desktop-godot/scripts/games/WordMaker.gd`.

### Find Sound — levels

`assets/data/findsound.json`:

```json
{ "levels": [ { "name": "Animals", "ids": ["cow", "elephant", "frog"] } ],
  "labels": { "carhorn": "car horn" } }
```

Each `id` must be both a picture stem in `assets/graphics/pools/soundpics/`
**and** a clip stem (`<id>.ogg`). `labels` overrides the spoken word for
ids whose filename reads oddly; anything not listed is de-slugged
automatically. Both targets fall back to a built-in list.

### Quiz — decks

One file per deck in `assets/data/quiz/` (`general`, `picture`, `math`,
`words`, `sayings` ship):

```json
{ "name": "Animals", "prompt": "which animal is this?",
  "questions": [
    { "level": 1, "q": "How many legs does a dog have?",
      "choices": ["Two", "Four", "Six"], "answer": 1 },
    { "level": 2, "image": "animals/17_lion", "q": "Which animal is this?",
      "choices": ["Lion", "Tiger", "Cat"], "answer": 0 }
  ] }
```

`answer` is the index into `choices` (the engine shuffles the display
order). `image` is an extension-less pool stem (optional). Questions are
grouped by `level`. To add a whole new deck: drop the JSON in and add a
`{ deck, label }` entry to the picker list in
`web-canvas/js/games/quiz-menu.js` and
`desktop-godot/scripts/QuizMenu.gd`.

### Puzzle / Wipe — painting difficulty

`assets/data/backgrounds.json` maps each painting stem to a tier
(`easy` / `med` / `hard`); a stem not listed is eligible at every tier.
The level → tier map is in the `LEVELS` tables of `puzzle.js` / `Puzzle.gd`
and `wipe.js` / `Wipe.gd`.

### Spoken lines (voice pack)

`assets/audio/voice/v_<slug>.ogg`, produced by **`tools/gen-voice.sh`**
(needs `espeak-ng` + `ffmpeg`). Add strings to the `PHRASES` array and run:

```sh
tools/gen-voice.sh
```

The slug is `lowercase, non-alphanumerics → "-", trimmed, 48 chars` — the
same rule in `tts.js` (`slug()`) and `GameContext._slug()`, so `say("Tap
number 3")` finds `v_tap-number-3.ogg` automatically. If a clip is missing
the games fall back to live TTS, then to silence.

### Asset pools

`assets/graphics/pools/` and `assets/audio/{sfx,soundmemory,flashcards}/`
are the curated pools the games actually reference. They are built from the
legacy dumps by **`tools/migrate-assets.sh`** and **`tools/migrate-audio.sh`**
(see [`docs/ASSETS.md`](docs/ASSETS.md) for the whole picture and
`docs/Design-Policy.md` §A for the naming rules). To add or swap an asset,
either drop a correctly-named file straight into a pool folder, or edit the
relevant `migrate-*.sh` mapping table and re-run it. The legacy trees
(`graphics/lib/`, `audio/lib/`, `audio/alphabet-sounds/`) stay in the repo
for provenance but are **not** synced to either target.

### After editing anything under `assets/`

```sh
web-canvas/sync-assets.sh          # refresh web-canvas/assets/ + manifest.json
desktop-godot/sync-assets.sh       # refresh desktop-godot/assets/ (res://)
```

Then commit the changed `assets/**` **and** the regenerated
`web-canvas/assets/**`. The desktop copy is git-ignored (rebuilt at
package time), but the web copy is committed because Pages serves it as-is.

---

## Develop

### Web

No build step, no bundler. Serve `web-canvas/` over HTTP (ES modules need
`http://`, not `file://`):

```sh
cd web-canvas
./sync-assets.sh        # first run: build web-canvas/assets/ (~9 MB)
./serve.sh              # -> http://localhost:8080  (pass a port to change)
```

Deploying is just copying `web-canvas/` to any static host; a push to
`main` that touches `web-canvas/**` auto-deploys to GitHub Pages via
`.github/workflows/deploy-pages.yml`.

The web target is a **PWA**: `manifest.webmanifest` + `sw.js` (a
stale-while-revalidate service worker) make it installable and fully
offline once visited, on Android / ChromeOS / Windows / macOS / iOS. Bump
`CACHE` in `sw.js` on a release if you want old cache entries evicted
immediately rather than lazily refreshed. Icons live in `web-canvas/icons/`
(regenerate the PNGs from `icon.svg` with `rsvg-convert`).

`js/` layout:

| File | Role |
| --- | --- |
| `js/engine.js` | Named state machine, image/sound loader + cache, channelled audio (`AudioManager`), rAF loop, fixed 1280×720 world with aspect-fit scaling, pointer/touch/key normalisation, `manifest.json` + artwork-overlay resolution. |
| `js/theme.js` | The 20-role light/dark palette; `setTheme` / `toggleTheme` / `initTheme`; mirrors roles to `--cp-*` CSS vars for the HTML chrome. |
| `js/artstyle.js` | The `classic` / overlay artwork switch (§C.4) — `initArtStyle` / `toggleArtStyle`, populated from the manifest. |
| `js/tts.js` | `say(text)` — baked clip → live `speechSynthesis` → silence. |
| `js/textinput.js` | `TextInput` — the hidden `<input>` that raises the device keyboard for the typing games, with the in-canvas keyboard as the a11y fallback. |
| `js/util.js` | `roundRect`, `shuffle`, `clamp`, `drawImageFit`, `Bag` / `tierBag` (no-repeat draws), `loadData`, `makeNameToggle`, the shared win/game-over `Overlay`, the HUD 🔊 button helpers. |
| `js/menu.js` | The paginated `MainMenu` grid of square icon tiles. |
| `js/main.js` | Bootstrap: theme + artwork + sound wiring, the Memory and Quiz sub-menus, lazy `import()` of a game per launch, Back HUD, audio unlock on first tap. |
| `js/games/*.js` | One default-exported Canvas scene per activity, plus `memory-menu.js` / `quiz-menu.js` (deck pickers) and the shared `quiz.js` engine. |

### Desktop (Godot 4)

```sh
desktop-godot/sync-assets.sh       # first run / after assets change
godot4 --path desktop-godot        # boots res://scenes/MainMenu.tscn
```

`AssetLoader` (autoload) indexes `res://assets/` and exposes
`get_texture(name)` / `play_sound(name)` (SVG-first, with an optional
artwork overlay). `GameContext` (autoload) owns the palette (`c("role")`),
the no-repeat pools (`draw_from_pool` / `draw_tiered`), `load_json()`,
`speak()`, `style_hud_bar()` / `name_toggle_*`, and the theme / artwork /
sound settings. The launcher (`MainMenu.gd` + `MenuTile.gd`) is a
responsive, paginated square-tile grid; `MemoryMenu` and `QuizMenu` are
deck pickers.

Build the package:

```sh
./build-deb.sh                 # -> dist/childsplay-modern_<project version>_amd64.deb
./build-deb.sh 0.4.0           # override the version string
./build-deb.sh --no-export     # just re-package the already-exported binary
```

Requirements: Godot 4 (`godot4`/`godot` on `PATH` or `GODOT_BIN`) with the
matching **Linux export templates**; `dpkg-deb`; optionally `fakeroot`
(only if your `dpkg-deb` predates `--root-owner-group`) and
`desktop-file-utils`. `build-deb.sh` runs `sync-assets.sh`, writes an
`export_presets.cfg` if none exists (Linux / x86_64 / all resources +
`*.json` / embedded `.pck`), does a headless `--import` +
`--export-release`, then stages an FHS tree and packages it. Stage under
`$TMPDIR` or set `CHILDSPLAY_BUILD_DIR` if your checkout is on FAT/exFAT.

Windows build (needs the Windows export templates for the same Godot
version):

```sh
./desktop-godot/build-windows.sh 0.4.0
#   -> dist/childsplay-modern_0.4.0_windows_x86_64.zip
```

To publish a release: bump `config/version` in `desktop-godot/project.godot`,
build both, then
`gh release create v<x.y.z> dist/childsplay-modern_<x.y.z>_amd64.deb dist/childsplay-modern_<x.y.z>_windows_x86_64.zip`.

---

## Other platforms — is a Windows / Android / Chrome build feasible?

| Target | Status | Notes |
| --- | --- | --- |
| **Windows `.exe`** | **Done** — `desktop-godot/build-windows.sh [VERSION]` | Same Godot project, second export preset (`Windows`, x86_64, embedded pck). Needs the Windows export templates for the exact Godot version. Output: `dist/childsplay-modern_<version>_windows_x86_64.zip` (a single `.exe` + README). Unsigned, so SmartScreen warns once. |
| **Installable web app (PWA)** | **Done** | `web-canvas/manifest.webmanifest` + `sw.js`. The hosted site installs as a full-screen, offline app on **Android, ChromeOS, Windows, macOS and (via "Add to Home Screen") iOS** — one artifact, every platform. |
| **Android `.apk`** | Not built; medium effort | (a) Godot Android export — needs the Android SDK + build-tools + a keystore (~30 min one-time), then exports an APK/AAB. (b) Wrap the PWA in a **Trusted Web Activity** — a thin APK pointing at the Pages URL, auto-updating, Play-Store-installable. |
| **macOS `.app` / `.dmg`** | Not built; build easy, ship hard | Godot exports it, but Gatekeeper wants an Apple Developer cert + notarization (and a Mac) for others to run it without right-click-Open. Fine unsigned for personal use. |
| **Chrome App** | Won't do | Chrome packaged apps were removed everywhere except deprecated ChromeOS kiosk. |
| **Chrome Extension** | Won't do | Would just open the page in a tab — no gain over the hosted site or the PWA. |

---

## Included activities

Full conversion status and per-game notes live in
[`docs/GAME-STATUS.md`](docs/GAME-STATUS.md). All 20 below are implemented
on **both** targets.

| Activity | Skill | What you do |
| --- | --- | --- |
| **Memory** | Visual memory | Flip-and-match picture pairs. A sub-menu picks the deck: Pictures / lowercase / UPPERCASE / Numbers / Sounds. |
| **Sound Memory** | Listening, memory | `?`-tiles play a clip; match by ear, a pair reveals the picture. |
| **Falling Letter** | Letter recognition, keyboard | Type the letter on each balloon (physical, device, or in-canvas keyboard) before it hits the danger line. 6 levels, gentle first; out of lives replays the level. |
| **Find Sound** | Listening | Hear a clip, tap the picture it belongs to. Themed levels from `assets/data/findsound.json`. |
| **Flashcards** | Vocabulary | Picture + word cards for 12 animals; tap to hear the word. English + Deutsch / Nederlands / Français / Español. |
| **Puzzle** | Spatial reasoning | Drag the pieces of a painting into the frame. 10 levels, grids → irregular rectangles; the picture is picked from a shared pool by the level's difficulty tier. |
| **Find It** | Attention | Spot-the-difference — the painting is shown twice, the right copy has coloured spots added; tap them all. |
| **Wipe** | Fine motor | Drag a sponge to wipe a grey cover off a hidden painting. 12 levels, rising target %, shrinking sponge; picture by difficulty tier. |
| **Image Changer** | Attention, memory | Study a row of pictures; the cards flip and one has changed — tap it. |
| **Aquarium** | Calm play (no score) | A fish tank toy over a Material-3 parallax backdrop: poke a fish for its name + a bubble, tap the water to drop food. Optional "read the fish names" mode. |
| **Pong** | Hand–eye | Bat and ball vs a gentle AI; first to 5; 3 speeds. Framed court with a style picker: Retro (Atari) / 90s Neon / Y2K / Modern. |
| **Block Breaker** | Hand–eye | Calm Breakout — slide the paddle, clear six brick walls. Tough bricks take two hits; 3 lives. |
| **Billiards** | Aim, fine motor | Drag back from the cue ball to aim + set power. 6 pockets, 3/6/10-ball racks. |
| **Packid** | Planning, coordination | Steer through an open maze eating dots, avoiding fruit "ghosts". Arrow keys or swipe. Friendly bump-reset, no game over. |
| **Simon** | Sequence memory | Repeat the growing colour-and-tone sequence. 10 levels (length 2→11). Synthesised tones. A miss just replays — no game over. |
| **Electro** | Matching, vocabulary | Drag a wire from each animal picture to its name; targets snap to the nearest node. Pairs from `assets/data/electro.json`. 6 levels, 3→8 pairs. |
| **Numbers** | Number order, memory | Study numbered tiles, they blank out, tap them 1→N from memory. A wrong tap peeks the board. 6 levels (4→9 tiles). |
| **Four in a Row** | Planning | Connect Four vs the computer (3 AI levels) or a **local Pass & Play** 2-player game. |
| **Tic Tac Toe** | Planning | Noughts and crosses vs Easy / Medium / perfect-minimax computer, or **local Pass & Play**. |
| **Word Maker** | Early literacy | Given a starting letter, build words on the on-screen or device keyboard. Scored against a ~1200-word dictionary; **2 hints per level**; spoken prompt on open. |
| **Quiz** | General knowledge | Tap the right answer to a spoken multiple-choice question. A deck picker: General / Pictures / Math / Words / Sayings, hand-editable JSON. |

---

## Controls

| Context | Input | Action |
| --- | --- | --- |
| Top bar | ☀ / ☾ (web) · "Theme" (desktop) | Toggle light / dark |
| Top bar | 🔊 (web) · "Sound" (desktop) | Music / Effects / Voice mute panel |
| Top bar | 🎨 / "Art" | Switch artwork style (only shown when an overlay art set is present) |
| Any activity | 🔊 button in the HUD | Re-speak the current instruction |
| Any activity | `Esc` (desktop) / **Menu** button (web) | Back to the dashboard |
| Menu | Click / tap · ← → · swipe | Select · change page |
| Falling Letter / Word Maker | Letter keys, the device keyboard, or the in-canvas one; `⌨` toggle | Type · switch keyboard |
| Word Maker | **Hint** button | Reveal a word you haven't found (2 per level) |
| Memory / Find Sound / Electro / Image Changer | "names" pill | Toggle spoken picture names |
| Quiz | Tap an answer button · 🔊 | Answer · hear the question again |
| Memory / Sound Memory / Find Sound / Find It / Image Changer | Click / tap | Flip / pick / tap the target |
| Billiards / Pong / Block Breaker | Click-drag or touch-drag | Aim & power / move the paddle |
| Pong | "Look" button (before serving) | Cycle the court style |
| Packid | Arrow keys / swipe | Move through the maze |
| Electro | Drag between the dots (snaps to nearest) | Wire a picture to its name |
| Four in a Row / Tic Tac Toe | 1P / 2P pill (before the first move) | Switch opponent |

The Godot project enables mouse↔touch emulation both ways, so every
activity is playable with a pointer or a touchscreen.

---

## Assets & attribution

All art and audio under `assets/` is derived from the original Childsplay
project and is licensed under the **GPL-3.0**, same as the original code
(`legacy-sources/childsplay-legacy/COPYING`). The baked voice clips in
`assets/audio/voice/` are generated locally with `espeak-ng`. Upstream:
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
