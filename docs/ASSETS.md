# Assets — where they live and how they flow

**`/assets/` at the repo root is the one true location for all art, audio,
fonts and game-content data.** Everything else is derived from it by a
script and can be deleted and rebuilt. If you are moving, renaming, adding
or removing an asset, do it in `/assets/` and nowhere else, then re-run the
sync scripts (below).

For the filename grammar (difficulty tags, theme variants, resolution
order) see [`Design-Policy.md`](Design-Policy.md) §A–§C. This document is
about *locations and the build flow*.

---

## The three trees

| Tree | In git? | What it is | Rebuilt by |
| --- | :---: | --- | --- |
| **`/assets/`** | ✅ tracked | **Source of truth.** Raw + curated art/audio/data, shared by both targets. | hand-editing + the `tools/` generators |
| `desktop-godot/assets/` | ❌ git-ignored | Local mirror. Godot's `res://` can't span directories, so the curated pools are copied in. Safe to `rm -rf` and regenerate. | `desktop-godot/sync-assets.sh` |
| `web-canvas/assets/` | ✅ tracked | The **web build**: a curated, web-sized copy with flattened paths + an image `manifest.json`. Committed only because GitHub Pages serves it verbatim. | `web-canvas/sync-assets.sh` |

Two mirrors, two reasons they differ from a plain copy:

- **Godot** needs the files physically under its project root and reads
  most of them through `AssetLoader` by **bare filename** (`"good.ogg"`,
  `"card_back"`), so the mirror just has to *contain* every name a game
  asks for.
- **Web** ships over the wire, so `sync-assets.sh` copies only what the
  games use, renames a few clips to clearer names, and writes
  `manifest.json` (stem → best-available file) for `engine.resolveImage()`.

---

## `/assets/` layout

```
assets/
  graphics/
    pools/            ← the ONLY graphics location games may reference
      backgrounds/      paintings, aquarium_1..6            (flat, unique names)
      animals/          01_cat.png … 21_frog.png, dog/horse/rooster
      ui/               card_front, card_back, sponge, bubble, soundbut
      soundpics/        Find Sound / Sound Memory pictures  (<id>.png)
      icons/            one <game-id>.png per menu tile
      sprites/<game>/   dense single-game frame sets: packid, billiards, aquarium
    themes/<style>/     optional alternate-art overlay (Design Policy §C.4)
    lib/               legacy CPData dump — PROVENANCE ONLY, not synced
    activity_dev/      scratch art for WIP activities — not synced

  audio/
    sfx/              flat effect clips, referenced by bare filename on both targets
    voice/            baked spoken lines, v_<slug>.ogg — owned by tools/gen-voice.sh
    soundmemory/      shared Find Sound / Sound Memory clip set, <id>.ogg
    flashcards/<lang>/ recorded animal names for Flashcards (de, nl, fr, es)
    lib/              legacy CPData sound dump — PROVENANCE ONLY, not synced
    alphabet-sounds/  legacy per-locale letter/word packs — PROVENANCE ONLY, not synced

  data/               editable game content (JSON) — see Design-Policy.md §J
    quiz/<deck>.json
  fonts/              DejaVuSansCondensed-Bold.ttf (UI font)
```

### Curated pools vs. legacy dumps

The `lib/` and `alphabet-sounds/` trees are the **raw upstream import**,
kept verbatim so the provenance of every derived file is traceable. They
are **not** copied to either target. The pools next to them
(`graphics/pools/`, `audio/{sfx,soundmemory,flashcards}/`) are the curated,
purpose-named subset the games actually load, produced by:

| Tool | Builds | From |
| --- | --- | --- |
| `tools/migrate-assets.sh` | `graphics/pools/**` | `graphics/lib/CPData/**` + `graphics/lib/SPData/themes/**` |
| `tools/migrate-audio.sh` | `audio/sfx/`, `audio/soundmemory/`, `audio/flashcards/**` | `audio/lib/CPData/**` + `audio/alphabet-sounds/**` |
| `tools/gen-voice.sh` | `audio/voice/**` | espeak/pico TTS of the line list in the script |

Each `migrate-*` script keeps its mapping table inline so it is
reviewable. **To add or change an asset**: either drop a correctly-named
file straight into the pool folder, or edit the mapping table and re-run
the script. Re-run is only needed when the source set changes — the pool
files are committed.

The pool files **are** committed to `/assets/` (they're the real source of
truth now; the dumps are just history).

---

## The sync / build flow

```
                 tools/migrate-assets.sh   tools/migrate-audio.sh   tools/gen-voice.sh
                          │                        │                       │
   assets/graphics/lib ───┘        assets/audio/lib ┘   assets/audio/… ─────┘
   assets/audio/alphabet-sounds ───┘
                          ▼
   ┌─────────────────  assets/  (SOURCE OF TRUTH, committed)  ─────────────────┐
   │  graphics/pools   audio/sfx  audio/voice  audio/soundmemory               │
   │  audio/flashcards  data      fonts                                        │
   └───────────────┬──────────────────────────────────────┬───────────────────┘
                   │ desktop-godot/sync-assets.sh          │ web-canvas/sync-assets.sh
                   ▼                                       ▼
        desktop-godot/assets/  (git-ignored,      web-canvas/assets/  (committed;
        rebuilt on clone & before packaging)      GitHub Pages serves it as-is)
                   │                                       │
                   ▼                                       ▼
        build-deb.sh / build-windows.sh           .github/workflows/deploy-pages.yml
        → .deb / .zip  (embedded data pack)       → https://hakarune.github.io/childsplay-modern
```

### After editing anything under `assets/`

```sh
tools/migrate-assets.sh            # only if you changed the graphics mapping / source set
tools/migrate-audio.sh             # only if you changed the audio mapping / source set
web-canvas/sync-assets.sh          # refresh web-canvas/assets/ + manifest.json
desktop-godot/sync-assets.sh       # refresh desktop-godot/assets/ (res://)
```

Then commit the changed `assets/**` **and** the regenerated
`web-canvas/assets/**`. `desktop-godot/assets/` is git-ignored — the deb
and Windows build scripts run `sync-assets.sh` themselves.

---

## How each target resolves an asset at runtime

### Godot (`desktop-godot/`)

`AssetLoader` (autoload) scans `res://assets` once at boot and builds two
`filename → res:// path` indexes (textures, audio). A game asks for
`"good.ogg"` or `"card_back"` and gets the file wherever it sits.

- On a filename collision it prefers a `/pools/` path and the
  higher-priority extension (§C.3).
- The `flashcards/` directory is **skipped** by the index
  (`AssetLoader.SCAN_SKIP_DIRS`): it holds the same animal-name stems in
  four languages, which would collide with each other and with the
  `soundmemory/` clip set. `Flashcards.gd` loads those by explicit path.
- A few textures are still referenced by an explicit `res://…/pools/…`
  path in a `.tscn` (`Packid.tscn`, `Aquarium.tscn`) — always a pools
  path, never `lib/`.

Because only the curated pools are mirrored, `AssetLoader`'s old "~1668
duplicate filename" warning is down to a handful of known pool-vs-pool
overlaps (`dog.png`, `horse.png`, `rooster.png` — an animal cutout and a
Find Sound picture share the name; harmless, different callers).

### Web (`web-canvas/`)

`engine.resolveImage()` reads `web-canvas/assets/manifest.json` so a game
can reference `backgrounds/castle` with no extension and get the
best-available file. Audio is referenced by explicit path
(`sfx/good.ogg`, `soundmemory/snd/<id>.ogg`, `voice/v_<slug>.ogg`,
`flashcards/<lang>/<word>.ogg`).

---

## Naming divergence between the targets

Four clips historically had different names on each side. The pool uses
the clearer (web) name and the Godot constant was updated to match:

| Pool name | Old Godot name | Used by |
| --- | --- | --- |
| `sfx/fourrow_win.ogg` | `won.ogg` | FourRow |
| `sfx/fourrow_loss.ogg` | `loss.ogg` | FourRow |
| `sfx/aqua_ambient.ogg` | `glockenschmoutz.ogg` | Aquarium |
| `ui/bubble.png` | `blub0.png` | Aquarium |

`sfx/eat.wav` (Godot Pac-Man chomp) and `sfx/waka.wav` (web Pac-Man
chomp) are two *different* legacy clips; both are kept.

---

## Known debt

- **`assets/audio/alphabet-sounds/` is ~24 MB** but only the 48 clips in
  `flashcards/` (12 animal names × de/nl/fr/es) are used. The rest is
  kept purely as provenance. It could be dropped from the repo entirely
  if provenance is captured elsewhere.
- `assets/graphics/pools/objects/` is named in Design-Policy §A.2 but not
  yet created — no game needs a non-animal cutout pool yet.
- No `assets/audio/music/` — there are no background-music tracks; the
  win/fanfare stingers live in `sfx/` and are just played on the Music
  bus.
