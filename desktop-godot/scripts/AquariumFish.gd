extends Node2D
class_name AquariumFish
## One fish. Two-frame swim cycle, random scale / speed / heading, gentle
## vertical bob, bounces off the tank walls. Clicking it (its Area2D)
## emits `poked` and makes it dart + flip; it can also steer toward a
## dropped food node.

signal poked(fish: AquariumFish)

var species_name := "fish"
var speed := 60.0
var target: Node2D = null

var _frames: Array[Texture2D] = []
var _vel := Vector2.ZERO
var _bounds := Rect2(0, 80, 1280, 600)
var _frame_t := 0.0
var _phase := 0.0
var _dart := 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _shape: CollisionShape2D = $Area/Shape


func setup(f0: Texture2D, f1: Texture2D, disp_name: String, base_scale: float) -> void:
	_frames = [f0, f1]
	species_name = disp_name
	_sprite.texture = f0
	scale = Vector2.ONE * base_scale * randf_range(0.7, 1.15)
	speed = randf_range(30.0, 82.0)
	_phase = randf() * 10.0
	_vel = Vector2(1.0 if randf() < 0.5 else -1.0, 0.0) * speed

	if f0 != null and _shape:
		var rect := RectangleShape2D.new()
		rect.size = f0.get_size()
		_shape.shape = rect

	# The Area2D is also wired for direct picking; the board hit-tests too,
	# so a consumed event won't fire twice.
	$Area.input_event.connect(_on_area_input)
	$Area.mouse_entered.connect(hover_pulse)


## Local rect (in this fish's parent space) used by the board's hit test.
func hit_rect() -> Rect2:
	var w: float = (_frames[0].get_width() if _frames and _frames[0] else 90.0) * scale.x
	var h: float = (_frames[0].get_height() if _frames and _frames[0] else 50.0) * scale.y
	return Rect2(position - Vector2(w, h) * 0.5, Vector2(w, h))


func set_bounds(r: Rect2) -> void:
	_bounds = r


func _process(delta: float) -> void:
	_frame_t += delta * (0.5 + speed / 90.0)
	if _frames.size() == 2:
		_sprite.texture = _frames[int(_frame_t) % 2]
	if _dart > 0.0:
		_dart -= delta

	if target != null and is_instance_valid(target):
		var to: Vector2 = (target.global_position - global_position)
		var d := to.length()
		if d > 1.0:
			_vel += to / d * 160.0 * delta
	else:
		if randf() < delta * 1.5:
			_vel.x += randf_range(-20.0, 20.0)
		_vel.y += (sin((_phase + Time.get_ticks_msec() / 1000.0) * 1.2) * 16.0 - _vel.y) * delta * 2.0

	var vmax := speed * (2.4 if _dart > 0.0 else 1.0) * (1.6 if target != null else 1.0)
	if _vel.length() > vmax:
		_vel = _vel.normalized() * vmax

	position += _vel * delta

	var w: float = (_frames[0].get_width() if _frames.size() > 0 and _frames[0] else 90.0) * scale.x
	var h: float = (_frames[0].get_height() if _frames.size() > 0 and _frames[0] else 50.0) * scale.y
	var mx := w * 0.35
	if position.x < _bounds.position.x + mx:
		position.x = _bounds.position.x + mx
		_vel.x = absf(_vel.x)
	if position.x > _bounds.end.x - mx:
		position.x = _bounds.end.x - mx
		_vel.x = -absf(_vel.x)
	if position.y < _bounds.position.y + h * 0.5:
		position.y = _bounds.position.y + h * 0.5
		_vel.y = absf(_vel.y) * 0.6
	if position.y > _bounds.end.y - h * 0.5:
		position.y = _bounds.end.y - h * 0.5
		_vel.y = -absf(_vel.y) * 0.6

	_sprite.flip_h = _vel.x < 0.0


func dart() -> void:
	_dart = 0.7
	var t := create_tween()
	t.tween_property(_sprite, "scale", Vector2(1.18, 1.18), 0.09)
	t.tween_property(_sprite, "scale", Vector2.ONE, 0.12)


func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		poked.emit(self)
		dart()


func hover_pulse() -> void:
	var t := create_tween()
	t.tween_property(_sprite, "scale", Vector2(1.1, 1.1), 0.1)
	t.tween_property(_sprite, "scale", Vector2.ONE, 0.15)
