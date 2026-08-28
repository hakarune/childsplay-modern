extends Control
class_name MemoryCard
## A single memory card: a picture "front" and a shared child-friendly
## "back". Clicking an interactable card asks the board (via card_clicked)
## to flip it; the board then drives flip_up / flip_down / set_matched.
##
## The flip is a fake-3D effect: tween the inner button's X scale to 0,
## swap the visible texture at the midpoint, then tween it back to 1.

signal card_clicked(card: MemoryCard)

const FLIP_TIME := 0.12

@export var card_id: String = ""
var is_flipped := false
var is_matched := false

var front_texture: Texture2D
var back_texture: Texture2D

@onready var _button: TextureButton = $Card


func _ready() -> void:
	_button.pressed.connect(_on_pressed)
	_button.resized.connect(_update_pivot)
	_update_pivot()
	_apply_face(false)
	_button.scale = Vector2.ONE


## Assign this card's identity and textures. Safe to call right after
## instantiate(); the visual is refreshed once the node is ready.
func setup(id: String, front: Texture2D, back: Texture2D) -> void:
	card_id = id
	front_texture = front
	back_texture = back
	is_flipped = false
	is_matched = false
	if is_node_ready():
		_apply_face(false)
		_button.scale = Vector2.ONE
		_button.disabled = false
		modulate.a = 1.0


func flip_up() -> void:
	if is_flipped or is_matched:
		return
	is_flipped = true
	_animate_flip(true)


func flip_down() -> void:
	if not is_flipped or is_matched:
		return
	is_flipped = false
	_animate_flip(false)


## Lock the card in its matched (face-up) state and dim it slightly.
func set_matched() -> void:
	is_matched = true
	is_flipped = true
	_button.disabled = true
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.55, 0.25)


func _on_pressed() -> void:
	if is_matched or is_flipped:
		return
	card_clicked.emit(self)


func _animate_flip(show_front: bool) -> void:
	var t := create_tween()
	t.set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_button, "scale", Vector2(0.0, 1.0), FLIP_TIME)
	t.tween_callback(_apply_face.bind(show_front))
	t.tween_property(_button, "scale", Vector2(1.0, 1.0), FLIP_TIME)


func _apply_face(show_front: bool) -> void:
	_button.texture_normal = front_texture if show_front else back_texture


func _update_pivot() -> void:
	_button.pivot_offset = _button.size * 0.5
