extends RigidBody2D
class_name BilliardsBall
## A pool ball. Rolls with linear damping for friction, bounces off the
## cushions, and snaps to a dead stop below a small speed threshold so it
## never jitters forever. Emits `pocketed` when the table sinks it and
## `bumped` when it strikes another ball (for the click SFX).

signal pocketed(ball: BilliardsBall)
signal settled(ball: BilliardsBall)
signal bumped(ball: BilliardsBall)

const STOP_EPS := 9.0
const MAX_SPEED := 1500.0
const BUMP_COOLDOWN := 0.07

@export var is_cue := false

var ball_index := 0
var active := true

var _was_moving := false
var _bump_t := 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _shape: CollisionShape2D = $Shape


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 6
	body_entered.connect(_on_body_entered)
	_apply_texture()


func setup(index: int, cue: bool) -> void:
	ball_index = index
	is_cue = cue
	if is_node_ready():
		_apply_texture()


func _apply_texture() -> void:
	var tex := AssetLoader.get_texture("ball1.png" if is_cue else "ball2.png")
	if tex:
		_sprite.texture = tex
	if is_cue:
		_sprite.modulate = Color.WHITE
	else:
		# spread target balls across the colour wheel so they read apart
		_sprite.modulate = Color.from_hsv(fmod(0.137 * ball_index, 1.0), 0.7, 1.0)


func _physics_process(delta: float) -> void:
	_bump_t = maxf(0.0, _bump_t - delta)
	if not active:
		return

	if linear_velocity.length() > MAX_SPEED:
		linear_velocity = linear_velocity.limit_length(MAX_SPEED)

	var spd := linear_velocity.length()
	if spd > 0.0 and spd < STOP_EPS:
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0

	var moving := linear_velocity.length() >= STOP_EPS
	if _was_moving and not moving:
		settled.emit(self)
	_was_moving = moving


func is_moving() -> bool:
	return active and linear_velocity.length() >= STOP_EPS


func shoot(impulse: Vector2) -> void:
	if active:
		apply_central_impulse(impulse)


func pocket() -> void:
	if not active:
		return
	active = false
	visible = false
	_was_moving = false
	# Deferred: this runs from body_entered, mid physics-query flush.
	_shape.set_deferred("disabled", true)
	set_deferred("freeze", true)
	set_deferred("linear_velocity", Vector2.ZERO)
	set_deferred("angular_velocity", 0.0)
	pocketed.emit(self)


## Put the ball back in play at `pos` (used for a cue-ball scratch).
func respawn_at(pos: Vector2) -> void:
	active = true
	visible = true
	_was_moving = false
	_shape.set_deferred("disabled", false)
	set_deferred("freeze", false)
	set_deferred("global_position", pos)
	set_deferred("linear_velocity", Vector2.ZERO)
	set_deferred("angular_velocity", 0.0)


func _on_body_entered(body: Node) -> void:
	if _bump_t <= 0.0 and body is BilliardsBall:
		_bump_t = BUMP_COOLDOWN
		bumped.emit(self)
