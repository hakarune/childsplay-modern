extends Control
## Find Sound — hear a sound, click the picture it belongs to.
##
## Each level is a themed board of pictures. A round plays one picture's
## clip; find them all to clear the level. Wrong clicks just wobble the
## card — no penalty.

const MAIN_MENU := "res://scenes/MainMenu.tscn"

# Levels + spoken-label overrides load from assets/data/findsound.json (§J);
# this is only the offline fallback.
const FALLBACK_LEVELS := [
	{ "name": "Animals",     "ids": ["cow", "elephant", "frog", "lion", "rooster", "sheep"] },
	{ "name": "Vehicles",    "ids": ["boat", "car", "plane", "police", "rocket"] },
	{ "name": "Instruments", "ids": ["drum", "flute", "guitar", "harp", "piano", "violin"] },
	{ "name": "More music",  "ids": ["banjo", "cello", "chimes", "clarinette", "didjeridu", "shenai"] },
	{ "name": "Noises",      "ids": ["alarm", "bird", "bubbles", "carhorn", "chiken", "clang", "cow", "dog"] },
	{ "name": "More noises", "ids": ["duck2", "foghorn", "frogs", "hey", "horse", "plane", "sheep", "zap"] },
]

var _levels: Array = FALLBACK_LEVELS
var _labels: Dictionary = {}

const SND_GOOD := "good.ogg"
const SND_BAD := "wrong.ogg"
const SND_WIN := "winner.ogg"

var _level_index := 0
var _tries := 0
var _found := 0
var _total := 0
var _target_id := ""
var _busy := false
var _say_names := false
var _names_btn: Button

# card = { "button": TextureButton, "id": String, "found": bool }
var _cards: Array = []

@onready var _grid: GridContainer = %CardGrid
@onready var _info_label: Label = %InfoLabel
@onready var _back_button: Button = %BackButton
@onready var _replay_button: Button = %ReplayButton
@onready var _popup: Control = %WinPopup
@onready var _popup_label: Label = %WinPopupLabel
@onready var _popup_next: Button = %WinPopupNext
@onready var _popup_replay: Button = %WinPopupReplay
@onready var _popup_menu: Button = %WinPopupMenu

@onready var _clip: AudioStreamPlayer = $Audio/ClipPlayer
@onready var _sfx_good: AudioStreamPlayer = $Audio/GoodSound
@onready var _sfx_bad: AudioStreamPlayer = $Audio/BadSound
@onready var _sfx_win: AudioStreamPlayer = $Audio/WinSound


func _ready() -> void:
	GameContext.theme_changed.connect(_style_hud)
	_style_hud()
	_sfx_good.stream = AssetLoader.get_stream(SND_GOOD)
	_sfx_bad.stream = AssetLoader.get_stream(SND_BAD)
	_sfx_win.stream = AssetLoader.get_stream(SND_WIN)

	_back_button.pressed.connect(_go_home)
	_replay_button.pressed.connect(_play_target)
	_popup_menu.pressed.connect(_go_home)
	_popup_replay.pressed.connect(func() -> void: _start_level(_level_index))
	_popup_next.pressed.connect(func() -> void: _start_level(_level_index + 1))
	_popup.visible = false

	var data := GameContext.load_json("findsound")
	if data.get("levels", []) is Array and not data.get("levels", []).is_empty():
		_levels = data["levels"]
	if data.get("labels", {}) is Dictionary:
		_labels = data["labels"]

	if GameContext.has_voice():
		_say_names = GameContext.name_toggle_get("findsound")
		_names_btn = Button.new()
		_names_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_names_btn.offset_left = -170.0
		_names_btn.offset_top = 12.0
		_names_btn.offset_right = -16.0
		_names_btn.custom_minimum_size = Vector2(154, 38)
		_names_btn.focus_mode = Control.FOCUS_ALL
		_names_btn.pressed.connect(_toggle_names)
		add_child(_names_btn)
		_sync_names_btn()

	_start_level(0)


func _toggle_names() -> void:
	_say_names = not _say_names
	GameContext.name_toggle_set("findsound", _say_names)
	_sync_names_btn()


func _sync_names_btn() -> void:
	if _names_btn:
		_names_btn.text = "🔊 names on" if _say_names else "🔇 names off"


func _start_level(index: int) -> void:
	_level_index = clampi(index, 0, _levels.size() - 1)
	var lvl: Dictionary = _levels[_level_index]
	_tries = 0
	_found = 0
	_total = lvl["ids"].size()
	_busy = false
	_target_id = ""
	_popup.visible = false

	for c in _grid.get_children():
		c.queue_free()
	_cards.clear()

	var ids: Array = lvl["ids"].duplicate()
	ids.shuffle()
	_grid.columns = 3 if ids.size() <= 6 else 4

	for id in ids:
		var button := TextureButton.new()
		button.custom_minimum_size = Vector2(190, 190)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_ALL
		button.texture_normal = AssetLoader.get_texture(id + ".png")
		button.pivot_offset = button.custom_minimum_size * 0.5
		var card := { "button": button, "id": id, "found": false }
		button.pressed.connect(_on_card_pressed.bind(card))
		_grid.add_child(button)
		_cards.append(card)

	_update_info()
	_next_round()


func _next_round() -> void:
	var remaining: Array = _cards.filter(func(c): return not c["found"])
	if remaining.is_empty():
		_on_level_complete()
		return
	_target_id = remaining[randi() % remaining.size()]["id"]
	_play_target()


func _play_target() -> void:
	if _target_id == "":
		return
	var stream := AssetLoader.get_stream(_target_id + ".ogg")
	if stream:
		_clip.stream = stream
		_clip.play()


func _on_card_pressed(card: Dictionary) -> void:
	if _busy or card["found"] or _popup.visible:
		return

	if card["id"] == _target_id:
		card["found"] = true
		_found += 1
		card["button"].disabled = true
		card["button"].modulate = Color(1, 1, 1, 0.55)
		_play(_sfx_good)
		if _say_names:
			GameContext.speak(str(_labels.get(card["id"], GameContext.name_from_id(card["id"]))))
		_update_info()
		_next_round()
	else:
		_tries += 1
		_play(_sfx_bad)
		_wobble(card["button"])


func _wobble(button: Control) -> void:
	var t := create_tween()
	t.tween_property(button, "rotation", 0.08, 0.05)
	t.tween_property(button, "rotation", -0.08, 0.08)
	t.tween_property(button, "rotation", 0.0, 0.05)


func _on_level_complete() -> void:
	_busy = true
	_target_id = ""
	_play(_sfx_win)
	var is_last := _level_index >= _levels.size() - 1
	_popup_label.text = "You found them all!\n%d wrong tap%s" % [_tries, "" if _tries == 1 else "s"]
	_popup_next.visible = not is_last
	_popup.visible = true
	(_popup_replay if is_last else _popup_next).grab_focus()


func _update_info() -> void:
	_info_label.text = "Found %d / %d      Level %d / %d  -  %s" % [
		_found, _total, _level_index + 1, _levels.size(), _levels[_level_index]["name"]
	]


func _play(player: AudioStreamPlayer) -> void:
	if player.stream != null:
		player.play()


func _go_home() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_home()


## Themed HUD bar + divider (Design Policy §G).
func _style_hud() -> void:
	GameContext.style_hud_bar(self, 80.0, [_info_label], [])
