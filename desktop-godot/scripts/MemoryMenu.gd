extends Control
## MemoryMenu — the "Memory" dashboard tile opens this. Pick a deck:
## Pictures / lowercase / UPPERCASE / Numbers -> Memory.tscn (variant via
## GameContext), or Sounds -> SoundMemory.tscn.

const MAIN_MENU := "res://scenes/MainMenu.tscn"
const MEMORY := "res://scenes/games/Memory.tscn"
const SOUND_MEMORY := "res://scenes/games/SoundMemory.tscn"

const CHOICES := [
	{ "label": "Pictures",  "sample": "★",   "variant": "pictures" },
	{ "label": "lowercase", "sample": "a b", "variant": "lower" },
	{ "label": "UPPERCASE", "sample": "A B", "variant": "upper" },
	{ "label": "Numbers",   "sample": "1 2", "variant": "numbers" },
	{ "label": "Sounds",    "sample": "♪",   "variant": "sounds" },
]

@onready var _grid: GridContainer = %ChoiceGrid
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_back_button.pressed.connect(_go_back)
	_grid.columns = 3
	for choice in CHOICES:
		_grid.add_child(_make_button(choice))
	if _grid.get_child_count() > 0:
		_grid.get_child(0).grab_focus()


func _make_button(choice: Dictionary) -> Button:
	var b := Button.new()
	b.text = "%s\n%s" % [choice["sample"], choice["label"]]
	b.custom_minimum_size = Vector2(300, 180)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(_on_choice.bind(choice["variant"]))
	return b


func _on_choice(variant: String) -> void:
	if variant == "sounds":
		get_tree().change_scene_to_file(SOUND_MEMORY)
	else:
		GameContext.memory_variant = variant
		get_tree().change_scene_to_file(MEMORY)


func _go_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
