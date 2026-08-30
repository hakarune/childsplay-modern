extends Control
## Four in a Row — Connect Four against the computer. You are red and go
## first; drop a disc into a column, get four in a line.

const MAIN_MENU := "res://scenes/MainMenu.tscn"
const COLS := 7
const ROWS := 6
const HUD := 64.0
const RED := 1
const YEL := 2

const LEVELS := [
	{ "name": "Easy", "smart": 0.35 },
	{ "name": "Tricky", "smart": 0.75 },
	{ "name": "Sharp", "smart": 1.0 },
]

const SND_DROP := "pick.wav"
const SND_WIN := "won.ogg"
const SND_LOSS := "loss.ogg"

var _level := 0
var _grid: Array = []
var _turn := RED
var _over := false
var _win_line = null
var _drop = null                # { col, row, y, vy, who }
var _hover_col := -1
var _ai_timer = null
var _cell := 90.0
var _bx := 0.0
var _by := 0.0
var _r := 36.0

@onready var _info_label: Label = %InfoLabel
@onready var _back_button: Button = %BackButton
@onready var _popup: Control = %WinPopup
@onready var _popup_label: Label = %WinPopupLabel
@onready var _popup_next: Button = %WinPopupNext
@onready var _popup_replay: Button = %WinPopupReplay
@onready var _popup_menu: Button = %WinPopupMenu
@onready var _sfx_drop: AudioStreamPlayer = $Audio/DropSound
@onready var _sfx_win: AudioStreamPlayer = $Audio/WinSound
@onready var _sfx_loss: AudioStreamPlayer = $Audio/LossSound


func _ready() -> void:
	GameContext.theme_changed.connect(queue_redraw)
	_sfx_drop.stream = AssetLoader.get_stream(SND_DROP)
	_sfx_win.stream = AssetLoader.get_stream(SND_WIN)
	_sfx_loss.stream = AssetLoader.get_stream(SND_LOSS)
	_back_button.pressed.connect(_go_home)
	_popup_menu.pressed.connect(_go_home)
	_popup_replay.pressed.connect(func() -> void: _start_level(_level))
	_popup_next.pressed.connect(func() -> void: _start_level(_level + 1))
	_popup.visible = false
	_start_level(0)


func _start_level(n: int) -> void:
	_level = clampi(n, 0, LEVELS.size() - 1)
	_grid.clear()
	for r in ROWS:
		_grid.append([])
		for c in COLS:
			_grid[r].append(0)
	_turn = RED
	_over = false
	_win_line = null
	_drop = null
	_ai_timer = null
	_hover_col = -1
	_popup.visible = false
	_geo()
	_update_hud()


func _geo() -> void:
	_cell = minf(96.0, minf((size.y - HUD - 40.0) / ROWS, (size.x - 80.0) / COLS))
	_bx = (size.x - _cell * COLS) / 2.0
	_by = HUD + (size.y - HUD - _cell * ROWS) / 2.0
	_r = _cell * 0.4


func _col_x(c: int) -> float:
	return _bx + c * _cell + _cell / 2.0


func _row_y(r: int) -> float:
	return _by + r * _cell + _cell / 2.0


func _lowest(c: int) -> int:
	for r in range(ROWS - 1, -1, -1):
		if _grid[r][c] == 0:
			return r
	return -1


func _process(delta: float) -> void:
	if _ai_timer != null and _drop == null and not _over:
		_ai_timer -= delta
		if _ai_timer <= 0.0:
			_ai_timer = null
			_ai_move()

	if _drop != null:
		_drop["vy"] += 2600.0 * delta
		_drop["y"] += _drop["vy"] * delta
		var rest := _row_y(_drop["row"])
		if _drop["y"] >= rest:
			_drop["y"] = rest
			var who: int = _drop["who"]
			_grid[_drop["row"]][_drop["col"]] = who
			_drop = null
			_play(_sfx_drop)
			var line = _four(who)
			if line != null:
				_end(who, line)
			elif _board_full():
				_end(0, null)
			else:
				_turn = YEL if who == RED else RED
				if _turn == YEL:
					_ai_timer = 0.45
	queue_redraw()


func _board_full() -> bool:
	for c in COLS:
		if _grid[0][c] == 0:
			return false
	return true


func _place(col: int, who: int) -> void:
	var row := _lowest(col)
	if row < 0 or _drop != null or _over:
		return
	_drop = { "col": col, "row": row, "y": _by - _cell / 2.0, "vy": 0.0, "who": who }


func _ai_move() -> void:
	var smart: float = LEVELS[_level]["smart"]
	var cols: Array = []
	for c in COLS:
		if _lowest(c) >= 0:
			cols.append(c)
	if cols.is_empty():
		return
	if randf() < smart:
		for c in cols:
			if _would_win(c, YEL):
				_place(c, YEL)
				return
		for c in cols:
			if _would_win(c, RED):
				_place(c, YEL)
				return
	var best: int = cols[0]
	var best_w := -999.0
	for c in cols:
		var w: float = (3.0 - absf(float(c) - 3.0)) + randf() * 2.0
		if w > best_w:
			best_w = w
			best = c
	_place(best, YEL)


func _would_win(c: int, who: int) -> bool:
	var r := _lowest(c)
	if r < 0:
		return false
	_grid[r][c] = who
	var w := _four(who) != null
	_grid[r][c] = 0
	return w


func _four(who: int):
	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, -1)]
	for r in ROWS:
		for c in COLS:
			if _grid[r][c] != who:
				continue
			for d in dirs:
				var cells: Array[Vector2i] = [Vector2i(c, r)]
				for k in range(1, 4):
					var nr: int = r + d.y * k
					var nc: int = c + d.x * k
					if nr < 0 or nr >= ROWS or nc < 0 or nc >= COLS or _grid[nr][nc] != who:
						break
					cells.append(Vector2i(nc, nr))
				if cells.size() == 4:
					return cells
	return null


func _end(who: int, line) -> void:
	_over = true
	_win_line = line
	var you_won := who == RED
	_play(_sfx_win if you_won else _sfx_loss)
	var is_last := _level >= LEVELS.size() - 1
	_popup_label.text = "It's a draw!" if who == 0 else ("You got four!" if you_won else "Computer wins!")
	_popup_next.visible = you_won and not is_last
	_popup.visible = true
	(_popup_replay if not (you_won and not is_last) else _popup_next).grab_focus()


func _gui_input(event: InputEvent) -> void:
	if _popup.visible:
		return
	if event is InputEventMouseMotion:
		_hover_col = int(floor((event.position.x - _bx) / _cell))
		if event.position.x < _bx or event.position.x > _bx + _cell * COLS:
			_hover_col = -1
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _over or _drop != null or _turn != RED:
			return
		var c := int(floor((event.position.x - _bx) / _cell))
		if c >= 0 and c < COLS and _lowest(c) >= 0:
			_place(c, RED)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_home()


func _draw() -> void:
	if _hover_col >= 0 and _turn == RED and not _over and _drop == null and _lowest(_hover_col) >= 0:
		draw_circle(Vector2(_col_x(_hover_col), _by - _cell / 2.0), _r, Color(1, 0.35, 0.35, 0.35))

	draw_rect(Rect2(_bx - 8.0, _by - 8.0, _cell * COLS + 16.0, _cell * ROWS + 16.0), GameContext.c("surface_alt"))
	for r in ROWS:
		for c in COLS:
			var v: int = _grid[r][c]
			var col := GameContext.c("bg")
			if v == RED:
				col = GameContext.c("p1")
			elif v == YEL:
				col = GameContext.c("p2")
			draw_circle(Vector2(_col_x(c), _row_y(r)), _r, col)

	if _drop != null:
		var dc := GameContext.c("p1") if _drop["who"] == RED else GameContext.c("p2")
		draw_circle(Vector2(_col_x(_drop["col"]), _drop["y"]), _r, dc)

	if _win_line != null:
		var a: Vector2i = _win_line[0]
		var b: Vector2i = _win_line[3]
		draw_line(Vector2(_col_x(a.x), _row_y(a.y)), Vector2(_col_x(b.x), _row_y(b.y)), GameContext.c("good"), 8.0)


func _update_hud() -> void:
	_info_label.text = "Level %d / %d  -  %s      (you are red)" % [_level + 1, LEVELS.size(), LEVELS[_level]["name"]]


func _play(p: AudioStreamPlayer) -> void:
	if p.stream != null:
		p.play()


func _go_home() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
