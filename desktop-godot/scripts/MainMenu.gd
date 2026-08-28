extends Control
## MainMenu — the Childsplay Modern launcher dashboard.
##
## Shows a top bar (title, audio toggle, exit) and a grid of large icon
## buttons, one per minigame. Button focus/hover plays a blip and pressing
## a button hands off to a stubbed per-game scene loader.

# id -> display title, icon filenames (resolved via AssetLoader), and the
# scene that _load_minigame() will switch to once each activity exists.
const GAMES := [
	{
		"id": "packid", "title": "Packid",
		"icon": "packid.icon.png", "hover": "packid_ro.icon.png",
		"scene": "res://scenes/games/Packid.tscn",
	},
	{
		"id": "fallingletter", "title": "Falling Letter",
		"icon": "fallingletters.icon.png", "hover": "fallingletters_ro.icon.png",
		"scene": "res://scenes/games/FallingLetter.tscn",
	},
	{
		"id": "soundmemory", "title": "Sound Memory",
		"icon": "soundmemory.icon.png", "hover": "soundmemory_ro.icon.png",
		"scene": "res://scenes/games/SoundMemory.tscn",
	},
	{
		"id": "memory", "title": "Memory",
		"icon": "memory_sp.icon.png", "hover": "memory_sp_ro.icon.png",
		"scene": "res://scenes/games/Memory.tscn",
	},
	{
		"id": "billiards", "title": "Billiards",
		"icon": "billiard.icon.png", "hover": "billiard_ro.icon.png",
		"scene": "res://scenes/minigames/Billiards.tscn",
	},
]

const HOVER_SOUND := "button_hover.wav"
const CLICK_SOUND := "wahoo.wav"

@onready var _grid: GridContainer = %GameGrid
@onready var _audio_toggle: Button = %AudioToggle
@onready var _exit_button: Button = %ExitButton


func _ready() -> void:
	_wire_grid()

	_audio_toggle.toggled.connect(_on_audio_toggled)
	_audio_toggle.button_pressed = AssetLoader.is_master_muted()
	_refresh_audio_toggle_text()

	_exit_button.pressed.connect(_on_exit_pressed)
	_exit_button.mouse_entered.connect(_play_hover)
	_exit_button.focus_entered.connect(_play_hover)

	# Land keyboard/controller focus on the first game for immediate play.
	if _grid.get_child_count() > 0:
		_grid.get_child(0).grab_focus()


## Configure the TextureButtons declared in MainMenu.tscn: assign icons
## from AssetLoader and wire their signals. Buttons are matched to GAMES by
## order; a missing button is created so the menu still fills in.
func _wire_grid() -> void:
	_grid.columns = 3
	var buttons := _grid.get_children()

	for i in GAMES.size():
		var game: Dictionary = GAMES[i]
		var button: TextureButton
		if i < buttons.size() and buttons[i] is TextureButton:
			button = buttons[i] as TextureButton
		else:
			button = TextureButton.new()
			_grid.add_child(button)
			button.owner = self
		_configure_game_button(button, game)


func _configure_game_button(button: TextureButton, game: Dictionary) -> void:
	button.name = "%sButton" % game["id"].capitalize()
	button.custom_minimum_size = Vector2(300, 220)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = game["title"]

	var normal_tex := AssetLoader.get_texture(game["icon"])
	if normal_tex:
		button.texture_normal = normal_tex
	var hover_tex := AssetLoader.get_texture(game["hover"])
	if hover_tex:
		button.texture_hover = hover_tex
		button.texture_focused = hover_tex

	# Always caption the button so it stays usable if an icon is missing.
	var label := button.get_node_or_null("Caption") as Label
	if label == null:
		label = Label.new()
		label.name = "Caption"
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)
	label.text = game["title"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_size_override("font_size", 28)

	var id: String = game["id"]
	if not button.pressed.is_connected(_on_game_pressed):
		button.pressed.connect(_on_game_pressed.bind(id))
	if not button.mouse_entered.is_connected(_play_hover):
		button.mouse_entered.connect(_play_hover)
	if not button.focus_entered.is_connected(_play_hover):
		button.focus_entered.connect(_play_hover)


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_game_pressed(id: String) -> void:
	AssetLoader.play_sound(CLICK_SOUND)
	_load_minigame(id)


## Stubbed scene loader — swaps to the activity scene once it exists,
## otherwise logs the intent so the menu stays usable during development.
func _load_minigame(id: String) -> void:
	var game := _game_by_id(id)
	if game.is_empty():
		push_warning("[MainMenu] unknown minigame id: %s" % id)
		return

	var scene_path: String = game["scene"]
	if ResourceLoader.exists(scene_path):
		print("[MainMenu] launching %s -> %s" % [id, scene_path])
		get_tree().change_scene_to_file(scene_path)
	else:
		print("[MainMenu] (stub) would launch '%s' from %s" % [id, scene_path])


func _on_audio_toggled(muted: bool) -> void:
	AssetLoader.set_master_muted(muted)
	_refresh_audio_toggle_text()
	if not muted:
		AssetLoader.play_sound("volumecheck.wav")


func _on_exit_pressed() -> void:
	AssetLoader.play_sound(CLICK_SOUND)
	get_tree().quit()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _play_hover() -> void:
	AssetLoader.play_sound(HOVER_SOUND)


func _refresh_audio_toggle_text() -> void:
	_audio_toggle.text = "Audio: Off" if _audio_toggle.button_pressed else "Audio: On"


func _game_by_id(id: String) -> Dictionary:
	for game in GAMES:
		if game["id"] == id:
			return game
	return {}


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_exit_pressed()
