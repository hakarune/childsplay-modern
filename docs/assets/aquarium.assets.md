<!-- Per-game graphics declaration — Design Policy §A.7.
     Hand-edit freely; keep it in sync in the commit that changes art. -->

# `aquarium` — graphics declaration

| Field | Value |
| --- | --- |
| Game id | `aquarium` (aquarium.js / Aquarium.tscn) |
| Owns any art? | no |
| Shared pools used | `sprites/aquarium` (2-frame fish), `backgrounds/aquarium_*` (photo texture layer), `ui/bubble`. |
| Content file(s) | — (none) |
| Theme variants | light+dark: backdrop gradient has both; fish art is theme-agnostic |
| Style themes | none (a `modern` overlay dir may add SVG fish later) |

## Assets

| Logical name | Pool / path (no ext) | Formats | Native px | Target box (world units) | Aspect / fit | Difficulty tag | Licence / source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| fish frames | sprites/aquarium/`<name>`_0 , _1 | png (svg drop-in ok) | 62x50 … 266x91 | ≤ base*scale, contain | per sprite | — (toy, no levels) | GPL, legacy `FishtankData` |

> The sprite stem **is** the fish name (hyphens → spaces for the spoken /
> floating label); the roster is a runtime scan of the pool, and
> `gen-voice.sh` bakes `v_<name>.ogg` from the same file list, so adding a
> fish is just dropping `<name>_0.png` + `<name>_1.png`. `TUNING` in
> `aquarium.js` / `Aquarium.gd` is an optional per-name size/rarity
> override.
| bubble | ui/bubble | png | 35x60 | ≤ 18 sq, contain | ~1:1.7 | — | GPL-3 |
| tank photo layer | backgrounds/aquarium_1 … _6 | jpg | ~800x600 | cover, 0.38 alpha | ~4:3 | — | GPL, legacy `FishtankData/backgrounds` |

## Notes

- Native px is the real pixel size of the largest raster in the set.
- Target box is the max on-screen size in world units (1280×720 ref); the
  renderer letterboxes inside it.
- Art is referenced without an extension — `svg` wins over `png`/`jpg`, so a
  newer vector can be dropped in beside the raster (Policy §C.2).
