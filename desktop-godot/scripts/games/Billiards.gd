extends Control
## Billiards - a forgiving pocket-the-balls game. Aim with the mouse, hold
## the left button to charge power, release to strike the cue ball. Sink
## every colour ball to clear the level; potting the cue ball just spots
## it back on the head spot.

const MAIN_MENU := "res://scenes/MainMenu.tscn"
const BALL_SCENE := preload("res://scenes/components/BilliardsBall.tscn")

const TABLE := Rect2(150, 140, 980, 520)
const CUSHION := 16.0
const GAP := 44.0             # cushion opening at each pocket
const POCKET := 44.0          # pocket capture half-extent

const MIN_POWER := 220.0
const MAX_POWER := 1150.0
const CHARGE_RATE := 1500.0   # power gained per second while held
const SETTLE_EPS := 9.0

const SND_CUE := "sndh.wav"
const SND_BUMP := "sndt.wav"
const SND_POCKET := "goal.wav"
const SND_WIN := "winner.ogg"

const LEVELS := [
	{ "name": "Warm-up", "targets": 3 },
	{ "name": "Rack",    "targets": 6 },
	{ "name": "Full",    "targets": 10 },
]

var _level_index := 0
var _shots := 0
var _targets_left := 0
var _level_done := false

var _cue: BilliardsBall
var _balls: Array[BilliardsBall] = []
var _head_spot := Vector2.ZERO
var _foot_spot := Vector2.ZERO

var _charging := false
var _power := 0.0
var _bump_cd := 0.0

@onready var _world: Node2D = $World
@onready var _cushions: StaticBody2D = $World/Cushions
@onready var _pockets: Node2D = $World/Pockets
@onready var _balls_root: Node2D = $World/Balls
@onready var _aim: Line2D = $World/AimLine
@onready var _info: Label = %InfoLabel
@onready var _back: Button = %BackButton
@onready var _popup: Control = %WinPopup
@onready var _popup_label: Label = %WinPopupLabel
@onready var _popup_next: Button = %WinPopupNext
@onready var _popup_replay: Button = %WinPopupReplay
@onready var _popup_menu: Button = %WinPopupMenu

@onready var _sfx_cue: AudioStreamPlayer = $Audio/CueSound
@onready var _sfx_bump: AudioStreamPlayer = $Audio/BumpSound
@onready var _sfx_pocket: AudioStreamPlayer = $Audio/PocketSound
@onready var _sfx_win: AudioStreamPlayer = $Audio/WinSound


func _ready() -> void:
	_sfx_cue.stream = AssetLoader.get_stream(SND_CUE)
	_sfx_bump.stream = AssetLoader.get_stream(SND_BUMP)
	_sfx_pocket.stream = AssetLoader.get_stream(SND_POCKET)
	_sfx_win.stream = AssetLoader.get_stream(SND_WIN)

	_head_spot = Vector2(TABLE.position.x + TABLE.size.x * 0.26, TABLE.get_center().y)
	_foot_spot = Vector2(TABLE.position.x + TABLE.size.x * 0.70, TABLE.get_center().y)

	_build_table()

	_back.pressed.connect(_go_home)
	_popup_menu.pressed.connect(_go_home)
	_popup_replay.pressed.connect(func() -> void: _start_level(_level_index))
	_popup_next.pressed.connect(func() -> void: _start_level(_level_index + 1))
	_popup.visible = false

	_start_level(0)


# ---------------------------------------------------------------------------
# Table build
# ---------------------------------------------------------------------------

func _build_table() -> void:
	var l := TABLE.position.x
	var r := TABLE.position.x + TABLE.size.x
	var top := TABLE.position.y
	var bot := TABLE.position.y + TABLE.size.y
	var mx := (l + r) * 0.5

	# Six cushion segments, leaving a GAP-wide opening at each pocket.
	_add_wall(l + GAP, top, mx - GAP, top)
	_add_wall(mx + GAP, top, r - GAP, top)
	_add_wall(l + GAP, bot, mx - GAP, bot)
	_add_wall(mx + GAP, bot, r - GAP, bot)
	_add_wall(l, top + GAP, l, bot - GAP)
	_add_wall(r, top + GAP, r, bot - GAP)

	# Six pockets: four corners + two long-rail middles.
	for spot in [Vector2(l, top), Vector2(mx, top), Vector2(r, top),
			Vector2(l, bot), Vector2(mx, bot), Vector2(r, bot)]:
		_add_pocket(spot)


func _add_wall(x1: float, y1: float, x2: float, y2: float) -> void:
	var rect := RectangleShape2D.new()
	if absf(x2 - x1) >= absf(y2 - y1):
		rect.size = Vector2(absf(x2 - x1), CUSHION)
	else:
		rect.size = Vector2(CUSHION, absf(y2 - y1))
	var cs := CollisionShape2D.new()
	cs.shape = rect
	cs.position = Vector2((x1 + x2) * 0.5, (y1 + y2) * 0.5)
	_cushions.add_child(cs)


func _add_pocket(spot: Vector2) -> void:
	var area := Area2D.new()
	area.position = spot
	var rect := RectangleShape2D.new()
	rect.size = Vector2(POCKET * 2.0, POCKET * 2.0)
	var cs := CollisionShape2D.new()
	cs.shape = rect
	area.add_child(cs)
	var spr := Sprite2D.new()
	var tex := AssetLoader.get_texture("hole.png")
	if tex:
		spr.texture = tex
		spr.scale = Vector2(POCKET * 2.0 / 60.0, POCKET * 2.0 / 60.0)
	area.add_child(spr)
	area.body_entered.connect(_on_pocket_body_entered)
	_pockets.add_child(area)


# ---------------------------------------------------------------------------
# Level setup
# ---------------------------------------------------------------------------

func _start_level(index: int) -> void:
	_level_index = clampi(index, 0, LEVELS.size() - 1)
	var lvl: Dictionary = LEVELS[_level_index]

	_shots = 0
	_level_done = false
	_charging = false
	_power = MIN_POWER
	_popup.visible = false

	for b in _balls:
		if is_instance_valid(b):
			b.queue_free()
	_balls.clear()

	_cue = BALL_SCENE.instantiate()
	_balls_root.add_child(_cue)
	_cue.setup(0, true)
	_cue.global_position = _head_spot
	_cue.bumped.connect(_on_bump)
	_balls.append(_cue)

	var n: int = lvl["targets"]
	var spots := _triangle_positions(n)
	for i in n:
		var b: BilliardsBall = BALL_SCENE.instantiate()
		_balls_root.add_child(b)
		b.setup(i + 1, false)
		b.global_position = spots[i]
		b.bumped.connect(_on_bump)
		b.settled.connect(_on_settled)
		_balls.append(b)

	_targets_left = n
	_update_info()


## Loose triangular rack starting at the foot spot, with a little jitter so
## overlapping balls push themselves apart.
func _triangle_positions(n: int) -> Array:
	var out: Array = []
	var spacing := 33.0
	var row := 0
	var col := 0
	var per_row := 1
	while out.size() < n:
		var x := _foot_spot.x + row * spacing * 0.9
		var y := _foot_spot.y + (col - row * 0.5) * spacing
		out.append(Vector2(x, y) + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)))
		col += 1
		if col >= per_row:
			row += 1
			per_row += 1
			col = 0
	return out


# ---------------------------------------------------------------------------
# Aiming & shooting
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_bump_cd = maxf(0.0, _bump_cd - delta)

	var ready_to_aim := _can_shoot() and not _level_done and _cue != null and _cue.active
	_aim.visible = ready_to_aim
	if not ready_to_aim:
		if _charging and not _can_shoot():
			_charging = false
		return

	var from: Vector2 = _cue.global_position
	var dir := get_global_mouse_position() - from
	dir = dir.normalized() if dir.length() > 1.0 else Vector2.RIGHT

	if _charging:
		_power = minf(_power + CHARGE_RATE * delta, MAX_POWER)

	var ratio := clampf((_power - MIN_POWER) / (MAX_POWER - MIN_POWER), 0.0, 1.0)
	var length := 70.0 + ratio * 210.0
	_aim.points = PackedVector2Array([from, from + dir * length])
	_aim.default_color = Color(0.45, 1.0, 0.55).lerp(Color(1.0, 0.5, 0.2), ratio)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_home()
		return
	if _level_done or not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		if _can_shoot() and _cue != null and _cue.active:
			_charging = true
			_power = MIN_POWER
	elif _charging:
		_charging = false
		_do_shot()


func _do_shot() -> void:
	var dir := get_global_mouse_position() - _cue.global_position
	if dir.length() < 1.0:
		return
	_cue.shoot(dir.normalized() * _power)
	_shots += 1
	_power = MIN_POWER
	_play(_sfx_cue)
	_update_info()


func _can_shoot() -> bool:
	for b in _balls:
		if b.active and b.linear_velocity.length() > SETTLE_EPS:
			return false
	return true


# ---------------------------------------------------------------------------
# Pocketing
# ---------------------------------------------------------------------------

func _on_pocket_body_entered(body: Node) -> void:
	if not (body is BilliardsBall):
		return
	var ball := body as BilliardsBall
	if not ball.active:
		return

	if ball.is_cue:
		_play(_sfx_pocket)
		ball.respawn_at(_head_spot)
		return

	ball.pocket()
	_play(_sfx_pocket)
	_targets_left -= 1
	_update_info()
	if _targets_left <= 0:
		_level_clear()


func _on_bump(_ball: BilliardsBall) -> void:
	if _bump_cd <= 0.0:
		_bump_cd = 0.05
		_play(_sfx_bump)


func _on_settled(_ball: BilliardsBall) -> void:
	_update_info()


# ---------------------------------------------------------------------------
# Level clear / navigation
# ---------------------------------------------------------------------------

func _level_clear() -> void:
	_level_done = true
	_charging = false
	_aim.visible = false
	_play(_sfx_win)

	var is_last := _level_index >= LEVELS.size() - 1
	_popup_label.text = "Table cleared in %d shot%s!" % [_shots, "" if _shots == 1 else "s"]
	_popup_next.visible = not is_last
	_popup.visible = true
	(_popup_replay if is_last else _popup_next).grab_focus()


func _go_home() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _update_info() -> void:
	_info.text = "Level %d / %d  -  %s      Shots: %d      Balls left: %d" % [
		_level_index + 1, LEVELS.size(), LEVELS[_level_index]["name"], _shots, _targets_left
	]


func _play(player: AudioStreamPlayer) -> void:
	if player.stream != null:
		player.play()
