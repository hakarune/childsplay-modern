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
}
const PALETTE_LIGHT := {
	"bg": Color("eef1f6"), "surface": Color("ffffff"), "surface_alt": Color("d7e0f2"),
	"text": Color("1a2330"), "text_muted": Color("525d70"),
	"accent": Color("2f5fe0"), "accent_press": Color("1f43b0"),
	"good": Color("137a37"), "bad": Color("c62f2f"), "warn": Color("9a5b00"),
	"line": Color("7183a8"), "overlay_scrim": Color(0.047, 0.067, 0.102, 0.55),
	"p1": Color("c62f2f"), "p2": Color("b07500"),
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
	if al != null:
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
