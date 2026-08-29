# Childsplay-Modern

A modern re-implementation of **[Childsplay](https://codeberg.org/childsplay/childsplay)**,
the classic suite of small educational games for children **ages 2–7**
(letter and number recognition, memory, listening skills, hand–eye
coordination). The original is a Python/Pygame application; Childsplay-Modern
rebuilds the core activities on two independent, self-contained targets.

## Dual-target architecture

Childsplay-Modern ships the same set of activities through two engines that
share nothing at runtime but draw from one common pool of art and audio.

| Target | Engine | Runs on | Distribution |
| --- | --- | --- | --- |
| **Desktop** | Godot 4 (GL Compatibility renderer) | Native desktop Linux (x86_64) | `.deb` package |
| **Web** | Hand-written HTML5 `<canvas>` + ES modules, no framework | Any modern browser — phones, tablets, Chromebooks | Static files on any web host |

```
                 assets/  (shared raw PNG/SVG/WAV/OGG/fonts)
                   /                              \
        desktop-godot/                        web-canvas/
      Godot 4 project  ->  build-deb.sh        index.html + js/ modules
      exported binary  ->  childsplay-modern_*.deb    served as static site
```

Why two implementations instead of one exported everywhere:

* The **desktop** build wants tight OS integration — a real `.deb`, a
  desktop entry, offline install, predictable performance on low-end Linux
  machines used in schools.
* The **web** build wants zero install and a tiny download so it loads on a
  locked-down Chromebook or a parent's phone. A stripped hand-written canvas
  engine keeps the payload far smaller than a WebAssembly engine export and
  sidesteps mobile-browser quirks around large `.wasm` bundles.

Keeping them separate means each can be optimised for its platform without
compromise; `assets/` is the single source of truth they both consume.

## Repository layout

```
childsplay-modern/
├── assets/              Shared raw assets extracted from the original Childsplay
│   ├── graphics/          PNG / SVG / JPG / GIF, mirrored from the legacy tree
│   ├── audio/             WAV / OGG effects and spoken prompts
│   ├── fonts/             DejaVu Sans Condensed (UI font)
│   └── icons/             Application / launcher icon
├── desktop-godot/       Godot 4 engine source
│   ├── project.godot       1280x720, canvas_items/keep stretch, Compatibility renderer
│   ├── default_bus_layout.tres  Master / Music / SFX / Voice audio buses
│   ├── sync-assets.sh      Mirrors ../assets into desktop-godot/assets (res://)
│   ├── scenes/             MainMenu.tscn + MemoryMenu.tscn + games/*.tscn
│   └── scripts/            AssetLoader & GameContext (autoloads), menus, games/*
├── web-canvas/          HTML5 / JS / Canvas implementation
│   ├── index.html          Responsive full-viewport kiosk canvas
│   ├── css/                Layout + HUD + splash styling
│   ├── assets/             Web-sized subset of /assets (built by sync-assets.sh)
│   ├── sync-assets.sh      (Re)builds web-canvas/assets/ from ../assets
│   └── js/                 engine.js, util.js, menu.js, main.js, games/*
├── build-deb.sh         Wrapper -> desktop-godot/build-deb.sh (export + .deb)
├── legacy-sources/      Upstream checkout (not tracked; see below)
├── docs/GAME-STATUS.md  Per-activity conversion tracker (legacy -> Godot / Web)
├── LICENSE              GPL-3.0
└── README.md
```

## Desktop Build

Requirements on the build host:

* [Godot 4](https://godotengine.org/) (`godot4` or `godot` on `PATH`, or set
  `GODOT_BIN`) with the matching **Linux export templates** installed
* `dpkg-deb` (from `dpkg`); `fakeroot` only if your `dpkg-deb` predates
  `--root-owner-group`
* optional: `desktop-file-utils` (the script validates the `.desktop` entry)

Run the project from the editor:

```sh
desktop-godot/sync-assets.sh     # first run / after assets change
godot4 --path desktop-godot
```

The project boots straight to `res://scenes/MainMenu.tscn`. `AssetLoader`
(an autoload) indexes everything under `res://assets/` on startup and
exposes `AssetLoader.get_texture(name)` / `AssetLoader.play_sound(name)`.

Produce an installable package:

```sh
./build-deb.sh            # -> dist/childsplay-modern_0.1.0_amd64.deb
./build-deb.sh 0.2.0      # override the version string
./build-deb.sh --no-export   # re-package an already-exported binary only
```

`desktop-godot/build-deb.sh` runs `sync-assets.sh`, writes an
`export_presets.cfg` (Linux / `x86_64`, **all resources**, embedded `.pck`)
if none exists, does a headless `--import` + `--export-release "Linux"` to a
single self-contained ELF, then stages an FHS layout and packages it:

```
usr/bin/childsplay-modern                                  (the game)
usr/share/applications/childsplay-modern.desktop           (menu entry)
usr/share/icons/hicolor/scalable/apps/childsplay-modern.svg
usr/share/doc/childsplay-modern/copyright
DEBIAN/{control,postinst,postrm}   (postinst/postrm refresh the menu caches)
```

Staging happens under `$TMPDIR` (override with `CHILDSPLAY_BUILD_DIR`) so a
FAT/exFAT checkout can't break the `DEBIAN/` permissions `dpkg-deb` requires.

Install / remove:

```sh
sudo apt install ./dist/childsplay-modern_0.1.0_amd64.deb
sudo apt remove childsplay-modern
```

## Web Build

The web target is plain static files — there is **no build step and no
bundler**. Serve `web-canvas/` with any static HTTP server (ES modules
require `http://`, not `file://`):

```sh
cd web-canvas
./sync-assets.sh          # first run: build web-canvas/assets/ (~3 MB)
./serve.sh                # -> http://localhost:8080  (pass a port to change)
```

`web-canvas/assets/` is committed, so deploying is just copying `web-canvas/`
to any static host — GitHub Pages, Netlify, an S3 bucket, a classroom
intranet. All games are implemented as Canvas modules. The engine
aspect-fits a fixed 1280×720 world into any screen, so phones, tablets and
Chromebooks all get a clean, un-distorted layout.

`js/` layout:

| File | Role |
| --- | --- |
| `js/engine.js` | The engine: named state machine (MainMenu, MemoryMenu + 13 games), image/sound loader + cache, overlapping one-shot audio, rAF loop, fixed 1280×720 world with aspect-fit scaling, pointer/touch/key normalisation. |
| `js/util.js` | `roundRect`, `shuffle`, `clamp`, `drawImageFit`, and a shared win/game-over `Overlay` with canvas buttons. |
| `js/menu.js` | The `MainMenu` state — a reflowing grid of icon tiles. |
| `js/main.js` | Bootstrap: registers MainMenu, lazily `import()`s + re-instantiates a game module per launch (fresh reset), drives the Back HUD, unlocks audio on first tap. |
| `js/games/index.js` | Two lists: `GAMES` (loadable modules) and `MENU` (the 12 dashboard tiles). |
| `js/games/memory-menu.js` | The **Memory** tile opens this: pick a deck — Pictures / lowercase / UPPERCASE / Numbers / Sounds. |
| `js/games/{memory,fallingletter,soundmemory,findsound,puzzle,findit,aquarium,pong,fourrow,flashcards,blockbreaker,packid,billiards}.js` | Standalone Canvas games. Each default-exports `new GameScene(game, { onExit, ... })`: flip/match (Memory takes a `variant`), falling balloons + on-screen QWERTY keyboard, audio pairs, hear-and-tap picture rounds, drag-the-pieces jigsaw (grid + irregular cuts), a calm interactive fish tank, bat-and-ball, spot-the-difference, Connect Four, picture+word flashcards (browser TTS), Breakout, tilemap maze with swipe/arrow steering, 2D ball physics with drag-aim and pockets. |
| `serve.sh` | `python3 -m http.server` (or `npx serve`) on port 8080. |

Each game module is downloaded only when first opened.

## Controls

| Context | Input | Action |
| --- | --- | --- |
| Menu | Mouse click / tap | Select an activity |
| Any activity | `Esc` (desktop) / **Menu** button (web) | Return to the dashboard |
| Falling Letter | Letter keys | Match the falling letter |
| Memory / Sound Memory | Click / tap | Flip a card |
| Billiards | Click-drag / touch-drag from the ball | Aim and set power; release to shoot |
| Packid | Arrow keys / swipe | Move through the maze |

The Godot project enables mouse↔touch emulation both ways, so every activity
is playable with either a pointer or a touchscreen.

## Included Games

| Activity | Skill | Description |
| --- | --- | --- |
| **Packid** | Coordination, planning | Steer Packid through a maze, eating every dot while avoiding the ghosts. |
| **Fallingletter** | Letter recognition, keyboard | Letters drift down the screen; press the matching key before one lands. |
| **Soundmemory** | Listening, memory | A grid of tiles; flip two at a time to hear their sounds and find matching pairs. |
| **Memory** | Visual memory | The classic picture-pairs game with the original Childsplay tilesets. |
| **Billiards** | Aim, fine motor | Drag back from the cue ball to set direction and power, then release to strike. |

More of the original activities (Puzzle, Find Sound, Fishtank, Pong, …) can be
added as new scenes in `desktop-godot/scenes/games/` and matching modules
in `web-canvas/js/games/` plus a line in each registry.

**Conversion progress for every legacy activity is tracked in
[`docs/GAME-STATUS.md`](docs/GAME-STATUS.md)** — update it in the same commit
that adds or finishes a game.

## Assets & attribution

All art and audio under `assets/` is extracted verbatim from the original
Childsplay project and is licensed under the **GPL-3.0**, same as the
original code (`legacy-sources/childsplay-legacy/COPYING`). Upstream project:
<https://codeberg.org/childsplay/childsplay>.

To refresh the upstream checkout used for extraction:

```sh
git clone https://codeberg.org/childsplay/childsplay.git \
  legacy-sources/childsplay-legacy
```

`legacy-sources/` is git-ignored — it is a working copy for pulling assets,
not part of this repository.

## License

Childsplay-Modern is released under the **GNU General Public License v3.0**.
See [`LICENSE`](./LICENSE).
