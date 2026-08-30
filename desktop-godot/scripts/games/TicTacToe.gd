extends Control
## Tic Tac Toe — noughts and crosses. Solo vs the computer (Easy / Medium /
## Hard) or a local "Pass & Play" 2-player game (Design Policy §K). X (blue)
## always moves first.

const MAIN_MENU := "res://scenes/MainMenu.tscn"
const SETTINGS_PATH := "user://settings.cfg"
const HUD := 56.0
const X := 1
const O := 2

const LEVELS := [
	{ "name": "Easy", "ai": "random" },
	{ "name": "Medium", "ai": "heuristic" },
	{ "name": "Hard", "ai": "perfect" },
]

const WLINES := [
	[0, 1, 2], [3, 4, 5], [6, 7, 8],
	[0, 3, 6], [1, 4, 7], [2, 5, 8],
	[0, 4, 8], [2, 4, 6],
]

const SND_MARK := "pick.wav"
const SND_AI := "dealcard1.wav"
const SND_WIN := "winner.ogg"
const SND_LOSE := "bummer.wav"
const SND_DRAW := "wrong.ogg"

var _level := 0
var _board: Array[int] = []
var _turn := X
var _done := {}                  # {} | { who } | { who, line }
var _ai_wait := 0.0
var _moves := 0
var _two_p := false
var _mode_btn: Button

var _grid := Rect2()
var _cell := 0.0

@onready var _info: Label = %InfoLabel
@onready var _status: Label = %StatusLabel
@onready var _back_button: Button = %BackButton
@onready var _popup: Control = %WinPopup
@onready var _popup_label: Label = %WinPopupLabel
@onready var _popup_next: Button = %WinPopupNext
@onready var _popup_replay: Button = %WinPopupReplay
@onready var _popup_menu: Button = %WinPopupMenu
@onready var _sfx_mark: AudioStreamPlayer = $Audio/Mark
@onready var _sfx_ai: AudioStreamPlayer = $Audio/Ai
@onready var _sfx_win: AudioStreamPlayer = $Audio/Win
@onready var _sfx_lose: AudioStreamPlayer = $Audio/Lose
@onready var _sfx_draw: AudioStreamPlayer = $Audio/Draw


func _ready() -> void:
	GameContext.theme_changed.connect(queue_redraw)
	var al := get_node_or_null("/root/AssetLoader")
	if al != null:
		_sfx_mark.stream = al.get_stream(SND_MARK)
		_sfx_ai.stream = al.get_stream(SND_AI)
		_sfx_win.stream = al.get_stream(SND_WIN)
		_sfx_lose.stream = al.get_stream(SND_LOSE)
		_sfx_draw.stream = al.get_stream(SND_DRAW)
	_back_button.pressed.connect(_go_home)
	_popup_menu.pressed.connect(_go_home)
	_popup_replay.pressed.connect(func() -> void: _start_level(_level))
	_popup_next.pressed.connect(func() -> void: _start_level(_level + 1))
	_popup.visible = false
	resized.connect(_geo)

	_two_p = _load_two_p()
	_mode_btn = Button.new()
	_mode_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mode_btn.offset_left = -196.0
	_mode_btn.offset_top = 10.0
	_mode_btn.offset_right = -16.0
	_mode_btn.custom_minimum_size = Vector2(180, 40)
	_mode_btn.focus_mode = Control.FOCUS_ALL
	_mode_btn.pressed.connect(_toggle_two_p)
	add_child(_mode_btn)

	_start_level(0)


func _load_two_p() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		return bool(cfg.get_value("tictactoe", "two_p", false))
	return false


func _toggle_two_p() -> void:
	if _moves > 0:
		return
	_two_p = not _two_p
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("tictactoe", "two_p", _two_p)
	cfg.save(SETTINGS_PATH)
	_start_level(_level)


func _sync_mode_btn() -> void:
	if _mode_btn == null:
		return
	_mode_btn.text = "2 Players" if _two_p else "1 Player"
	_mode_btn.visible = _moves == 0 and _done.is_empty()


func _start_level(n: int) -> void:
	_level = clampi(n, 0, LEVELS.size() - 1)
	_board = [0, 0, 0, 0, 0, 0, 0, 0, 0]
	_turn = X
	_done = {}
	_ai_wait = 0.0
	_moves = 0
	_popup.visible = false
	_sync_mode_btn()
	_geo()
	_update_hud()
	queue_redraw()


func _geo() -> void:
	var s: float = minf(size.x * 0.6, size.y - HUD - 90.0)
	_grid = Rect2((size.x - s) / 2.0, HUD + 30.0 + (size.y - HUD - 30.0 - s) / 2.0, s, s)
	_cell = s / 3.0


# --- rules -----------------------------------------------------------------
func _winner(b: Array) -> Dictionary:
	for ln in WLINES:
		var a: int = b[ln[0]]
		if a != 0 and a == b[ln[1]] and a == b[ln[2]]:
			return { "who": a, "line": ln }
	for v in b:
		if v == 0:
			return {}
	return { "who": 0 }


func _empty_cells(b: Array) -> Array[int]:
	var e: Array[int] = []
	for i in 9:
		if b[i] == 0:
			e.append(i)
	return e


func _minimax(b: Array, turn: int, me: int) -> int:
	var w := _winner(b)
	if not w.is_empty():
		if w["who"] == 0:
			return 0
		return 10 if w["who"] == me else -10
	var best := -999 if turn == me else 999
	for i in 9:
		if b[i] != 0:
			continue
		b[i] = turn
		var sc := _minimax(b, O if turn == X else X, me)
		b[i] = 0
		best = maxi(best, sc) if turn == me else mini(best, sc)
	return best


# a cell that completes a line for `who`, else -1
func _find_line(who: int) -> int:
	for ln in WLINES:
		var mine := 0
		var empty_idx := -1
		for c in ln:
			if _board[c] == who:
				mine += 1
			elif _board[c] == 0:
				empty_idx = c
		if mine == 2 and empty_idx >= 0:
			return empty_idx
	return -1


func _first_of(cells: Array, empty: Array) -> int:
	for c in cells:
		if c in empty:
			return c
	return -1


func _ai_move() -> void:
	var empty := _empty_cells(_board)
	if empty.is_empty():
		return
	var kind: String = LEVELS[_level]["ai"]
	var pick := -1

	if kind == "random":
		pick = empty[randi() % empty.size()]
	elif kind == "heuristic":
		pick = _find_line(O)
		if pick < 0:
			pick = _find_line(X)
		if pick < 0 and _board[4] == 0:
			pick = 4
		if pick < 0:
			pick = _first_of([0, 2, 6, 8], empty)
		if pick < 0:
			pick = _first_of([1, 3, 5, 7], empty)
		if pick < 0:
			pick = empty[0]
	else:
		var best_score := -999
		var best_moves: Array[int] = []
		for i in empty:
			_board[i] = O
			var sc := _minimax(_board, X, O)
			_board[i] = 0
			if sc > best_score:
				best_score = sc
				best_moves.clear()
				best_moves.append(i)
			elif sc == best_score:
				best_moves.append(i)
		pick = best_moves[randi() % best_moves.size()]

	_board[pick] = O
	_play(_sfx_ai)
	_turn = X
	_check_end()
	_update_hud()
	queue_redraw()


func _check_end() -> void:
	var w := _winner(_board)
	if w.is_empty():
		return
	_done = w
	var last := _level >= LEVELS.size() - 1
	if _two_p and w["who"] != 0:
		_play(_sfx_win)
		_popup_label.text = "Blue wins!" if w["who"] == X else "Orange wins!"
		_popup_next.visible = false
	elif w["who"] == X:
		_play(_sfx_win)
		if last:
			_popup_label.text = "You beat the champion!"
			_popup_next.visible = false
		else:
			_popup_label.text = "You win!"
			_popup_next.visible = true
	elif w["who"] == O:
		_play(_sfx_lose)
		_popup_label.text = "Computer wins"
		_popup_next.visible = false
	else:
		if _two_p:
			_play(_sfx_draw)
			_popup_label.text = "It's a draw"
			_popup_next.visible = false
		elif last:
			_play(_sfx_win)
			_popup_label.text = "Draw — you held the champion!"
			_popup_next.visible = false
		else:
			_play(_sfx_draw)
			_popup_label.text = "It's a draw"
			_popup_next.visible = false
	if _popup_next.visible:
		_popup_next.grab_focus()
	else:
		_popup_replay.grab_focus()
	_popup.visible = true
	_update_hud()


func _process(delta: float) -> void:
	if not _two_p and _done.is_empty() and _turn == O:
		_ai_wait += delta
		if _ai_wait > 0.4:
			_ai_wait = 0.0
			_ai_move()


func _gui_input(event: InputEvent) -> void:
	if _popup.visible or not _done.is_empty():
		return
	if not _two_p and _turn != X:
		return   # solo: wait for the AI
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
	if not _grid.has_point(pos):
		return
	var col: int = clampi(int((pos.x - _grid.position.x) / _cell), 0, 2)
	var row: int = clampi(int((pos.y - _grid.position.y) / _cell), 0, 2)
	var i := row * 3 + col
	if _board[i] != 0:
		return
	_board[i] = _turn
	_moves += 1
	_sync_mode_btn()
	_play(_sfx_mark)
	_turn = O if _turn == X else X
	_ai_wait = 0.0
	_check_end()
	_update_hud()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_home()


func _cell_centre(i: int) -> Vector2:
	return _grid.position + Vector2((i % 3) * _cell + _cell / 2.0, (i / 3) * _cell + _cell / 2.0)


func _draw() -> void:
	draw_rect(Rect2(0, 0, size.x, size.y), GameContext.c("bg"))
	var g := _grid

	for k in [1, 2]:
		draw_line(Vector2(g.position.x + k * _cell, g.position.y + 10.0),
			Vector2(g.position.x + k * _cell, g.position.y + g.size.y - 10.0), GameContext.c("line"), 6.0)
		draw_line(Vector2(g.position.x + 10.0, g.position.y + k * _cell),
			Vector2(g.position.x + g.size.x - 10.0, g.position.y + k * _cell), GameContext.c("line"), 6.0)

	for i in 9:
		var c := _cell_centre(i)
		var r := _cell * 0.28
		if _board[i] == X:
			draw_line(c + Vector2(-r, -r), c + Vector2(r, r), GameContext.c("accent"), 14.0)
			draw_line(c + Vector2(r, -r), c + Vector2(-r, r), GameContext.c("accent"), 14.0)
		elif _board[i] == O:
			draw_arc(c, r, 0.0, TAU, 40, GameContext.c("warn"), 14.0)

	if _done.has("line"):
		var ln: Array = _done["line"]
		draw_line(_cell_centre(ln[0]), _cell_centre(ln[2]), GameContext.c("good"), 10.0)


func _update_hud() -> void:
	if _two_p:
		_info.text = "2 players"
		if _status != null:
			if not _done.is_empty():
				_status.text = "game over"
			else:
				_status.text = "Blue's turn (X)" if _turn == X else "Orange's turn (O)"
	else:
		_info.text = "Level %d/%d - %s" % [_level + 1, LEVELS.size(), LEVELS[_level]["name"]]
		if _status != null:
			if not _done.is_empty():
				_status.text = "game over"
			else:
				_status.text = "your turn - you are X" if _turn == X else "computer thinking..."


func _play(p: AudioStreamPlayer) -> void:
	if p != null and p.stream != null:
		p.play()


func _go_home() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
