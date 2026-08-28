extends Control
class_name LetterItem
## A single falling letter: a big high-contrast glyph inside a colourful
## balloon. It drifts straight down at fall_speed (px/sec). When its
## bottom edge crosses the danger boundary it emits `missed` and frees
## itself. The board calls pop() instead when the player types its letter.

signal missed(letter: LetterItem)

const SIZE := Vector2(112.0, 112.0)

var target_char: String = "A"
var fall_speed: float = 100.0

var _boundary_y: float = 100000.0
var _bubble_color: Color = Color(0.3, 0.6, 1.0)
var _dead := false

@onready var _balloon: Panel = $Balloon
@onready var _label: Label = $Balloon/Char


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE * 0.5
	_apply_visuals()


## Configure the letter. Safe to call right after instantiate(); visuals
## refresh on _ready. `boundary_y` is the Y (in the parent's space) at
## which the letter counts as missed.
func setup(ch: String, speed: float, boundary_y: float, bubble_color: Color) -> void:
	target_char = ch.to_upper()
	fall_speed = speed
	_boundary_y = boundary_y
	_bubble_color = bubble_color
	if is_node_ready():
		_apply_visuals()


func _apply_visuals() -> void:
	_label.text = target_char

	var sb := StyleBoxFlat.new()
	sb.bg_color = _bubble_color
	sb.set_corner_radius_all(int(SIZE.x * 0.5))
	sb.set_border_width_all(6)
	sb.border_color = _bubble_color.lightened(0.35)
	_balloon.add_theme_stylebox_override("panel", sb)

	_label.add_theme_color_override(
		"font_color",
		Color(0.12, 0.12, 0.16) if _bubble_color.get_luminance() > 0.5 else Color.WHITE
	)


func _process(delta: float) -> void:
	if _dead:
		return
	position.y += fall_speed * delta
	if position.y + size.y >= _boundary_y:
		_dead = true
		missed.emit(self)
		queue_free()


## Player typed this letter: quick "pop" then disappear.
func pop() -> void:
	if _dead:
		return
	_dead = true
	set_process(false)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(1.6, 1.6), 0.18).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	t.chain().tween_callback(queue_free)


## Stop falling in place (used when the game ends).
func freeze() -> void:
	fall_speed = 0.0
	set_process(false)
