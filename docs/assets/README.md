# Per-game graphics declarations

One file per game, required by **[Design Policy §A.7](../Design-Policy.md)**:
what art each activity draws, where it lives, native pixel size, on-screen
box, difficulty tag, and licence/source. Template:
[../templates/ASSETS.template.md](../templates/ASSETS.template.md).

Keep a file in sync in the **same commit** that changes that game's art.

Most games own no art — they draw from the shared purpose pools
(`assets/graphics/pools/`) or are drawn procedurally from palette roles.
The ones that reference a bundled data file:

| Game | Data file |
| --- | --- |
| Puzzle, Wipe | — difficulty is a `_easy/_med/_hard` tag on the `backgrounds/` filename |
| Electro | `assets/data/electro.json` — picture↔name pairs |
| Find Sound | — a level is a graphics pool folder; picture & clip pair by stem |
| Quiz | `assets/data/quiz/*.json` — one file per deck |
| Word Maker | `assets/data/wordlist.json` — kid dictionary |

Alternate-art overlays (Policy §C.4) go in
`assets/graphics/themes/<style>/<pool>/<name>` and win over the base pool
when that art style is selected in the launcher chrome.
