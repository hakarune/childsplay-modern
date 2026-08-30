extends Control
## FallingLetter — type the letter on each balloon before it reaches the
## ground. Input: a physical keyboard, or the on-screen keyboard (kept as
## the accessibility path, Design Policy §I.3). Six levels with a gentle
## first tier; out of lives just replays the level (§H.1.3).

const MAIN_MENU := "res://scenes/MainMenu.tscn"
const LETTER_SCENE := preload("res://scenes/components/LetterItem.tscn")

const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const KB_ROWS := ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]

const DANGER_ZONE_H := 90.0
const KB_H := 196.0

# ≥ 6 tiers, gentle "Warm up" first level, every knob ramps monotonically
# (§H.1 / §H.2). Fall speed still creeps up a little within a level.
const LEVELS := [
	{ "name": "Warm up",  "speed": 46.0,  "spawn": 3.3,  "lives": 5 },
	{ "name": "Easy",     "speed": 62.0,  "spawn": 2.8,  "lives": 4 },
	{ "name": "Steady",   "speed": 80.0,  "spawn": 2.3,  "lives": 3 },
	{ "name": "Quicker",  "speed": 104.0, "spawn": 1.9,  "lives": 3 },
	{ "name": "Fast",     "speed": 132.0, "spawn": 1.6,  "lives": 3 },
	{ "name": "Blizzard", "speed": 164.0, "spawn": 1.35, "lives": 3 },
]
const POPS_PER_LEVEL := 12
const SPEED_CREEP := 2.2
const SPEED_CREEP_MAX := 80.0

const BUBBLE_COLORS := [
	Color("ff6b6b"), Color("ffd93d"), Color("6bcB77"),
	Color("4d96ff"), Color("b980f0"), Color("ff9f45"),
]

const SND_SPAWN := "pick.wav"
const SND_HIT := "zap.ogg"
const SND_MISS := "bump.wav"
const SND_END := "winner.ogg"

const HEART_FULL := "♥"
const HEART_EMPTY := "♡"

const SETTINGS_PATH := "user://settings.cfg"

var _level := 0
var _level_score := 0          # pops this level
var _total := 0                # pops all game
var _lives := 3
var _lives_max := 3
var _active := false
var _end_mode := ""            # "" | "lose" | "win"
var _letters: Array[LetterItem] = []

var _osk := false             # true = rely on device keyboard, hide the on-screen one
var _ground_y := 630.0
var _kb_panel: PanelContainer
var _kb_buttons: Array[Button] = []
var _kb_toggle: Button

@onready var _play_area: Control = %PlayArea
@onready var _danger_zone: ColorRect = $PlayArea/DangerZone
@onready var _ground_line: ColorRect = $PlayArea/GroundLine
@onready var _score_label: Label = %ScoreLabel
@onready var _lives_box: HBoxContainer = %LivesBox
@onready var _back_button: Button = %BackButton
@onready var _spawn_timer: Timer = %SpawnTimer
@onready var _game_over_panel: Control = %GameOverPanel
@onready var _summary: Label = %GameOverSummary
@onready var _play_again: Button = %PlayAgainButton
@onready var _menu_button: Button = %MenuButton

@onready var _sfx_spawn: AudioStreamPlayer = $Audio/SpawnSound
@onready var _sfx_hit: AudioStreamPlayer = $Audio/HitSound
@onready var _sfx_miss: AudioStreamPlayer = $Audio/MissSound
@onready var _sfx_end: AudioStreamPlayer = $Audio/EndSound


func _ready() -> void:
	_sfx_spawn.stream = AssetLoader.get_stream(SND_SPAWN)
	_sfx_hit.stream = AssetLoader.get_stream(SND_HIT)
	_sfx_miss.stream = AssetLoader.get_stream(SND_MISS)
	_sfx_end.stream = AssetLoader.get_stream(SND_END)

	_back_button.pressed.connect(_go_home)
	_menu_button.pressed.connect(_go_home)
	_play_again.pressed.connect(_on_play_again)
	_spawn_timer.timeout.connect(_on_spawn_timer)
	resized.connect(_recompute_ground)

	_load_osk()
	_build_keyboard()
	_build_toggle()
	_recompute_ground()

	_start_game()


# ---------------------------------------------------------------------------
# Round lifecycle
# ---------------------------------------------------------------------------

func _start_game() -> void:
	_total = 0
	_start_level(0)


func _start_level(n: int) -> void:
	for letter in _letters:
		if is_instance_valid(letter):
			letter.queue_free()
	_letters.clear()

	_level = clampi(n, 0, LEVELS.size() - 1)
	var lv: Dictionary = LEVELS[_level]
	_level_score = 0
	_lives_max = int(lv["lives"])
	_lives = _lives_max
	_active = true
	_end_mode = ""
	_game_over_panel.visible = false
	_rebuild_lives()
	_update_hud()

	_spawn_timer.wait_time = float(lv["spawn"])
	_spawn_timer.start()
	_spawn_letter()


func _advance() -> void:
	if _level >= LEVELS.size() - 1:
		_win()
	else:
		_start_level(_level + 1)


func _win() -> void:
	_active = false
	_spawn_timer.stop()
	_end_mode = "win"
	for letter in _letters:
		if is_instance_valid(letter):
			letter.freeze()
	_play(_sfx_end)
	_summary.text = "You did it!  %d letter%s caught" % [_total, "" if _total == 1 else "s"]
	_play_again.text = "Play Again"
	_game_over_panel.visible = true
	_play_again.grab_focus()


# Out of lives: no ejection — replay this level (§H.1.3).
func _lose_level() -> void:
	_active = false
	_spawn_timer.stop()
	_end_mode = "lose"
	for letter in _letters:
		if is_instance_valid(letter):
			letter.freeze()
	_play(_sfx_miss)
	_summary.text = "Let's try level %d again" % (_level + 1)
	_play_again.text = "Try Again"
	_game_over_panel.visible = true
	_play_again.grab_focus()


func _on_play_again() -> void:
	if _end_mode == "lose":
		_start_level(_level)
	else:
		_start_game()


# ---------------------------------------------------------------------------
# Spawning & difficulty
# ---------------------------------------------------------------------------

func _on_spawn_timer() -> void:
	if _active:
		_spawn_letter()


func _spawn_letter() -> void:
	var letter: LetterItem = LETTER_SCENE.instantiate()
	var ch := ALPHABET[randi() % ALPHABET.length()]
	var area := _play_area.size
	var max_x: float = maxf(0.0, area.x - LetterItem.SIZE.x)

	_play_area.add_child(letter)
	letter.position = Vector2(randf_range(0.0, max_x), -LetterItem.SIZE.y)
	letter.setup(ch, _current_speed(), _ground_y, BUBBLE_COLORS.pick_random())
	letter.missed.connect(_on_letter_missed)
	_letters.append(letter)

	_play(_sfx_spawn)
	_spawn_timer.wait_time = _current_spawn_interval()


func _current_speed() -> float:
	var base: float = LEVELS[_level]["speed"]
	return minf(base + SPEED_CREEP_MAX, base + _level_score * SPEED_CREEP)


func _current_spawn_interval() -> float:
	return maxf(1.0, float(LEVELS[_level]["spawn"]) - _level_score * 0.03)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_home()
		return

	if not _active:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	var key: int = event.keycode
	if key >= KEY_A and key <= KEY_Z:
		_try_hit(String.chr(key))
		get_viewport().set_input_as_handled()


## Pop the lowest on-screen balloon whose letter matches `ch`.
func _try_hit(ch: String) -> void:
	if not _active:
		return
	_flash_key(ch)
	var target: LetterItem = null
	for letter in _letters:
		if not is_instance_valid(letter):
			continue
		if letter.target_char == ch and (target == null or letter.position.y > target.position.y):
			target = letter

	if target == null:
		return  # no match: no penalty

	_letters.erase(target)
	target.pop()
	_level_score += 1
	_total += 1
	_update_hud()
	_play(_sfx_hit)
	if _level_score >= POPS_PER_LEVEL:
		_advance()


func _on_letter_missed(letter: LetterItem) -> void:
	_letters.erase(letter)
	if not _active:
		return
	_lives -= 1
	_play(_sfx_miss)
	_update_lives()
	if _lives <= 0:
		_lose_level()


# ---------------------------------------------------------------------------
# On-screen keyboard (§I.3 accessibility path)
# ---------------------------------------------------------------------------

func _build_keyboard() -> void:
	_kb_panel = PanelContainer.new()
	_kb_panel.name = "Keyboard"
	_kb_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_kb_panel.offset_top = -KB_H
	_kb_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_kb_panel)

	var sb := StyleBoxFlat.new()
	sb.bg_color = GameContext.c("hud")
	sb.set_border_width_all(0)
	sb.border_width_top = 2
	sb.border_color = GameContext.c("line")
	_kb_panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_kb_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	for row_str in KB_ROWS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(row)
		for i in String(row_str).length():
			var ch: String = String(row_str)[i]
			var b := Button.new()
			b.text = ch
			b.custom_minimum_size = Vector2(64, 52)   # ≥ 44 touch target
			b.focus_mode = Control.FOCUS_NONE          # don't steal gameplay focus
			b.add_theme_font_size_override("font_size", 24)
			b.pressed.connect(_try_hit.bind(ch))
			row.add_child(b)
			_kb_buttons.append(b)


func _build_toggle() -> void:
	_kb_toggle = Button.new()
	_kb_toggle.custom_minimum_size = Vector2(150, 44)
	_kb_toggle.focus_mode = Control.FOCUS_NONE
	_kb_toggle.pressed.connect(func() -> void: _set_osk(not _osk))
	# drop it into the top bar just before the Back button
	var bar := _back_button.get_parent()
	bar.add_child(_kb_toggle)
	bar.move_child(_kb_toggle, 0)
	_sync_toggle()


func _sync_toggle() -> void:
	if _kb_toggle:
		_kb_toggle.text = "⌨ keyboard" if _osk else "⌨ on-screen"


func _set_osk(v: bool) -> void:
	_osk = v
	_kb_panel.visible = not v
	_sync_toggle()
	_save_osk()
	_recompute_ground()
	# on a touch/mobile/web export, also raise / drop the platform keyboard
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		if v:
			DisplayServer.virtual_keyboard_show("")
		else:
			DisplayServer.virtual_keyboard_hide()


func _recompute_ground() -> void:
	var h := size.y
	var kb := KB_H if (_kb_panel and _kb_panel.visible) else 0.0
	_ground_y = h - DANGER_ZONE_H - kb
	# keep the danger visuals sitting just above the ground line
	if _danger_zone:
		_danger_zone.offset_top = -(DANGER_ZONE_H + kb)
		_danger_zone.offset_bottom = -kb
	if _ground_line:
		_ground_line.offset_top = -(DANGER_ZONE_H + kb)
		_ground_line.offset_bottom = -(DANGER_ZONE_H + kb) + 6.0
	for letter in _letters:
		if is_instance_valid(letter):
			letter.set_boundary(_ground_y)


func _flash_key(ch: String) -> void:
	for b in _kb_buttons:
		if b.text == ch:
			var t := create_tween()
			b.modulate = Color(1.4, 1.4, 1.4)
			t.tween_property(b, "modulate", Color.WHITE, 0.18)
			return


func _load_osk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and cfg.has_section_key("fallingletter", "osk"):
		_osk = bool(cfg.get_value("fallingletter", "osk"))
	else:
		_osk = DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD)


func _save_osk() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("fallingletter", "osk", _osk)
	cfg.save(SETTINGS_PATH)


# ---------------------------------------------------------------------------
# HUD helpers
# ---------------------------------------------------------------------------

func _update_hud() -> void:
	var lv: Dictionary = LEVELS[_level]
	_score_label.text = "L%d/%d  %s  ·  %d/%d" % [
		_level + 1, LEVELS.size(), lv["name"], _level_score, POPS_PER_LEVEL]


func _rebuild_lives() -> void:
	for c in _lives_box.get_children():
		_lives_box.remove_child(c)
		c.queue_free()
	for i in _lives_max:
		var l := Label.new()
		l.text = HEART_FULL
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", Color(0.9, 0.2, 0.3))
		_lives_box.add_child(l)
	_update_lives()


func _update_lives() -> void:
	var hearts := _lives_box.get_children()
	for i in hearts.size():
		hearts[i].text = HEART_FULL if i < _lives else HEART_EMPTY
		hearts[i].modulate.a = 1.0 if i < _lives else 0.4


func _go_home() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	get_tree().change_scene_to_file(MAIN_MENU)


func _play(player: AudioStreamPlayer) -> void:
	if player.stream != null:
		player.play()
