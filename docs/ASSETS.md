# Assets — where they live and how they flow

**`/assets/` at the repo root is the source of truth for all art, audio,
fonts and game-content data.** The pools under it are **hand-maintained**:
to add or swap an asset you drop a correctly-named file straight into the
right pool folder and commit it. Nothing regenerates `/assets/` from
anything else.

For the filename grammar (difficulty tags, themed sets, resolution order)
see [`Design-Policy.md`](Design-Policy.md) §A–§C.

---

## The three trees

| Tree | In git? | What it is | Rebuilt by |
| --- | :---: | --- | --- |
| **`/assets/`** | ✅ tracked | **Source of truth.** The purpose-named pools every game reads from. Hand-maintained. | you, by dropping files in |
| `desktop-godot/assets/` | ❌ git-ignored | Local mirror — Godot's `res://` can't span directories, so `/assets/` is copied in. Safe to `rm -rf` and regenerate. | `desktop-godot/sync-assets.sh` |
| `web-canvas/assets/` | ✅ tracked | The **web build** — a web-sized copy with an image `manifest.json`. Committed only because GitHub Pages serves it verbatim. | `web-canvas/sync-assets.sh` |

Both `sync-assets.sh` scripts only ever **copy `/assets/` outward**. They
never write to `/assets/` itself.

---

## `/assets/` layout

```
assets/
  graphics/
    pools/            ← the ONLY graphics location games may reference
      backgrounds/      paintings + aquarium_1..6; difficulty is a
                        `_easy`/`_med`/`_hard` filename tag, untagged = any tier
      animals/          plain-named cutouts (cat, cow, dog, bird, duck, …)
      ui/               card_front, card_back, sponge, bubble, soundbut
      vehicles/         Find Sound level pool: boat, car, plane, …
      instruments/      Find Sound level pool: drum, flute, guitar, …
      sounds/           Find Sound level pool: alarm, bubbles, clang, …
      icons/            one <game-id>.png per menu tile
      sprites/<game>/   dense single-game frame sets: packid, billiards, aquarium
    themes/<style>/     optional alternate-art overlay (Design Policy §C.4)
    activity_dev/       scratch art for WIP activities — not synced

  audio/
    sfx/         flat effect clips, referenced by bare filename on both targets
    voice/       baked spoken lines + letters/digits, v_<slug>.ogg — tools/gen-voice.sh
    soundmemory/ shared Find Sound / Sound Memory clip set, <id>.ogg
    flashcards/  recorded animal names, flat: <word>_<lang>.ogg (de/nl/fr/es)
    human/       raw human recordings gen-voice.sh may pull from (en_GB a–z / 0–9)

  data/          editable game content (JSON) — see Design-Policy.md §J
    quiz/<deck>.json
  fonts/         DejaVuSansCondensed-Bold.ttf (UI font)
```

The pools were originally curated out of the upstream Childsplay
`CPData` / `SPData` dump by one-time extraction scripts. That job is done;
the dump and those scripts have been removed. The committed pools are now
the only source. (The full upstream tree still lives, git-ignored, under
`legacy-sources/` for anyone who wants to mine more from it.)

`tools/` keeps only *generators* that read the pools (or the network) and
write into `/assets/`:

| Tool | Writes | From |
| --- | --- | --- |
| `tools/gen-voice.sh` | `audio/voice/**` | per phrase, best-first: a human recording in `audio/human/`, else a synthesiser picked by `TTS=` (`google` \| `piper` \| `espeak`). Fish names are scanned from `sprites/aquarium/`. |
| `tools/gen-electro-data.sh` | `data/electro.json` | the `animals/` pool |
| `tools/gen-wordlist.py` | `data/wordlist.json` | a bundled word list |

---

## The sync / build flow

```
   ┌──────────────  assets/  (SOURCE OF TRUTH, hand-maintained, committed)  ──────────────┐
   │  graphics/pools/**   audio/{sfx,voice,soundmemory,flashcards}/**   data/   fonts/     │
   └───────────────┬───────────────────────────────────────────────┬────────────────────┘
                   │ desktop-godot/sync-assets.sh                   │ web-canvas/sync-assets.sh
                   ▼                                                ▼
        desktop-godot/assets/  (git-ignored,            web-canvas/assets/  (committed;
        rebuilt on clone & before packaging)            GitHub Pages serves it as-is)
                   │                                                │
                   ▼                                                ▼
        build-deb.sh / build-windows.sh                  .github/workflows/deploy-pages.yml
        → .deb / .zip  (embedded data pack)              → https://hakarune.github.io/childsplay-modern
```

### After adding or changing anything under `assets/`

```sh
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
  higher-priority extension (§C.3). Every pool filename is now globally
  unique, so `AssetLoader`'s old "~1668 duplicate filename" warning is
  **0**.
- `AssetLoader.list_pool("<pool>")` returns a pool's bare stems (a runtime
  directory listing) so games never hard-code a pool's contents;
  `stem_tier()` reads the `_easy/_med/_hard` tag off a filename.
- Flashcard clips are `<word>_<lang>.ogg` (flat, unique) and index like
  any other clip.
- A few textures are referenced by an explicit `res://…/pools/…` path in a
  `.tscn` (`Packid.tscn`, `Aquarium.tscn`) — always a pools path.

### Web (`web-canvas/`)

`engine.resolveImage()` reads `web-canvas/assets/manifest.json` so a game
can reference `backgrounds/castle` with no extension and get the
best-available file. `sync-assets.sh` also lists `soundmemory/snd/*` stems
in the manifest so a game can ask "does this stem have a clip?"
(`poolKeys(manifest, pool)` in `util.js`). Audio is referenced by explicit
path (`sfx/good.ogg`, `soundmemory/snd/<id>.ogg`, `voice/v_<slug>.ogg`,
`flashcards/<word>_<lang>.ogg`).

---

## Recipes

### Add a background
Drop `castle.jpg` (or `castle_hard.jpg` to tag its tier) into
`assets/graphics/pools/backgrounds/`, run both `sync-assets.sh`, commit.
Puzzle / Wipe / Find It pick it up automatically.

### Add an Aquarium fish
Drop `octopus_0.png` + `octopus_1.png` into
`assets/graphics/pools/sprites/aquarium/`, run `tools/gen-voice.sh` (bakes
`v_octopus.ogg`) and both `sync-assets.sh`, commit. Optional: a `TUNING`
entry in `aquarium.js` / `Aquarium.gd` for a non-default size.

### Add a Find Sound card
Drop `<pool>/<stem>.png` (pool = `animals` / `vehicles` / `instruments` /
`sounds`) **and** `assets/audio/soundmemory/<stem>.ogg`, run both
`sync-assets.sh`, commit.

### Add a Flashcards language (e.g. Japanese)
1. Put the 12 DECK-word clips at
   `assets/audio/flashcards/<word>_ja.ogg`.
2. Add `{ code: 'ja', label: '日本語', bcp: 'ja-JP' }` to the `LANGS`
   array in **both** `desktop-godot/scripts/games/Flashcards.gd` and
   `web-canvas/js/games/flashcards.js` — a button appears automatically.
3. Run both `sync-assets.sh`. Missing clips fall back to TTS in that
   language, so a partial set still works.

### Swap a piece of shared pool art (e.g. the card back)
Overwrite the file in `assets/graphics/pools/<pool>/`, run both
`sync-assets.sh`, commit. Keep raster pool art modestly sized (a card back
tiles small on screen — 256² is plenty).

---

## Naming divergence between the targets

A few effect clips had different names on each side. The pool uses the
clearer (web) name; the Godot constants were updated to match:

| Pool name | Old Godot name | Used by |
| --- | --- | --- |
| `sfx/fourrow_win.ogg` | `won.ogg` | FourRow |
| `sfx/fourrow_loss.ogg` | `loss.ogg` | FourRow |
| `sfx/aqua_ambient.ogg` | `glockenschmoutz.ogg` | Aquarium |
| `ui/bubble.png` | `blub0.png` | Aquarium |

`sfx/eat.wav` (Godot Pac-Man chomp) and `sfx/waka.wav` (web) are two
different clips; both are kept.

---

## Known debt

- **The synthetic `voice/` phrase clips are Google Translate TTS** — an
  unofficial endpoint. For a fully offline, reproducible pack run
  `TTS=piper tools/gen-voice.sh` on a machine with piper + a voice model;
  the human letters/digits (`audio/human/`) won't change.
- `assets/graphics/pools/objects/` is named in Design-Policy §A.2 but not
  yet created — no game needs a non-animal cutout pool yet.
- No `assets/audio/music/` — there are no background-music tracks; the
  win/fanfare stingers live in `sfx/` and play on the Music bus.
