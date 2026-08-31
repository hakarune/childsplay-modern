extends Node
## AssetLoader — AutoLoad singleton.
##
## Scans res://assets/ once at boot and builds a filename -> resource-path
## index for every texture and audio file, so activities can ask for
## "cherry.png" or "wahoo.wav" without knowing where in the tree it lives.
##
## Resources are loaded lazily and then cached, so the first request for an
## asset pays the load cost and every request after is a Dictionary hit.
##
## Audio is routed to one of three buses (SFX / Voice / Music) chosen from
## the file's path, with a per-call override available.

const ASSET_ROOT := "res://assets"

# Resolution order (Design Policy §C.2): a newer `castle.svg` dropped next to
# `castle.jpg` wins. IMAGE_EXTS is listed best-first and EXT_PRIORITY lets
# _register() prefer the higher-priority extension on a name collision
# instead of just keeping whichever the directory walk hit first.
const IMAGE_EXTS := ["svg", "png", "jpg", "jpeg", "webp"]
const EXT_PRIORITY := {"svg": 0, "png": 1, "jpg": 2, "jpeg": 3, "webp": 4}
const AUDIO_EXTS := ["ogg", "wav", "mp3"]

# Optional alternate-art overlay (Design Policy §C.4). Art placed under
# res://assets/graphics/themes/<style>/<pool>/<name>.<ext> is indexed with a
# style-relative key ("themes/<style>/<name>") and, when art_style is set to
# that style, wins over the base pool. "classic" = base pools only.
const ART_STYLE_DEFAULT := "classic"
var art_style := ART_STYLE_DEFAULT

const BUS_SFX := "SFX"
const BUS_VOICE := "Voice"
const BUS_MUSIC := "Music"

# Per-channel mute is persisted here and mirrors the web 3-way sound
# popover (Design Policy §E.3): channel name -> audio bus it gates.
const SETTINGS_PATH := "user://settings.cfg"
const CHANNEL_BUSES := {"music": BUS_MUSIC, "sfx": BUS_SFX, "voice": BUS_VOICE}

# Number of pooled AudioStreamPlayers for overlapping one-shot sounds.
const SFX_VOICE_POOL := 12

# --- indexes: lower-case filename -> res:// path -----------------------------
var _texture_paths: Dictionary = {}
var _audio_paths: Dictionary = {}

# --- caches: path -> loaded resource ---------------------------------------
var _texture_cache: Dictionary = {}
var _audio_cache: Dictionary = {}

# --- audio playback -------------------------------------------------------
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _music_player: AudioStreamPlayer

var _indexed_textures := 0
var _indexed_audio := 0
var _collision_count := 0
var _collision_sample: PackedStringArray = []

# Guards against counting an asset twice when both "foo.png" and its
# "foo.png.import" sidecar show up in the same directory scan.
var _seen_paths := {}


## Fired when set_art_style() changes the active alternate-art style, so the
## menu and any texture-drawing scene can reload their art.
signal art_style_changed


func _ready() -> void:
	_build_audio_players()
	_load_audio_settings()
	_load_art_style()
	var start := Time.get_ticks_msec()
	_scan_dir(ASSET_ROOT)
	_seen_paths.clear()
	var elapsed := Time.get_ticks_msec() - start
	print("[AssetLoader] indexed %d textures, %d audio files from %s in %d ms"
		% [_indexed_textures, _indexed_audio, ASSET_ROOT, elapsed])
	if _collision_count > 0:
		# Expected: the legacy tree ships the same filename under many
		# themes/locales. First match wins (childsplay theme sorts first).
		var more := _collision_count - _collision_sample.size()
		var tail := " (+%d more)" % more if more > 0 else ""
		print("[AssetLoader] %d duplicate filenames, first match kept: %s%s"
			% [_collision_count, ", ".join(_collision_sample), tail])


# ---------------------------------------------------------------------------
# Indexing
# ---------------------------------------------------------------------------

func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("[AssetLoader] cannot open %s (err %d)" % [path, DirAccess.get_open_error()])
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue

		var full := path.path_join(entry)
		if dir.current_is_dir():
			_scan_dir(full)
		else:
			_index_file(full, entry)
		entry = dir.get_next()
	dir.list_dir_end()


func _index_file(full_path: String, file_name: String) -> void:
	# Godot writes a "<asset>.import" / "<asset>.remap" sidecar next to each
	# imported file. Strip that suffix so both the real file and its sidecar
	# resolve to the same asset path...
	var clean := full_path
	if clean.ends_with(".import") or clean.ends_with(".remap"):
		clean = clean.get_basename()
		file_name = file_name.get_basename()

	# ...then skip anything already indexed this scan.
	if _seen_paths.has(clean):
		return
	_seen_paths[clean] = true

	var ext := clean.get_extension().to_lower()
	var key := file_name.to_lower()

	# Alternate-art overlay files keep a style-relative key so they don't
	# collide with (or overwrite) the base pool entry of the same name.
	var theme_key := _theme_relative_key(clean)

	if ext in IMAGE_EXTS:
		if theme_key != "":
			_register(_texture_paths, theme_key, clean)
		else:
			_register(_texture_paths, key, clean)
		_indexed_textures += 1
	elif ext in AUDIO_EXTS:
		_register(_audio_paths, key, clean)
		_indexed_audio += 1


## "res://assets/graphics/themes/<style>/<pool>/<name>.png" -> "themes/<style>/<name>".
## "" for anything not under a themes/ dir.
func _theme_relative_key(path: String) -> String:
	var parts := path.split("/")
	var ti := parts.find("themes")
	if ti == -1 or ti + 2 >= parts.size():
		return ""
	var style: String = parts[ti + 1].to_lower()
	var stem: String = parts[parts.size() - 1].get_basename().to_lower()
	return "themes/%s/%s" % [style, stem]


func _register(index: Dictionary, key: String, path: String) -> void:
	if index.has(key):
		# Same name, different file. Prefer the higher-priority extension
		# (svg > png > jpg > …, Policy §C.2); on a tie prefer a file in the
		# flat purpose pools (Policy §A) over a stray legacy copy; failing
		# that keep the first seen.
		var old_path := String(index[key])
		var old_ext := old_path.get_extension().to_lower()
		var new_ext := path.get_extension().to_lower()
		var old_p: int = EXT_PRIORITY.get(old_ext, 99)
		var new_p: int = EXT_PRIORITY.get(new_ext, 99)
		_collision_count += 1
		if _collision_sample.size() < 12:
			_collision_sample.append(key)
		var replace := new_p < old_p
		if new_p == old_p:
			replace = path.contains("/pools/") and not old_path.contains("/pools/")
		if replace:
			index[key] = path
			var s := key.get_basename()
			if s != key:
				index[s] = path
		return
	index[key] = path
	# Also index without the extension for convenience (e.g. "cherry").
	var stem := key.get_basename()
	if stem != key and not index.has(stem):
		index[stem] = path


# ---------------------------------------------------------------------------
# Textures
# ---------------------------------------------------------------------------

## Return a Texture2D for `asset_name` ("cherry.png" or "cherry"), or null.
## When art_style != "classic", an overlay file of the same name (indexed as
## "themes/<style>/<name>") is used in preference to the base pool entry.
func get_texture(asset_name: String) -> Texture2D:
	var key := asset_name.to_lower()

	if art_style != ART_STYLE_DEFAULT:
		var stem := key.get_basename() if key.get_extension() != "" else key
		var overlay := "themes/%s/%s" % [art_style, stem]
		if _texture_paths.has(overlay):
			key = overlay

	if not _texture_paths.has(key):
		push_warning("[AssetLoader] missing texture: '%s'" % asset_name)
		return null

	var path: String = _texture_paths[key]
	if _texture_cache.has(path):
		return _texture_cache[path]

	var res := ResourceLoader.load(path)
	if res is Texture2D:
		_texture_cache[path] = res
		return res

	push_warning("[AssetLoader] failed to load texture: %s" % path)
	return null


func has_texture(asset_name: String) -> bool:
	return _texture_paths.has(asset_name.to_lower())


func has_stream(sound_name: String) -> bool:
	return _audio_paths.has(sound_name.to_lower())


# ---------------------------------------------------------------------------
# Audio
# ---------------------------------------------------------------------------

## Return an AudioStream for `sound_name`, or null (with a warning).
func get_stream(sound_name: String) -> AudioStream:
	var key := sound_name.to_lower()
	if not _audio_paths.has(key):
		push_warning("[AssetLoader] missing sound: '%s'" % sound_name)
		return null

	var path: String = _audio_paths[key]
	if _audio_cache.has(path):
		return _audio_cache[path]

	var res := ResourceLoader.load(path)
	if res is AudioStream:
		_audio_cache[path] = res
		return res

	push_warning("[AssetLoader] failed to load sound: %s" % path)
	return null


## Play a one-shot sound through the pooled players.
## `bus_override` forces a bus; otherwise it is inferred from the path.
func play_sound(sound_name: String, bus_override: String = "") -> void:
	var stream := get_stream(sound_name)
	if stream == null:
		return  # get_stream already logged the miss

	var bus := bus_override
	if bus.is_empty():
		bus = _bus_for_path(_audio_paths[sound_name.to_lower()])

	var player := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	player.stop()
	player.stream = stream
	player.bus = bus
	player.play()


## Start (or swap) looping background music on the Music bus.
func play_music(sound_name: String, loop: bool = true) -> void:
	var stream := get_stream(sound_name)
	if stream == null:
		return
	if "loop" in stream:
		stream.loop = loop
	_music_player.stream = stream
	_music_player.bus = BUS_MUSIC
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


## Stop EVERY sound this autoload is playing, plus any active speech.
## Called on every scene change so nothing outlives its game (Policy §E.1).
func stop_all() -> void:
	for p in _sfx_pool:
		if is_instance_valid(p):
			p.stop()
	if is_instance_valid(_music_player):
		_music_player.stop()
	if DisplayServer.has_method("tts_stop"):
		DisplayServer.tts_stop()


func _bus_for_path(path: String) -> String:
	var p := path.to_lower()
	if p.contains("alphabetsounds") or p.contains("flashcards") \
			or p.contains("voice") or p.contains("/speech") or p.contains("spoken"):
		return BUS_VOICE
	if p.contains("music") or p.contains("/bgm") or p.contains("background"):
		return BUS_MUSIC
	return BUS_SFX


# ---------------------------------------------------------------------------
# Bus helpers (used by the settings toggle in MainMenu)
# ---------------------------------------------------------------------------

func set_master_muted(muted: bool) -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)


func is_master_muted() -> bool:
	var idx := AudioServer.get_bus_index("Master")
	return idx >= 0 and AudioServer.is_bus_mute(idx)


## Mute / unmute one channel (Music / SFX / Voice). Persisted to
## settings.cfg under [audio] as an "on" bool for readability. The Voice
## channel also gates live TTS via GameContext.speak().
func set_channel_muted(channel: String, muted: bool) -> void:
	var bus_name: String = CHANNEL_BUSES.get(channel, "")
	if bus_name == "":
		return
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)          # keep other keys (theme, …)
	cfg.set_value("audio", channel, not muted)
	cfg.save(SETTINGS_PATH)


func is_channel_muted(channel: String) -> bool:
	var bus_name: String = CHANNEL_BUSES.get(channel, "")
	if bus_name == "":
		return false
	var idx := AudioServer.get_bus_index(bus_name)
	return idx >= 0 and AudioServer.is_bus_mute(idx)


func _load_audio_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for channel in CHANNEL_BUSES:
		var on := bool(cfg.get_value("audio", channel, true))
		var idx := AudioServer.get_bus_index(CHANNEL_BUSES[channel])
		if idx >= 0:
			AudioServer.set_bus_mute(idx, not on)


# ---------------------------------------------------------------------------
# Alternate-art style (Design Policy §C.4)
# ---------------------------------------------------------------------------

## Styles that actually have art on disk under assets/graphics/themes/, plus
## the always-present "classic". Order is menu order.
func list_art_styles() -> PackedStringArray:
	var found: Array[String] = [ART_STYLE_DEFAULT]
	for key in _texture_paths.keys():
		var k := String(key)
		if k.begins_with("themes/"):
			var style := k.split("/")[1]
			if not found.has(style):
				found.append(style)
	return PackedStringArray(found)


func has_art_style(style: String) -> bool:
	return style == ART_STYLE_DEFAULT or list_art_styles().has(style)


func set_art_style(style: String) -> void:
	var s := style.to_lower()
	if not has_art_style(s):
		s = ART_STYLE_DEFAULT
	if s == art_style:
		return
	art_style = s
	_texture_cache.clear()                 # base <-> overlay swap
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)                 # keep other keys
	cfg.set_value("ui", "art_style", art_style)
	cfg.save(SETTINGS_PATH)
	art_style_changed.emit()


func _load_art_style() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		art_style = str(cfg.get_value("ui", "art_style", ART_STYLE_DEFAULT))


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _build_audio_players() -> void:
	for i in SFX_VOICE_POOL:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		p.bus = BUS_SFX
		add_child(p)
		_sfx_pool.append(p)

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "Music"
	_music_player.bus = BUS_MUSIC
	add_child(_music_player)
