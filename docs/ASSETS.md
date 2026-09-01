# Assets — where they live and how they flow

**`godot/assets/` is the only place art, audio, fonts and game-content data
live.** It's what the game loads (`res://assets/...`) *and* what every
export ships — Linux, Windows, the `.deb`, and the Web build's
`index.pck`. There is no build/convert/copy step: drop a correctly-named
file straight into the right pool folder under `godot/assets/`, commit it
(plus its generated `.import` sidecar), and it's in every platform's next
build.

For the filename grammar (difficulty tags, themed sets, resolution order)
see [`Design-Policy.md`](Design-Policy.md) §A–§C.

---

## The two places

| Tree | In git? | What it is |
| --- | :---: | --- |
| **`godot/assets/`** | ✅ tracked | **What the game loads and ships.** The purpose-named pools every activity reads from, plus `.import` sidecars. Hand-maintained — you drop files in and commit. |
| **`/assets/`** (repo root) | ✅ tracked | **Editable originals only** — `.svg` / `.afdesign` / layered exports and generator inputs that are never loaded by the game and never shipped in a build. |

Nothing regenerates `godot/assets/` from anything else, and nothing
copies it anywhere else. One folder in, one folder shipped.

---

## `godot/assets/` layout

```
godot/assets/
  graphics/
    pools/            ← the ONLY graphics location games may reference
      backgrounds/      kid scene art + aquarium_1..6; difficulty is a
                        `_easy`/`_med`/`_hard` filename tag, untagged = any tier
      animals/          plain-named cutouts (cat, cow, dog, bird, duck, …)
      ui/               card_front, card_back, sponge, bubble, soundbut
      vehicles/         Find the sound level pool: boat, car, plane, …
      instruments/      Find the sound level pool: drum, flute, guitar, …
      sounds/           Find the sound level pool: alarm, bubbles, clang, …
      icons/            one <game-id>.png per menu tile
      sprites/<game>/   dense single-game frame sets: packid, billiards, aquarium
    themes/<style>/     optional alternate-art overlay (Design Policy §C.4)

  audio/
    sfx/         flat effect clips, referenced by bare filename
    voice/       baked spoken lines + letters/digits, v_<slug>.ogg — tools/gen-voice.sh
    soundmemory/ shared Find Sound / Sound Memory clip set, <id>.ogg
    flashcards/  recorded animal names, flat: <word>_<lang>.ogg (de/nl/fr/es)

  data/          editable game content (JSON) — see Design-Policy.md §J
    quiz/<deck>.json
  fonts/         DejaVuSansCondensed-Bold.ttf (UI font)
```

Every file above also has a same-named `.import` sidecar, committed
alongside it — a fresh clone or CI checkout never needs a full reimport.

## `/assets/` layout (repo root — editable originals, not shipped)

```
assets/
  designing/       .afdesign / layered exports / working SVGs — the
                    editable master for anything with a flattened copy
                    under godot/assets/. Sync this between machines; the
                    game never reads it.
  activity_dev/    scratch art for WIP activities, not yet promoted to a pool
  template.icon.png  blank canvas template for new menu-tile icons
  audio/human/     raw human recordings (letters + digits, en_GB, named by
                    codepoint: U0061 = 'a') — a generator INPUT for
                    tools/gen-voice.sh, not loaded by the game. Preferred
                    over synthesised speech when baking godot/assets/audio/voice/.
```

The pools were originally curated out of the upstream Childsplay
`CPData` / `SPData` dump by one-time extraction scripts. That job is done;
the dump and those scripts have been removed. The committed pools are now
the only source. (The full upstream tree still lives, git-ignored, under
`legacy-sources/` for anyone who wants to mine more from it.)

`tools/` keeps only *generators* that read `godot/assets/` pools (or the
network) and write back into `godot/assets/`:

| Tool | Writes | From |
| --- | --- | --- |
| `tools/gen-voice.sh` | `godot/assets/audio/voice/**` | per phrase, best-first: a human recording in `assets/audio/human/` (repo root), else a synthesiser picked by `TTS=` (`google` \| `piper` \| `espeak`). Fish names are scanned from `godot/assets/graphics/pools/sprites/aquarium/`. |
| `tools/gen-electro-data.sh` | `godot/assets/data/electro.json` | `godot/assets/graphics/pools/animals/` |
| `tools/gen-wordlist.py` | `godot/assets/data/wordlist.json` | a bundled word list |

---

## After adding or changing anything under `godot/assets/`

Nothing to run. Commit the new/changed files under `godot/assets/`
(including the `.import` sidecar Godot generates for each — open the
project once, or let CI's `--headless --import` do it) and every export
picks it up on its next build.

---

## How the game resolves an asset at runtime

`AssetLoader` (autoload) scans `res://assets` once at boot and builds two
`filename → res:// path` indexes (textures, audio). A game asks for
`"good.ogg"` or `"card_back"` and gets the file wherever it sits.

- On a filename collision it prefers a `/pools/` path and the
  higher-priority extension (§C.3). Every pool filename is globally
  unique, so `AssetLoader`'s old "~1668 duplicate filename" warning is
  **0**.
- `AssetLoader.list_pool("<pool>")` returns a pool's bare stems (a runtime
  directory listing) so games never hard-code a pool's contents;
  `stem_tier()` reads the `_easy/_med/_hard` tag off a filename.
- Flashcard clips are `<word>_<lang>.ogg` (flat, unique) and index like
  any other clip.
- A few textures are referenced by an explicit `res://…/pools/…` path in a
  `.tscn` (`Packid.tscn`, `Aquarium.tscn`) — always a pools path.

The **Web** export is the same `res://assets/...` tree, packed into
`index.pck` by the exporter — there's no separate web asset copy or
manifest to keep in sync.

---

## Recipes

### Add a background
Drop `castle.jpg` (or `castle_hard.jpg` to tag its tier) into
`godot/assets/graphics/pools/backgrounds/`, commit it and its `.import`.
Puzzles / Picture Wipe / Picture Find pick it up automatically.

### Add an Aquarium fish
Drop `octopus_0.png` + `octopus_1.png` into
`godot/assets/graphics/pools/sprites/aquarium/`, run `tools/gen-voice.sh`
(bakes `v_octopus.ogg`), commit. Optional: a `TUNING` entry in
`Aquarium.gd` for a non-default size.

### Add a Find Sound card
Drop `<pool>/<stem>.png` (pool = `animals` / `vehicles` / `instruments` /
`sounds`) **and** `godot/assets/audio/soundmemory/<stem>.ogg`, commit.

### Add a Flashcards language (e.g. Japanese)
1. Put the 12 DECK-word clips at
   `godot/assets/audio/flashcards/<word>_ja.ogg`.
2. Add `{ code: 'ja', label: '日本語', bcp: 'ja-JP' }` to the `LANGS`
   array in `godot/scripts/games/Flashcards.gd` — a button appears
   automatically.
3. Commit. Missing clips fall back to TTS in that language, so a partial
   set still works.

### Swap a piece of shared pool art (e.g. the card back)
Overwrite the file in `godot/assets/graphics/pools/<pool>/`, commit. Keep
raster pool art modestly sized (a card back tiles small on screen — 256²
is plenty).

---

## Known debt

- **The synthetic `voice/` phrase clips are Google Translate TTS** — an
  unofficial endpoint. For a fully offline, reproducible pack run
  `TTS=piper tools/gen-voice.sh` on a machine with piper + a voice model;
  the human letters/digits (`assets/audio/human/` at repo root) won't change.
- `godot/assets/graphics/pools/objects/` is named in Design-Policy §A.2
  but not yet created — no game needs a non-animal cutout pool yet.
- No `godot/assets/audio/music/` — there are no background-music tracks;
  the win/fanfare stingers live in `sfx/` and play on the Music bus.
