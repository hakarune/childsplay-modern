extends Node2D
class_name PackidGhost
## Friendly maze wanderer (drawn as a fruit, not a scary ghost). At every
## cell it picks a random direction that isn't a wall and isn't a straight
## reversal, so it drifts around without ping-ponging. Speed is low and
## forgiving for small children.

const TILE := 24.0

var grid_pos := Vector2i.ZERO
var speed := 70.0
var active := true

var _blocked: Callable
var _dir := Vector2i.ZERO
var _moving := false
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _t := 0.0
var _dur := 0.0
var _target := Vector2i.ZERO

@onready var _sprite: Sprite2D = $Sprite


## `tex_name` is an AssetLoader key (e.g. "appel.png"); `tint` recolours it.
func setup(blocked_fn: Callable, tex_name: String, tint: Color) -> void:
	_blocked = blocked_fn
	var tex := AssetLoader.get_texture(tex_name)
	if tex:
		_sprite.texture = tex
	_sprite.modulate = tint


func place_at(cell: Vector2i) -> void:
	grid_pos = cell
	position = PackidPlayer.cell_center(cell)
	_dir = Vector2i.ZERO
	_moving = false


func _process(delta: float) -> void:
	if not active:
		return

	if _moving:
		_t += delta
		var a: float = clampf(_t / _dur, 0.0, 1.0)
		position = _from.lerp(_to, a)
		if a >= 1.0:
			_moving = false
			grid_pos = _target
			position = _to
			_choose_next()
	else:
		_choose_next()


func _choose_next() -> void:
	var opts: Array[Vector2i] = []
	for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		if d == -_dir:
			continue
		if not (_blocked.is_valid() and _blocked.call(grid_pos + d)):
			opts.append(d)

	if opts.is_empty():
		# Dead end - allow the reversal.
		if _dir != Vector2i.ZERO and not _blocked.call(grid_pos - _dir):
			opts.append(-_dir)
	if opts.is_empty():
		return

	# Bias toward carrying straight on for calmer paths.
	var choice: Vector2i
	if _dir in opts and randf() < 0.6:
		choice = _dir
	else:
		choice = opts[randi() % opts.size()]
	_start_move(choice)


func _start_move(dir: Vector2i) -> void:
	_dir = dir
	_target = grid_pos + dir
	_from = position
	_to = PackidPlayer.cell_center(_target)
	_dur = TILE / speed
	_t = 0.0
	_moving = true
