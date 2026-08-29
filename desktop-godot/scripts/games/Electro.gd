extends Control
## Electro — the wiring board. Animal pictures down the left, their names
## (shuffled) down the right. Drag a wire from each picture to its name.
## Correct wires lock in green; wrong ones buzz and fall away. Connect
## every pair to clear the level. Six levels, 3 → 8 pairs.

const MAIN_MENU := "res://scenes/MainMenu.tscn"
const HUD := 56.0
const SIDE := 44.0
const NODE_R := 13.0
const PAIRS := [3, 4, 5, 6, 7, 8]

const ANIMALS := [
	"01_cat", "02_pig", "03_bear", "06_cow", "07_sheep", "09_panda",
	"14_fox", "17_lion", "21_frog", "12_wolf", "13_monkey", "16_elephant",
	"05_penguin", "08_turtle",
]

const SND_PICK := "dealcard1.wav"
const SND_GOOD := "good.ogg"
const SND_WRONG := "wrong.ogg"
const SND_WIN := "winner.ogg"

var _level := 0
var _ids: Array[String] = []
var _right_ids: Array[String] = []
var _solved: Dictionary = {}          # id -> true
var _wrong := {}                      # { a, b, t } or {}
var _drag := {}                       # { col:"L"/"R", id, x, y } or {}

var _tile_w := 300.0
var _tile_h := 90.0
var _top := 0.0
var _gap := 14.0
var _tex_cache: Dictionary = {}

@onready var _info: Label = %InfoLabel
@onready var _back_button: Button = %BackButton
@onready var _popup: Control = %WinPopup
@onready var _popup_label: Label = %WinPopupLabel
@onready var _popup_next: Button = %WinPopupNext
@onready var _popup_replay: Button = %WinPopupReplay
@onready var _popup_menu: Button = %WinPopupMenu
@onready var _sfx_pick: AudioStreamPlayer = $Audio/Pick
@onready var _sfx_good: AudioStreamPlayer = $Audio/Good
@onready var _sfx_wrong: AudioStreamPlayer = $Audio/Wrong
@onready var _sfx_win: AudioStreamPlayer = $Audio/Win


func _ready() -> void:
	var al := get_node_or_null("/root/AssetLoader")
	if al != null:
		_sfx_pick.stream = al.get_stream(SND_PICK)
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


func _label(id: String) -> String:
	var base := id.substr(id.find("_") + 1)
	return base.substr(0, 1).to_upper() + base.substr(1)


func _tex(id: String) -> Texture2D:
	if not _tex_cache.has(id):
		var al := get_node_or_null("/root/AssetLoader")
		_tex_cache[id] = al.get_texture("%s.png" % id) if al != null else null
	return _tex_cache[id]


func _start_level(n: int) -> void:
	_level = clampi(n, 0, PAIRS.size() - 1)
	var count: int = PAIRS[_level]
	var pool := ANIMALS.duplicate()
	pool.shuffle()
	_ids.assign(pool.slice(0, count))
	_right_ids.assign(_ids.duplicate())
	_right_ids.shuffle()
	_solved.clear()
	_wrong = {}
	_drag = {}
	_popup.visible = false
	_geo()
	_update_hud()
	queue_redraw()


func _geo() -> void:
	var count: int = PAIRS[_level]
	_tile_w = clampf(size.x * 0.30, 200.0, 340.0)
	var avail_h := size.y - HUD - 56.0
	_tile_h = minf(94.0, (avail_h - _gap * (count - 1)) / count)
	var grid_h := count * _tile_h + _gap * (count - 1)
	_top = HUD + 28.0 + maxf(0.0, (avail_h - grid_h) / 2.0)


func _row_y(i: int) -> float:
	return _top + i * (_tile_h + _gap)

func _left_x() -> float:
	return SIDE

func _right_x() -> float:
	return size.x - SIDE - _tile_w

func _left_node(i: int) -> Vector2:
	return Vector2(_left_x() + _tile_w, _row_y(i) + _tile_h / 2.0)

func _right_node(i: int) -> Vector2:
	return Vector2(_right_x(), _row_y(i) + _tile_h / 2.0)


func _node_hit(p: Vector2) -> Dictionary:
	for i in _ids.size():
		if not _solved.has(_ids[i]) and p.distance_to(_left_node(i)) < NODE_R * 2.2:
			return { "col": "L", "id": _ids[i], "i": i }
		if not _solved.has(_right_ids[i]) and p.distance_to(_right_node(i)) < NODE_R * 2.2:
			return { "col": "R", "id": _right_ids[i], "i": i }
	return {}


func _process(delta: float) -> void:
	if _wrong:
		_wrong["t"] += delta
		if _wrong["t"] > 0.5:
			_wrong = {}
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _popup.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag(event.position)
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if _drag:
			_drag["x"] = event.position.x
			_drag["y"] = event.position.y
			queue_redraw()


func _begin_drag(p: Vector2) -> void:
	var hit := _node_hit(p)
	if hit:
		_drag = { "col": hit["col"], "id": hit["id"], "x": p.x, "y": p.y }
		_play(_sfx_pick)
		queue_redraw()


func _end_drag(p: Vector2) -> void:
	if not _drag:
		return
	var d := _drag
	_drag = {}
	var hit := _node_hit(p)
	if not hit or hit["col"] == d["col"]:
		queue_redraw()
		return
	if hit["id"] == d["id"]:
		_solved[d["id"]] = true
		_play(_sfx_good)
		if _solved.size() >= int(PAIRS[_level]):
			_level_done()
	else:
		_wrong = { "a": d["id"], "b": hit["id"], "t": 0.0 }
		_play(_sfx_wrong)
	_update_hud()
	queue_redraw()


func _level_done() -> void:
	var last := _level >= PAIRS.size() - 1
	_play(_sfx_win)
	if last:
		_popup_label.text = "Every wire connected!"
		_popup_next.visible = false
		_popup_replay.grab_focus()
	else:
		_popup_label.text = "Level %d done!" % (_level + 1)
		_popup_next.visible = true
		_popup_next.grab_focus()
	_popup.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_home()


func _bezier_pts(a: Vector2, b: Vector2) -> PackedVector2Array:
	var mx := (a.x + b.x) / 2.0
	var c1 := Vector2(mx, a.y)
	var c2 := Vector2(mx, b.y)
	var pts := PackedVector2Array()
	for k in 17:
		var t := k / 16.0
		var u := 1.0 - t
		pts.append(u * u * u * a + 3.0 * u * u * t * c1 + 3.0 * u * t * t * c2 + t * t * t * b)
	return pts


func _draw() -> void:
	draw_rect(Rect2(0, 0, size.x, size.y), Color("141a24"))

	var wrong_ids: Array = [_wrong["a"], _wrong["b"]] if _wrong else []

	for i in _ids.size():
		var id: String = _ids[i]
		var y := _row_y(i)
		var done := _solved.has(id)
		var buzz := id in wrong_ids
		var fill := Color("5b2b2b") if buzz else (Color("26402c") if done else Color("243247"))
		draw_rect(Rect2(_left_x(), y, _tile_w, _tile_h), fill)
		var tex := _tex(id)
		if tex != null:
			var pad := 8.0
			var s: float = minf((_tile_w - pad * 2) / tex.get_width(), (_tile_h - pad * 2) / tex.get_height())
			var dw := tex.get_width() * s
			var dh := tex.get_height() * s
			draw_texture_rect(tex, Rect2(_left_x() + pad, y + (_tile_h - dh) / 2.0, dw, dh), false)
		_draw_node(_left_node(i), done)

	var font := ThemeDB.fallback_font
	for i in _right_ids.size():
		var id: String = _right_ids[i]
		var y := _row_y(i)
		var done := _solved.has(id)
		var buzz := id in wrong_ids
		var fill := Color("5b2b2b") if buzz else (Color("26402c") if done else Color("243247"))
		draw_rect(Rect2(_right_x(), y, _tile_w, _tile_h), fill)
		var txt := _label(id)
		var fs := 24
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(_right_x() + _tile_w / 2.0 - tw / 2.0 + 8.0, y + _tile_h / 2.0 + fs * 0.35),
			txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("8fd6a0") if done else Color("eef2f7"))
		_draw_node(_right_node(i), done)

	for id in _solved.keys():
		var li := _ids.find(id)
		var ri := _right_ids.find(id)
		draw_polyline(_bezier_pts(_left_node(li), _right_node(ri)), Color("5fce6b"), 6.0, true)

	if _wrong:
		var a := _left_node(_ids.find(_wrong["a"]))
		var b := _right_node(_right_ids.find(_wrong["b"]))
		var alpha: float = clampf(1.0 - _wrong["t"] / 0.5, 0.0, 1.0)
		draw_polyline(_bezier_pts(a, b), Color(1, 0.35, 0.35, alpha), 6.0, true)

	if _drag:
		var list: Array = _ids if _drag["col"] == "L" else _right_ids
		var i := list.find(_drag["id"])
		var a := _left_node(i) if _drag["col"] == "L" else _right_node(i)
		draw_polyline(_bezier_pts(a, Vector2(_drag["x"], _drag["y"])), Color("ffd93d"), 6.0, true)


func _draw_node(n: Vector2, done: bool) -> void:
	draw_circle(n, NODE_R, Color("5fce6b") if done else Color("8fa6c8"))
	draw_circle(n, NODE_R * 0.45, Color("141a24"))


func _update_hud() -> void:
	_info.text = "Level %d/%d   ·   %d/%d wired" % [
		_level + 1, PAIRS.size(), _solved.size(), int(PAIRS[_level])
	]


func _play(p: AudioStreamPlayer) -> void:
	if p != null and p.stream != null:
		p.play()


func _go_home() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
