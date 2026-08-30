extends Control
## Numbers — the counting-order memory game. Numbered tiles are scattered
## on the board; study them, press Start, they go blank, then tap them in
## order 1, 2, 3 … from memory. A wrong tap flashes red and peeks the whole
## board for a moment — no progress lost. Six levels, 4 → 9 tiles.

const MAIN_MENU := "res://scenes/MainMenu.tscn"
const HUD := 56.0
const R := 42.0

const SND_START := "pick.wav"
const SND_GOOD := "good.ogg"
const SND_WRONG := "wrong.ogg"
const SND_WIN := "winner.ogg"

var _level := 0
var _tiles: Array = []            # { n, nx, ny, flash, lit }
var _phase := "study"             # study | play | peek
var _next := 1
var _peek := 0.0
var _box := Rect2()
var _start_btn := Rect2()

@onready var _info: Label = %InfoLabel
@onready var _status: Label = %StatusLabel
@onready var _back_button: Button = %BackButton
@onready var _popup: Control = %WinPopup
@onready var _popup_label: Label = %WinPopupLabel
@onready var _popup_next: Button = %WinPopupNext
@onready var _popup_replay: Button = %WinPopupReplay
@onready var _popup_menu: Button = %WinPopupMenu
@onready var _sfx_start: AudioStreamPlayer = $Audio/Start
@onready var _sfx_good: AudioStreamPlayer = $Audio/Good
@onready var _sfx_wrong: AudioStreamPlayer = $Audio/Wrong
@onready var _sfx_win: AudioStreamPlayer = $Audio/Win


func _ready() -> void:
	GameContext.theme_changed.connect(queue_redraw)
	var al := get_node_or_null("/root/AssetLoader")
	if al != null:
		_sfx_start.stream = al.get_stream(SND_START)
		_sfx_good.stream = al.get_stream(SND_GOOD)
		_sfx_wrong.stream = al.get_stream(SND_WRONG)
		_sfx_win.stream = al.get_stream(SND_WIN)
	_back_button.pressed.connect(_go_home)
	_popup_menu.pressed.connect(_go_home)
	_popup_replay.pressed.connect(func() -> void: _start_level(_level))
	_popup_next.pressed.connect(func() -> void: _start_level(_level + 1))
	_popup.visible = false
	resized.connect(_geo)
	_start_level(0)


func _count() -> int:
	return 4 + _level


func _start_level(n: int) -> void:
	_level = clampi(n, 0, 5)
	_popup.visible = false
	_new_board()


func _new_board() -> void:
	var count := _count()
	var pts: Array = []
	var guard := 0
	while pts.size() < count and guard < 4000:
		guard += 1
		var nx := randf_range(0.06, 0.94)
		var ny := randf_range(0.08, 0.92)
		var bad := false
		for q in pts:
			if (q.x - nx) * (q.x - nx) + (q.y - ny) * (q.y - ny) < 0.02:
				bad = true
				break
		if not bad:
			pts.append(Vector2(nx, ny))
	while pts.size() < count:
		pts.append(Vector2(randf_range(0.06, 0.94), randf_range(0.08, 0.92)))
	pts.shuffle()
	_tiles = []
	for i in count:
		_tiles.append({ "n": i + 1, "nx": pts[i].x, "ny": pts[i].y, "flash": 0.0, "lit": false })

	_phase = "study"
	_next = 1
	_peek = 0.0
	_geo()
	_update_hud()
	queue_redraw()


func _geo() -> void:
	_box = Rect2(60.0, HUD + 34.0, size.x - 120.0, size.y - HUD - 34.0 - 110.0)
	_start_btn = Rect2(size.x / 2.0 - 110.0, size.y - 84.0, 220.0, 60.0)


func _pos(t: Dictionary) -> Vector2:
	return Vector2(
		_box.position.x + R + t["nx"] * (_box.size.x - 2.0 * R),
		_box.position.y + R + t["ny"] * (_box.size.y - 2.0 * R),
	)


func _begin() -> void:
	if _phase != "study":
		return
	if _sfx_start.stream != null:
		_sfx_start.play()
	_phase = "play"
	_update_hud()


func _process(delta: float) -> void:
	var redraw := false
	for t in _tiles:
		if t["flash"] > 0.0:
			t["flash"] = maxf(0.0, t["flash"] - delta)
			redraw = true
	if _peek > 0.0:
		_peek -= delta
		if _peek <= 0.0 and _phase == "peek":
			_phase = "play"
			_update_hud()
		redraw = true
	if redraw:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _popup.visible:
		return
	var pos := Vector2.ZERO
	var tapped := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		pos = event.position
		tapped = true
	elif event is InputEventScreenTouch and not event.pressed:
		pos = event.position
		tapped = true
	if not tapped:
		return

	if _phase == "study":
		if _start_btn.has_point(pos):
			_begin()
		return
	if _phase != "play":
		return

	var hit := {}
	for t in _tiles:
		if _pos(t).distance_to(pos) <= R:
			hit = t
			break
	if hit.is_empty() or hit["lit"]:
		return

	if int(hit["n"]) == _next:
		hit["lit"] = true
		hit["flash"] = 0.4
		if _sfx_good.stream != null:
			_sfx_good.play()
		_next += 1
		_update_hud()
		if _next > _count():
			_level_done()
	else:
		hit["flash"] = 0.6
		if _sfx_wrong.stream != null:
			_sfx_wrong.play()
		_phase = "peek"
		_peek = 1.2
		_update_hud()
	queue_redraw()


func _level_done() -> void:
	var last := _level >= 5
	if _sfx_win.stream != null:
		_sfx_win.play()
	if last:
		_popup_label.text = "You found every number!"
		_popup_next.visible = false
		_popup_replay.grab_focus()
	else:
		_popup_label.text = "Level %d done!" % (_level + 1)
		_popup_next.visible = true
		_popup_next.grab_focus()
	_popup.visible = true
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_home()


func _draw() -> void:
	draw_rect(Rect2(0, 0, size.x, size.y), GameContext.c("bg"))
	var font := ThemeDB.fallback_font
	var show_nums := _phase == "study" or _phase == "peek"

	for t in _tiles:
		var p := _pos(t)
		var flashing: bool = t["flash"] > 0.0
		var reveal: bool = show_nums or t["lit"]
		var fill := GameContext.c("surface")
		if t["lit"]:
			fill = GameContext.c("good")
		if flashing:
			fill = GameContext.c("good") if t["lit"] else GameContext.c("bad")
		draw_circle(p, R, fill)
		draw_arc(p, R, 0.0, TAU, 48, GameContext.c("good") if t["lit"] else Color(1, 1, 1, 0.18), 3.0)

		var txt := str(t["n"]) if reveal else "?"
		var fs := 34 if reveal else 30
		var col := GameContext.c("text") if reveal else Color(1, 1, 1, 0.28)
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, p + Vector2(-tw / 2.0, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	if _phase == "study" and not _popup.visible:
		draw_rect(_start_btn, GameContext.c("accent"))
		var fs := 26
		var tw := font.get_string_size("Start", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, _start_btn.position + Vector2(_start_btn.size.x / 2.0 - tw / 2.0, _start_btn.size.y / 2.0 + fs * 0.35),
			"Start", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _update_hud() -> void:
	var got: int = mini(_next - 1, _count())
	_info.text = "Level %d/6   ·   %d/%d found" % [_level + 1, got, _count()]
	if _status != null:
		if _phase == "study":
			_status.text = "remember where the numbers are, then press Start"
		elif _phase == "peek":
			_status.text = "take another look..."
		else:
			_status.text = "tap number %d" % _next


func _go_home() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
