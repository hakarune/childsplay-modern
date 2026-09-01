extends Control
## Block Breaker — a gentle Breakout. Slide the paddle, bounce the ball,
## clear every brick. Losing the ball costs a life, not the game; run out
## and you just replay the wall. Six walls, then you win.

const MAIN_MENU := "res://scenes/MainMenu.tscn"

const HUD := 56.0
const SIDE := 44.0
const COLS := 11
const BRICK_H := 28.0
const BRICK_GAP := 6.0
const BRICK_TOP := HUD + 42.0
const PAD_W := 150.0
const PAD_H := 16.0
const PAD_Y_OFF := 58.0
const BALL_R := 9.0
const BASE_SPEED := 430.0
const SPEED_PER_LEVEL := 28.0
const MAX_BOUNCE := deg_to_rad(62.0)
const MIN_BOUNCE := deg_to_rad(19.0)
const MIN_VX_FRAC := 0.18
const MIN_VY_FRAC := 0.26
const LIVES := 3
const SUBSTEPS := 3

const TINTS := {
	"r": "ff5a5a", "o": "ff9838", "y": "ffd93d", "g": "5fce6b",
	"b": "4d96ff", "p": "b980f0", "c": "33c2d6",
}
const TOUGH := "8a94a6"
const TOUGH_HIT := "5b6270"

# 11-wide wall layouts, top row first.
const LEVELS := [
	["ggggggggggg",
	 "ooooooooooo"],
	["o.o.o.o.o.o",
	 "rrrrrrrrrrr",
	 "o.o.o.o.o.o"],
	["bbbbbbbbbbb",
	 "ccccccccccc",
	 "bbbbbbbbbbb"],
	[".....y.....",
	 "....yoy....",
	 "...yo#oy...",
	 "..yo#g#oy.."],
	["#.#.#.#.#.#",
	 "ggggggggggg",
	 "ppppppppppp"],
	["##.......##",
	 "#o#.....#o#",
	 "#o#.....#o#",
	 "##.......##",
	 ".#########."],
]

const SND_LAUNCH := "sndh.wav"
const SND_WALL := "bump.wav"
const SND_PAD := "sndt.wav"
const SND_BRICK := "pick.wav"
const SND_LOSE := "bummer.wav"
const SND_CLEAR := "finlevel.wav"
const SND_WIN := "winner.ogg"

var _level := 0
var _lives := LIVES
var _over := false
var _won := false
var _stuck := true
var _speed := BASE_SPEED
var _pad_x := 0.0
var _pad_y := 0.0
var _bx := 0.0
var _by := 0.0
var _bvx := 0.0
var _bvy := 0.0
var _field_w := 0.0
var _brick_w := 0.0
var _bricks: Array = []           # { c, r, tough, hp, color: Color, alive }
var _move := 0                    # -1 / 0 / 1 keyboard paddle
var _ptr_active := false

@onready var _info: Label = %InfoLabel
@onready var _back_button: Button = %BackButton
@onready var _popup: Control = %WinPopup
@onready var _popup_label: Label = %WinPopupLabel
@onready var _popup_next: Button = %WinPopupNext
@onready var _popup_replay: Button = %WinPopupReplay
@onready var _popup_menu: Button = %WinPopupMenu
@onready var _sfx_launch: AudioStreamPlayer = $Audio/Launch
@onready var _sfx_wall: AudioStreamPlayer = $Audio/Wall
@onready var _sfx_pad: AudioStreamPlayer = $Audio/Pad
@onready var _sfx_brick: AudioStreamPlayer = $Audio/Brick
@onready var _sfx_lose: AudioStreamPlayer = $Audio/Lose
@onready var _sfx_clear: AudioStreamPlayer = $Audio/Clear
@onready var _sfx_win: AudioStreamPlayer = $Audio/Win


func _ready() -> void:
	GameContext.theme_changed.connect(_style_hud)
	_style_hud()
	var al := get_node_or_null("/root/AssetLoader")
	if al != null:
		_sfx_launch.stream = al.get_stream(SND_LAUNCH)
		_sfx_wall.stream = al.get_stream(SND_WALL)
		_sfx_pad.stream = al.get_stream(SND_PAD)
		_sfx_brick.stream = al.get_stream(SND_BRICK)
		_sfx_lose.stream = al.get_stream(SND_LOSE)
		_sfx_clear.stream = al.get_stream(SND_CLEAR)
		_sfx_win.stream = al.get_stream(SND_WIN)
	_back_button.pressed.connect(_go_home)
	_popup_menu.pressed.connect(_go_home)
	_popup_replay.pressed.connect(func() -> void: _start_level(_level))
	_popup_next.pressed.connect(func() -> void: _start_level(_level + 1))
	_popup.visible = false
	resized.connect(_on_resized)
	_start_level(0)


func _start_level(n: int) -> void:
	_level = clampi(n, 0, LEVELS.size() - 1)
	_lives = LIVES
	_over = false
	_won = false
	_popup.visible = false
	_geo()
	_build_bricks()
	_reset_ball()
	_update_hud()


func _on_resized() -> void:
	_geo()
	if _stuck:
		_reset_ball()


func _geo() -> void:
	_field_w = size.x - SIDE * 2.0
	_brick_w = _field_w / float(COLS)
	_pad_y = size.y - PAD_Y_OFF
	if _pad_x == 0.0:
		_pad_x = (size.x - PAD_W) / 2.0
	_pad_x = clampf(_pad_x, 0.0, size.x - PAD_W)


func _build_bricks() -> void:
	_bricks.clear()
	var rows: Array = LEVELS[_level]
	for r in rows.size():
		var row: String = rows[r]
		for c in COLS:
			var ch := row.substr(c, 1) if c < row.length() else "."
			if ch == ".":
				continue
			var tough := ch == "#"
			var hex: String = TOUGH if tough else String(TINTS.get(ch, "9fb4d8"))
			_bricks.append({
				"c": c, "r": r, "tough": tough,
				"hp": 2 if tough else 1,
				"color": Color(hex),
				"alive": true,
			})


func _brick_rect(b: Dictionary) -> Rect2:
	var x: float = SIDE + int(b["c"]) * _brick_w
	var y: float = BRICK_TOP + int(b["r"]) * (BRICK_H + BRICK_GAP)
	return Rect2(x + 3.0, y + 3.0, _brick_w - 6.0, BRICK_H)


func _reset_ball() -> void:
	_stuck = true
	_speed = BASE_SPEED + _level * SPEED_PER_LEVEL
	_bx = _pad_x + PAD_W / 2.0
	_by = _pad_y - BALL_R - 1.0
	_bvx = 0.0
	_bvy = 0.0


func _launch() -> void:
	if not _stuck or _over:
		return
	_stuck = false
	var ang := deg_to_rad(randf_range(-60.0, 60.0))
	_bvx = sin(ang) * _speed
	_bvy = -absf(cos(ang) * _speed)
	_play(_sfx_launch)


func _alive_count() -> int:
	var n := 0
	for b in _bricks:
		if b["alive"]:
			n += 1
	return n


func _process(delta: float) -> void:
	if not _over:
		if _move != 0:
			_pad_x = clampf(_pad_x + _move * 620.0 * delta, 0.0, size.x - PAD_W)
		if _stuck:
			_bx = _pad_x + PAD_W / 2.0
			_by = _pad_y - BALL_R - 1.0
		else:
			var h := delta / float(SUBSTEPS)
			for i in SUBSTEPS:
				if _over:
					break
				_step(h)
	queue_redraw()


func _step(h: float) -> void:
	_bx += _bvx * h
	_by += _bvy * h

	if _bx - BALL_R < 0.0:
		_bx = BALL_R
		_bvx = absf(_bvx)
		_play(_sfx_wall)
	elif _bx + BALL_R > size.x:
		_bx = size.x - BALL_R
		_bvx = -absf(_bvx)
		_play(_sfx_wall)
	if _by - BALL_R < HUD:
		_by = HUD + BALL_R
		_bvy = absf(_bvy)
		_play(_sfx_wall)

	# paddle
	if _bvy > 0.0 \
			and _by + BALL_R >= _pad_y and _by - BALL_R <= _pad_y + PAD_H \
			and _bx >= _pad_x - BALL_R and _bx <= _pad_x + PAD_W + BALL_R:
		_by = _pad_y - BALL_R
		var rel := clampf((_bx - (_pad_x + PAD_W / 2.0)) / (PAD_W / 2.0), -1.0, 1.0)
		var ang := rel * MAX_BOUNCE
		if absf(ang) < MIN_BOUNCE:
			var dir := signf(rel) if absf(rel) > 0.05 else (1.0 if _bvx >= 0.0 else -1.0)
			ang = dir * MIN_BOUNCE
		_bvx = sin(ang) * _speed
		_bvy = -cos(ang) * _speed
		_play(_sfx_pad)

	# bricks — reflect off the first one hit this step
	for b in _bricks:
		if not b["alive"]:
			continue
		var rect := _brick_rect(b)
		var cx := clampf(_bx, rect.position.x, rect.position.x + rect.size.x)
		var cy := clampf(_by, rect.position.y, rect.position.y + rect.size.y)
		var dx := _bx - cx
		var dy := _by - cy
		if dx * dx + dy * dy > BALL_R * BALL_R:
			continue

		if absf(dx) > absf(dy):
			_bvx = absf(_bvx) if dx >= 0.0 else -absf(_bvx)
			_bx += (BALL_R - absf(dx)) if _bvx >= 0.0 else -(BALL_R - absf(dx))
		else:
			_bvy = absf(_bvy) if dy >= 0.0 else -absf(_bvy)
			_by += (BALL_R - absf(dy)) if _bvy >= 0.0 else -(BALL_R - absf(dy))

		_clamp_angle()

		b["hp"] -= 1
		if b["hp"] <= 0:
			b["alive"] = false
			_play(_sfx_brick)
			_update_hud()
		else:
			b["color"] = Color(TOUGH_HIT)
			_play(_sfx_pad)
		if _alive_count() == 0:
			_clear_level()
		break

	if _by - BALL_R > size.y:
		_lose_ball()


func _clamp_angle() -> void:
	var sx := -1.0 if _bvx < 0.0 else 1.0
	var sy := -1.0 if _bvy < 0.0 else 1.0
	var vx: float = maxf(absf(_bvx), _speed * MIN_VX_FRAC)
	var vy: float = maxf(absf(_bvy), _speed * MIN_VY_FRAC)
	var k := _speed / maxf(sqrt(vx * vx + vy * vy), 1.0)
	_bvx = sx * vx * k
	_bvy = sy * vy * k


func _lose_ball() -> void:
	_lives -= 1
	_play(_sfx_lose)
	if _lives > 0:
		_reset_ball()
		_update_hud()
	else:
		_over = true
		_popup_label.text = "Out of balls!  Have another go."
		_popup_next.visible = false
		_popup.visible = true
		_popup_replay.grab_focus()


func _clear_level() -> void:
	_over = true
	var last := _level >= LEVELS.size() - 1
	if last:
		_won = true
		_play(_sfx_win)
		_popup_label.text = "You cleared every wall!"
		_popup_next.visible = false
		_popup_replay.grab_focus()
	else:
		_play(_sfx_clear)
		_popup_label.text = "Wall %d cleared!" % (_level + 1)
		_popup_next.visible = true
		_popup_next.grab_focus()
	_popup.visible = true


func _gui_input(event: InputEvent) -> void:
	if _popup.visible:
		return
	if event is InputEventMouseMotion:
		if _ptr_active:
			_aim_paddle(event.position.x)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_ptr_active = true
			_aim_paddle(event.position.x)
		else:
			_ptr_active = false
			_launch()
	elif event is InputEventScreenDrag:
		_aim_paddle(event.position.x)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_aim_paddle(event.position.x)
		else:
			_launch()


func _aim_paddle(x: float) -> void:
	_pad_x = clampf(x - PAD_W / 2.0, 0.0, size.x - PAD_W)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_home()
	elif event.is_action_pressed("ui_left"):
		_move = -1
	elif event.is_action_pressed("ui_right"):
		_move = 1
	elif event.is_action_released("ui_left") and _move == -1:
		_move = 0
	elif event.is_action_released("ui_right") and _move == 1:
		_move = 0
	elif event.is_action_pressed("ui_accept"):
		_launch()


func _draw() -> void:
	draw_rect(Rect2(0, 0, size.x, size.y), GameContext.c("bg"))
	draw_rect(Rect2(0, HUD, size.x, size.y - HUD), GameContext.c("bg"))

	for b in _bricks:
		if not b["alive"]:
			continue
		var rect := _brick_rect(b)
		draw_rect(rect, b["color"])
		draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 4.0), Color(1, 1, 1, 0.18))
		if b["tough"] and b["hp"] > 1:
			draw_rect(Rect2(rect.position.x + 3.0, rect.position.y + 3.0, rect.size.x - 6.0, rect.size.y - 6.0),
				Color(1, 1, 1, 0.5), false, 2.0)

	draw_rect(Rect2(_pad_x, _pad_y, PAD_W, PAD_H), GameContext.c("p2"))
	draw_circle(Vector2(_bx, _by), BALL_R, GameContext.c("p1"))


func _update_hud() -> void:
	var hearts := ""
	for i in LIVES:
		hearts += "●" if i < _lives else "○"
	_info.text = "Wall %d/%d   ·   bricks left %d      %s" % [
		_level + 1, LEVELS.size(), _alive_count(), hearts
	]


func _play(p: AudioStreamPlayer) -> void:
	if p != null and p.stream != null:
		p.play()


func _go_home() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


## Themed HUD bar + divider so the top chrome reads against the play
## area in both palettes (Design Policy §G).
func _style_hud() -> void:
	GameContext.style_hud_bar(self, HUD, [_info], [])
	queue_redraw()
