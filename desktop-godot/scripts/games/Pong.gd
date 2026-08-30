extends Control
## Pong — bat and ball versus a gentle computer paddle. First to 5.

const MAIN_MENU := "res://scenes/MainMenu.tscn"

const HUD := 64.0
const PW := 16.0
const PH := 116.0
const BR := 12.0
const TARGET := 5
const BASE := 330.0
const SPEEDUP := 20.0
const MAXV := 620.0

const LEVELS := [
	{ "name": "Gentle", "ai": 52.0 },
	{ "name": "Rally", "ai": 78.0 },
	{ "name": "Speedy", "ai": 106.0 },
]

const SND_WALL := "bump.wav"
const SND_HIT := "pick.wav"
const SND_GOAL := "goal.wav"
const SND_WIN := "winner.ogg"

var _level := 0
var _you := 0
var _cpu := 0
var _over := false
var _py := 300.0
var _ay := 300.0
var _ball := Vector2.ZERO
var _bvel := Vector2.ZERO
var _serve_pause := 0.0
var _ptr_y = null

@onready var _score_label: Label = %ScoreLabel
@onready var _info_label: Label = %InfoLabel
@onready var _back_button: Button = %BackButton
@onready var _popup: Control = %WinPopup
@onready var _popup_label: Label = %WinPopupLabel
@onready var _popup_next: Button = %WinPopupNext
@onready var _popup_replay: Button = %WinPopupReplay
@onready var _popup_menu: Button = %WinPopupMenu
@onready var _sfx_wall: AudioStreamPlayer = $Audio/WallSound
@onready var _sfx_hit: AudioStreamPlayer = $Audio/HitSound
@onready var _sfx_goal: AudioStreamPlayer = $Audio/GoalSound
@onready var _sfx_win: AudioStreamPlayer = $Audio/WinSound


func _ready() -> void:
	GameContext.theme_changed.connect(queue_redraw)
	_sfx_wall.stream = AssetLoader.get_stream(SND_WALL)
	_sfx_hit.stream = AssetLoader.get_stream(SND_HIT)
	_sfx_goal.stream = AssetLoader.get_stream(SND_GOAL)
	_sfx_win.stream = AssetLoader.get_stream(SND_WIN)
	_back_button.pressed.connect(_go_home)
	_popup_menu.pressed.connect(_go_home)
	_popup_replay.pressed.connect(func() -> void: _start_level(_level))
	_popup_next.pressed.connect(func() -> void: _start_level(_level + 1))
	_popup.visible = false
	_start_level(0)


func _start_level(n: int) -> void:
	_level = clampi(n, 0, LEVELS.size() - 1)
	_you = 0
	_cpu = 0
	_over = false
	_py = (HUD + size.y) / 2.0 - PH / 2.0
	_ay = _py
	_popup.visible = false
	_serve(1 if randf() < 0.5 else -1)
	_update_hud()


func _serve(dir: int) -> void:
	_ball = Vector2(size.x / 2.0, (HUD + size.y) / 2.0)
	var ang := randf_range(-0.35, 0.35)
	_bvel = Vector2(dir * BASE * cos(ang), BASE * sin(ang))
	_serve_pause = 0.6


func _process(delta: float) -> void:
	if not _over:
		_sim(delta)
	queue_redraw()


func _sim(delta: float) -> void:
	var top := HUD
	var bot := size.y

	var kv := (1.0 if Input.is_action_pressed("ui_down") else 0.0) - (1.0 if Input.is_action_pressed("ui_up") else 0.0)
	if kv != 0.0:
		_py = clampf(_py + kv * 420.0 * delta, top, bot - PH)
	if _ptr_y != null:
		var want: float = clampf(_ptr_y - PH / 2.0, top, bot - PH)
		_py += (want - _py) * minf(1.0, delta * 14.0)

	var ai_max: float = LEVELS[_level]["ai"]
	var acx := _ay + PH / 2.0
	if absf(_ball.y - acx) > 16.0:
		_ay = clampf(_ay + signf(_ball.y - acx) * ai_max * delta, top, bot - PH)

	if _serve_pause > 0.0:
		_serve_pause -= delta
		return

	_ball += _bvel * delta

	if _ball.y - BR < top:
		_ball.y = top + BR
		_bvel.y = absf(_bvel.y)
		_play(_sfx_wall)
	if _ball.y + BR > bot:
		_ball.y = bot - BR
		_bvel.y = -absf(_bvel.y)
		_play(_sfx_wall)

	var pl := 60.0
	var pr := size.x - 60.0 - PW
	if _bvel.x < 0.0 and _ball.x - BR < pl + PW and _ball.x - BR > pl - 20.0 \
			and _ball.y > _py - BR and _ball.y < _py + PH + BR:
		_bounce(_py, 1)
	if _bvel.x > 0.0 and _ball.x + BR > pr and _ball.x + BR < pr + PW + 20.0 \
			and _ball.y > _ay - BR and _ball.y < _ay + PH + BR:
		_bounce(_ay, -1)

	if _ball.x < -BR:
		_cpu += 1
		_point(1)
	elif _ball.x > size.x + BR:
		_you += 1
		_point(-1)


func _bounce(paddle_top: float, dir: int) -> void:
	_bvel.x = dir * minf(MAXV, absf(_bvel.x) + SPEEDUP)
	var rel := (_ball.y - (paddle_top + PH / 2.0)) / (PH / 2.0)
	_bvel.y = clampf(_bvel.y + rel * 190.0, -MAXV, MAXV)
	_ball.x += dir * 6.0
	_play(_sfx_hit)


func _point(serve_dir: int) -> void:
	_play(_sfx_goal)
	_update_hud()
	if _you >= TARGET or _cpu >= TARGET:
		_finish()
	else:
		_serve(serve_dir)


func _finish() -> void:
	_over = true
	_play(_sfx_win)
	var won := _you > _cpu
	var is_last := _level >= LEVELS.size() - 1
	_popup_label.text = "%s\n%d - %d" % ["You win!" if won else "So close!", _you, _cpu]
	_popup_next.visible = won and not is_last
	_popup.visible = true
	(_popup_replay if not (won and not is_last) else _popup_next).grab_focus()


func _gui_input(event: InputEvent) -> void:
	if _popup.visible:
		return
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed):
		if event.position.x < size.x * 0.55:
			_ptr_y = event.position.y


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_home()


func _draw() -> void:
	draw_rect(Rect2(0, HUD, size.x, size.y - HUD), GameContext.c("bg"))
	var dash := 0.0
	while dash < size.y - HUD - 10.0:
		draw_line(Vector2(size.x / 2.0, HUD + 10.0 + dash), Vector2(size.x / 2.0, HUD + 10.0 + dash + 16.0), Color(1, 1, 1, 0.18), 4.0)
		dash += 34.0
	draw_rect(Rect2(60, _py, PW, PH), GameContext.c("good"))
	draw_rect(Rect2(size.x - 60 - PW, _ay, PW, PH), GameContext.c("warn"))
	draw_circle(_ball, BR, Color.WHITE)


func _update_hud() -> void:
	_score_label.text = "%d   -   %d" % [_you, _cpu]
	_info_label.text = "first to %d   -   Level %d / %d  -  %s" % [TARGET, _level + 1, LEVELS.size(), LEVELS[_level]["name"]]


func _play(p: AudioStreamPlayer) -> void:
	if p.stream != null:
		p.play()


func _go_home() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
