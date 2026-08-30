extends Control
## Puzzle — drag the pieces of a painting back into the frame.
##
## Levels 1-3 are regular grids (2x2 / 3x3 / 4x4). Levels 4-6 are cut into
## rectangles of different sizes by recursive random splits, so there is
## no grid to lean on.
##
## Everything is drawn in _draw(); dragging is handled in _gui_input().

const MAIN_MENU := "res://scenes/MainMenu.tscn"
const SNAP := 44.0

const LEVELS := [
	{ "name": "2 x 2",       "kind": "grid", "cols": 2, "rows": 2 },
	{ "name": "3 x 3",       "kind": "grid", "cols": 3, "rows": 3 },
	{ "name": "4 x 4",       "kind": "grid", "cols": 4, "rows": 4 },
	{ "name": "Odd shapes",  "kind": "free", "pieces": 6,  "min": 0.17 },
	{ "name": "5 x 5",       "kind": "grid", "cols": 5, "rows": 5 },
	{ "name": "More shapes", "kind": "free", "pieces": 9,  "min": 0.135 },
	{ "name": "Puzzler",     "kind": "free", "pieces": 12, "min": 0.11 },
	{ "name": "6 x 5",       "kind": "grid", "cols": 6, "rows": 5 },
	{ "name": "Master",      "kind": "free", "pieces": 16, "min": 0.09 },
]
const PAINTINGS := ["bruegel0", "bruegel1", "gogh0", "gogh1", "gogh3", "monet0", "monet1", "monet3", "pieck0", "pieck1", "pieck2", "rembrandt0", "rembrandt1", "renoir0", "vermeer1", "vermeer2", "vermeer3"]

const SND_SNAP := "pick.wav"
const SND_WIN := "winner.ogg"

var _level_index := 0
var _tex: Texture2D
var _frame := Rect2()
var _pieces: Array = []          # [{ nr: Rect2, home: Rect2, pos: Vector2, placed: bool }]
var _placed := 0
var _drag_piece = null
var _drag_offset := Vector2.ZERO

@onready var _info_label: Label = %InfoLabel
@onready var _back_button: Button = %BackButton
@onready var _popup: Control = %WinPopup
@onready var _popup_label: Label = %WinPopupLabel
@onready var _popup_next: Button = %WinPopupNext
@onready var _popup_replay: Button = %WinPopupReplay
@onready var _popup_menu: Button = %WinPopupMenu

@onready var _sfx_snap: AudioStreamPlayer = $Audio/SnapSound
@onready var _sfx_win: AudioStreamPlayer = $Audio/WinSound


func _ready() -> void:
	_sfx_snap.stream = AssetLoader.get_stream(SND_SNAP)
	_sfx_win.stream = AssetLoader.get_stream(SND_WIN)
	_back_button.pressed.connect(_go_home)
	_popup_menu.pressed.connect(_go_home)
	_popup_replay.pressed.connect(func() -> void: _start_level(_level_index))
	_popup_next.pressed.connect(func() -> void: _start_level(_level_index + 1))
	_popup.visible = false
	_start_level(0)


func _start_level(index: int) -> void:
	_level_index = clampi(index, 0, LEVELS.size() - 1)
	var lvl: Dictionary = LEVELS[_level_index]
	_placed = 0
	_drag_piece = null
	_popup.visible = false

	_tex = AssetLoader.get_texture(str(GameContext.draw_from_pool("backgrounds", PAINTINGS, 1)[0]))
	var iw := 4.0
	var ih := 3.0
	if _tex:
		iw = _tex.get_width()
		ih = _tex.get_height()
	var aspect := iw / ih

	var fw := 660.0
	var fh := fw / aspect
	if fh > 520.0:
		fh = 520.0
		fw = fh * aspect
	_frame = Rect2(56.0, 96.0 + (600.0 - fh) / 2.0, fw, fh)

	var norm: Array = (_grid_rects(lvl["cols"], lvl["rows"]) if lvl["kind"] == "grid"
		else _free_rects(lvl["pieces"], lvl["min"]))

	var scatter_x := _frame.position.x + _frame.size.x + 46.0
	_pieces.clear()
	for nr: Rect2 in norm:
		var home := Rect2(_frame.position + nr.position * _frame.size, nr.size * _frame.size)
		_pieces.append({
			"nr": nr,
			"home": home,
			"pos": Vector2(
				randf_range(scatter_x, size.x - 30.0 - home.size.x),
				randf_range(96.0, size.y - 30.0 - home.size.y)
			),
			"placed": false,
		})
	_pieces.shuffle()

	_update_info()
	queue_redraw()


# ---------------------------------------------------------------------------
# Piece layouts
# ---------------------------------------------------------------------------

func _grid_rects(cols: int, rows: int) -> Array:
	var out: Array = []
	for r in rows:
		for c in cols:
			out.append(Rect2(float(c) / cols, float(r) / rows, 1.0 / cols, 1.0 / rows))
	return out


func _free_rects(count: int, minf: float) -> Array:
	var rects: Array = [Rect2(0, 0, 1, 1)]
	var fails := 0
	while rects.size() < count and fails < 80:
		rects.sort_custom(func(a: Rect2, b: Rect2): return a.get_area() > b.get_area())
		var done := false
		for k in mini(3, rects.size()):
			var r: Rect2 = rects[k]
			var horiz := r.size.x >= r.size.y
			var along: float = r.size.x if horiz else r.size.y
			if along < minf * 2.0:
				continue
			var cut := along * randf_range(0.36, 0.64)
			if cut < minf or along - cut < minf:
				continue
			var a: Rect2
			var b: Rect2
			if horiz:
				a = Rect2(r.position, Vector2(cut, r.size.y))
				b = Rect2(r.position + Vector2(cut, 0), Vector2(r.size.x - cut, r.size.y))
			else:
				a = Rect2(r.position, Vector2(r.size.x, cut))
				b = Rect2(r.position + Vector2(0, cut), Vector2(r.size.x, r.size.y - cut))
			rects.remove_at(k)
			rects.insert(k, b)
			rects.insert(k, a)
			done = true
			break
		if not done:
			fails += 1
	return rects


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if _popup.visible:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var p = _top_piece_at(event.position)
			if p != null:
				_drag_piece = p
				_drag_offset = event.position - p["pos"]
				_pieces.erase(p)
				_pieces.append(p)          # bring to front
				accept_event()
		elif _drag_piece != null:
			var p = _drag_piece
			_drag_piece = null
			if p["pos"].distance_to(p["home"].position) < SNAP:
				p["pos"] = p["home"].position
				p["placed"] = true
				_placed += 1
				_play(_sfx_snap)
				_update_info()
				if _placed == _pieces.size():
					_win()
			queue_redraw()
			accept_event()

	elif event is InputEventMouseMotion and _drag_piece != null:
		var home: Rect2 = _drag_piece["home"]
		_drag_piece["pos"] = Vector2(
			clampf(event.position.x - _drag_offset.x, 0.0, size.x - home.size.x),
			clampf(event.position.y - _drag_offset.y, 0.0, size.y - home.size.y)
		)
		queue_redraw()
		accept_event()


func _top_piece_at(point: Vector2):
	for i in range(_pieces.size() - 1, -1, -1):
		var p = _pieces[i]
		if not p["placed"] and Rect2(p["pos"], p["home"].size).has_point(point):
			return p
	return null


# ---------------------------------------------------------------------------
# Draw
# ---------------------------------------------------------------------------

func _draw() -> void:
	if _tex == null:
		return
	var isize := _tex.get_size()

	# faint whole-picture ghost + frame + per-piece home outlines
	draw_texture_rect_region(_tex, _frame, Rect2(Vector2.ZERO, isize), Color(1, 1, 1, 0.14))
	draw_rect(_frame, Color(0.35, 0.44, 0.62), false, 3.0)
	for p in _pieces:
		draw_rect(p["home"], Color(0.47, 0.55, 0.7, 0.35), false, 1.0)

	var ordered: Array = []
	for p in _pieces:
		if p["placed"]:
			ordered.append(p)
	for p in _pieces:
		if not p["placed"]:
			ordered.append(p)

	for p in ordered:
		var nr: Rect2 = p["nr"]
		var src := Rect2(nr.position * isize, nr.size * isize)
		draw_texture_rect_region(_tex, Rect2(p["pos"], p["home"].size), src)
		var col := Color(1, 1, 1, 0.15) if p["placed"] else Color(0, 0, 0, 0.55)
		draw_rect(Rect2(p["pos"], p["home"].size), col, false, 1.0 if p["placed"] else 2.0)


# ---------------------------------------------------------------------------
# Win / helpers
# ---------------------------------------------------------------------------

func _win() -> void:
	_play(_sfx_win)
	var is_last := _level_index >= LEVELS.size() - 1
	_popup_label.text = "Picture complete!"
	_popup_next.visible = not is_last
	_popup.visible = true
	(_popup_replay if is_last else _popup_next).grab_focus()


func _update_info() -> void:
	_info_label.text = "Pieces %d / %d      Level %d / %d  -  %s" % [
		_placed, _pieces.size(), _level_index + 1, LEVELS.size(), LEVELS[_level_index]["name"]
	]


func _play(player: AudioStreamPlayer) -> void:
	if player.stream != null:
		player.play()


func _go_home() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_home()
