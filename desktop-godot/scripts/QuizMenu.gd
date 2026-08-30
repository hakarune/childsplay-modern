extends Control
## QuizMenu — the "Quiz" dashboard tile opens this. Pick a deck; it hands
## the id to the shared engine (Quiz.tscn) via GameContext.quiz_deck.

const MAIN_MENU := "res://scenes/MainMenu.tscn"
const QUIZ := "res://scenes/games/Quiz.tscn"

const CHOICES := [
	{ "label": "General",  "sample": "?",   "deck": "general" },
	{ "label": "Pictures", "sample": "★",   "deck": "picture" },
	{ "label": "Math",     "sample": "+",   "deck": "math" },
	{ "label": "Words",    "sample": "A B", "deck": "words" },
	{ "label": "Sayings",  "sample": "\"\"", "deck": "sayings" },
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
	b.pressed.connect(_on_choice.bind(choice["deck"]))
	return b


func _on_choice(deck: String) -> void:
	GameContext.quiz_deck = deck
	get_tree().change_scene_to_file(QUIZ)


func _go_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
