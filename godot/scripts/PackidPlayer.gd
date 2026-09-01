extends Node2D
class_name PackidPlayer
## Grid-snapped Pac-style player. Arrow keys set a desired direction; the
## player keeps sliding cell-to-cell, turning as soon as the desired turn
## is clear, and stopping when it walks into a wall. The mouth opens and
## closes while moving; a "caught" pose freezes it for the reset beat.

signal arrived(cell: Vector2i)

const TILE := 24.0
const MOUTH_INTERVAL := 0.11
const INPUT_DIRS := {
	"ui_right": Vector2i.RIGHT,
	"ui_left": Vector2i.LEFT,
	"ui_up": Vector2i.UP,
	"ui_down": Vector2i.DOWN,
}

var grid_pos := Vector2i.ZERO
var speed := 120.0           # px/sec in World-local units
var active := true

var _blocked: Callable       # (Vector2i) -> bool
var _dir := Vector2i.ZERO
var _facing := Vector2i.RIGHT
var _desired := Vector2i.ZERO
var _moving := false
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _t := 0.0
var _dur := 0.0
var _target := Vector2i.ZERO

var _mouth_open := true
var _mouth_t := 0.0
var _caught := false

var _tex := {}

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	_tex = {
		Vector2i.RIGHT: [AssetLoader.get_texture("pac_r.png"), AssetLoader.get_texture("pac_r_c.png")],
		Vector2i.LEFT:  [AssetLoader.get_texture("pac_l.png"), AssetLoader.get_texture("pac_l_c.png")],
		Vector2i.UP:    [AssetLoader.get_texture("pac_u.png"), AssetLoader.get_texture("pac_u_c.png")],
		Vector2i.DOWN:  [AssetLoader.get_texture("pac_d.png"), AssetLoader.get_texture("pac_d_c.png")],
	}
	_refresh_sprite()


## Provide the wall test: blocked_fn.call(cell) -> bool.
func configure(blocked_fn: Callable) -> void:
	_blocked = blocked_fn


func place_at(cell: Vector2i) -> void:
	grid_pos = cell
	position = cell_center(cell)
	_dir = Vector2i.ZERO
	_desired = Vector2i.ZERO
	_facing = Vector2i.RIGHT
	_moving = false
	_caught = false
	_mouth_open = true
	_refresh_sprite()


func play_caught() -> void:
	_caught = true
	_moving = false
	_dir = Vector2i.ZERO
	_desired = Vector2i.ZERO
	var sad := AssetLoader.get_texture("pac_sad.png")
	if sad:
		_sprite.texture = sad


static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE * 0.5, cell.y * TILE + TILE * 0.5)


func _process(delta: float) -> void:
	if not active or _caught:
		return

	_read_input()

	if _moving:
		_t += delta
		var a: float = clampf(_t / _dur, 0.0, 1.0)
		position = _from.lerp(_to, a)
		_animate_mouth(delta)
		if a >= 1.0:
			_moving = false
			grid_pos = _target
			position = _to
			arrived.emit(grid_pos)
			_choose_next()
	else:
		_choose_next()
		if not _moving:
			_mouth_open = true
			_refresh_sprite()


func _read_input() -> void:
	for action in INPUT_DIRS:
		if Input.is_action_pressed(action):
			_desired = INPUT_DIRS[action]


func _choose_next() -> void:
	if _start_move(_desired):
		return
	_start_move(_dir)


func _start_move(dir: Vector2i) -> bool:
	if dir == Vector2i.ZERO:
		return false
	var next := grid_pos + dir
	if _blocked.is_valid() and _blocked.call(next):
		if dir == _dir:
			_dir = Vector2i.ZERO
		return false
	_dir = dir
	_facing = dir
	_target = next
	_from = position
	_to = cell_center(next)
	_dur = TILE / speed
	_t = 0.0
	_moving = true
	_refresh_sprite()
	return true


func _animate_mouth(delta: float) -> void:
	_mouth_t += delta
	if _mouth_t >= MOUTH_INTERVAL:
		_mouth_t = 0.0
		_mouth_open = not _mouth_open
		_refresh_sprite()


func _refresh_sprite() -> void:
	if _caught or _tex.is_empty():
		return
	var pair: Array = _tex.get(_facing, _tex[Vector2i.RIGHT])
	_sprite.texture = pair[0] if _mouth_open else pair[1]
