extends Node
## GameContext — small autoload shared by every scene.
##
##  * hands a choice to the next scene (change_scene_to_file can't pass args)
##  * owns the light/dark colour palette (Design Policy §D)
##  * shared no-repeat asset-pool draw (Design Policy §B)
##  * one text-to-speech entry point (Design Policy §E.2)

# --- next-scene handoff --------------------------------------------------
## One of: "pictures", "lower", "upper", "numbers"
var memory_variant := "pictures"
## A quiz deck id — the stem of assets/data/quiz/<deck>.json
var quiz_deck := "general"

# --- theme / palette (§D) ---------------------------------------------------
signal theme_changed

const SETTINGS_PATH := "user://settings.cfg"

const PALETTE_DARK := {
	"bg": Color("12161f"), "surface": Color("232c3d"), "surface_alt": Color("374663"),
	"text": Color("eef2f7"), "text_muted": Color("a6b8d6"),
	"accent": Color("5b8cff"), "accent_press": Color("3a63d0"),
	"good": Color("6ee38a"), "bad": Color("ff6b6b"), "warn": Color("ffb454"),
	"line": Color("5a7bb5"), "overlay_scrim": Color(0.016, 0.027, 0.047, 0.66),
	"p1": Color("ff6b6b"), "p2": Color("ffd93d"),
	"hud": Color("34435d"), "hud_text": Color("f2f5fa"), "hud_muted": Color("b7c6e0"),
	"card": Color("f4f6fb"), "card_ink": Color("1a2330"), "board": Color("0a1524"),
}
const PALETTE_LIGHT := {
	"bg": Color("eef1f6"), "surface": Color("ffffff"), "surface_alt": Color("d7e0f2"),
	"text": Color("1a2330"), "text_muted": Color("525d70"),
	"accent": Color("2f5fe0"), "accent_press": Color("1f43b0"),
	"good": Color("137a37"), "bad": Color("c62f2f"), "warn": Color("9a5b00"),
	"line": Color("7183a8"), "overlay_scrim": Color(0.047, 0.067, 0.102, 0.55),
	"p1": Color("c62f2f"), "p2": Color("b07500"),
	"hud": Color("c6d1e5"), "hud_text": Color("1a2330"), "hud_muted": Color("4a566b"),
	"card": Color("ffffff"), "card_ink": Color("1a2330"), "board": Color("12314e"),
}

var theme_mode := "dark"
var palette: Dictionary = PALETTE_DARK.duplicate()

## Colour role accessor. Games call `GameContext.c("bg")`.
func c(role: String) -> Color:
	return palette.get(role, Color.MAGENTA)

func set_theme(mode: String) -> void:
	theme_mode = "light" if mode == "light" else "dark"
	palette = (PALETTE_LIGHT if theme_mode == "light" else PALETTE_DARK).duplicate()
	_save_settings()
	theme_changed.emit()

func toggle_theme() -> void:
	set_theme("dark" if theme_mode == "light" else "light")


## In-game HUD bar (Design Policy §G) — paint a real `hud` surface with a
## `line` divider behind the top chrome so it reads against the play area
## in BOTH palettes, and colour the HUD labels (`hud_text` / `hud_muted`).
## Idempotent: call from _ready() AND from the game's theme_changed handler.
##   text  — labels shown in the primary HUD colour
##   muted — secondary / hint labels
func style_hud_bar(host: Control, hud_h: float, text: Array = [], muted: Array = []) -> void:
	var bg: ColorRect = host.get_node_or_null("HudBarBg")
	if bg == null:
		bg = ColorRect.new()
		bg.name = "HudBarBg"
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
		host.add_child(bg)
		host.move_child(bg, 1)                 # just above the Background rect
	bg.offset_bottom = hud_h
	bg.color = c("hud")

	var line: ColorRect = host.get_node_or_null("HudBarLine")
	if line == null:
		line = ColorRect.new()
		line.name = "HudBarLine"
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.set_anchors_preset(Control.PRESET_TOP_WIDE)
		host.add_child(line)
		host.move_child(line, 2)
	line.offset_top = hud_h - 1.0
	line.offset_bottom = hud_h
	line.color = c("line")

	for l in text:
		if l is Label:
			l.add_theme_color_override("font_color", c("hud_text"))
	for l in muted:
		if l is Label:
			l.add_theme_color_override("font_color", c("hud_muted"))


func _ready() -> void:
	_load_settings()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		theme_mode = str(cfg.get_value("ui", "theme", "dark"))
	palette = (PALETTE_LIGHT if theme_mode == "light" else PALETTE_DARK).duplicate()

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)               # keep other keys
	cfg.set_value("ui", "theme", theme_mode)
	cfg.save(SETTINGS_PATH)


# --- no-repeat asset-pool draw (§B) --------------------------------------
# key -> shuffled Array of remaining candidates. Cleared per game via
# reset_pools(prefix) when a game (re)launches.
var _bags: Dictionary = {}

## Draw `n` distinct entries from `candidates`, without repeating any until
## the pool is exhausted, then reshuffle. `key` scopes the memory (use a
## bare pool name like "backgrounds:med" for pools shared between games).
func draw_from_pool(key: String, candidates: Array, n := 1) -> Array:
	var out: Array = []
	for _i in n:
		var bag: Array = _bags.get(key, [])
		if bag.is_empty():
			bag = candidates.duplicate()
			bag.shuffle()
		out.append(bag.pop_back())
		_bags[key] = bag
	return out

func reset_pools(prefix := "") -> void:
	if prefix == "":
		_bags.clear()
		return
	for k in _bags.keys():
		if str(k).begins_with(prefix):
			_bags.erase(k)


## Draw `n` distinct entries from the subset of `candidates` whose difficulty
## tier (looked up in `tier_of`: item -> "easy"|"med"|"hard") equals `tier`.
## Items missing from `tier_of` are eligible at every tier. Each tier keeps
## its own no-repeat memory under `<pool_key>:<tier>` so Puzzle and Wipe
## sharing the paintings pool never repeat a picture in a session (§B.4).
func draw_tiered(pool_key: String, candidates: Array, tier_of: Dictionary, tier: String, n := 1) -> Array:
	var eligible: Array = []
	for item in candidates:
		var t: String = str(tier_of.get(item, ""))
		if t == "" or t == tier:
			eligible.append(item)
	if eligible.is_empty():
		eligible = candidates.duplicate()
	return draw_from_pool("%s:%s" % [pool_key, tier], eligible, n)


# --- JSON data files (§J) ------------------------------------------------
var _json_cache: Dictionary = {}

## Load & cache a data file. Accepts "backgrounds" or a full res:// path;
## returns the parsed Dictionary, or {} on any failure.
func load_json(name: String) -> Dictionary:
	var path := name
	if not path.begins_with("res://"):
		path = "res://assets/data/%s.json" % name
	if _json_cache.has(path):
		return _json_cache[path]
	var out: Dictionary = {}
	if FileAccess.file_exists(path):
		var txt := FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(txt)
		if parsed is Dictionary:
			out = parsed
	_json_cache[path] = out
	return out


# --- "say this" (§E) --------------------------------------------------------
# Baked clips first (res://…/voice/<slug>.ogg via tools/gen-voice.sh), then
# live DisplayServer TTS, then silence. Respects nothing here — the menu's
# voice-mute would gate at the bus, TODO when the Godot menu grows a 3-way
# mute. Slug MUST match tts.js `slug()` and tools/gen-voice.sh `slug()`.
var _tts_voice := ""
var _voice_player: AudioStreamPlayer

func _slug(text: String) -> String:
	var out := ""
	var prev_dash := true
	for ch in text.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
			prev_dash = false
		elif not prev_dash:
			out += "-"
			prev_dash = true
	out = out.rstrip("-")
	return out.substr(0, 48)

func speak(text: String, lang_hint := "") -> void:
	if text == "":
		return
	# 1) baked clip
	var al := get_node_or_null("/root/AssetLoader")
	# Voice channel off -> stay silent (also covers live TTS, which no bus can mute).
	if al != null and al.has_method("is_channel_muted") and al.is_channel_muted("voice"):
		return
	if al != null and al.has_method("has_stream") and al.has_stream("v_" + _slug(text) + ".ogg"):
		var st: AudioStream = al.get_stream("v_" + _slug(text) + ".ogg")
		if st != null:
			if _voice_player == null:
				_voice_player = AudioStreamPlayer.new()
				_voice_player.bus = "Voice" if AudioServer.get_bus_index("Voice") >= 0 else "Master"
				add_child(_voice_player)
			_voice_player.stream = st
			_voice_player.play()
			return
	# 2) live TTS
	if not DisplayServer.has_method("tts_get_voices"):
		return
	var voices: Array = DisplayServer.tts_get_voices()
	if voices.is_empty():
		return
	var voice := _tts_voice
	if lang_hint != "":
		var m := DisplayServer.tts_get_voices_for_language(lang_hint)
		if m.size() > 0:
			voice = m[0]
	if voice == "":
		voice = voices[0].get("id", "") if voices[0] is Dictionary else str(voices[0])
	if voice == "":
		return
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, voice)

## We ship baked clips, so a speaker button is always worth showing.
func has_voice() -> bool:
	return true


# --- "say the names" toggle (§E.3) -------------------------------------
# A per-game OFF-by-default switch: OFF = sound effect only, ON = the game
# also speak()s an entity's name on interaction. Persisted in settings.cfg
# under [names]. Games cache the bool and redraw the pill via draw_name_pill.

func name_toggle_get(game_id: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		return bool(cfg.get_value("names", game_id, false))
	return false


func name_toggle_set(game_id: String, on: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("names", game_id, on)
	cfg.save(SETTINGS_PATH)


## Friendlier spoken labels for pool ids whose auto-name reads oddly.
## Keyed on the result of the generic tidy below.
const NAME_OVERRIDES := {
	"bluebaby": "baby blue bird",
	"greenbaby": "baby green bird",
}

## Tidy a pool id ("01_cat", "car_horn") into a spoken label.
func name_from_id(id: String) -> String:
	var s := id
	var us := s.find("_")
	if us >= 0 and s.substr(0, us).is_valid_int():
		s = s.substr(us + 1)
	s = s.replace("_", " ").replace("-", " ").strip_edges()
	return NAME_OVERRIDES.get(s, s)


## Draw the toggle pill. Nothing is drawn where the platform has no voice.
func draw_name_pill(ci: CanvasItem, rect: Rect2, on: bool) -> void:
	if not has_voice():
		return
	var font := ThemeDB.fallback_font
	ci.draw_rect(rect, c("accent") if on else c("surface"))
	var label := "names on" if on else "names off"
	var fs := 15
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(font, rect.position + Vector2((rect.size.x - tw) / 2.0, rect.size.y * 0.66),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE if on else c("text"))
