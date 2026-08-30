extends Control
## MainMenu — the Childsplay Modern launcher dashboard (Design Policy §F).
##
## A responsive, paginated kiosk grid of 1:1 icon tiles. Columns and tile
## size come from the viewport; if the rows don't fit at the minimum icon
## size the extra tiles paginate rather than shrink. Chrome (top-right):
## light/dark toggle, artwork-style toggle, sound popover, exit — the
## desktop twin of the web menu chrome.

const GAMES := [
	{"id": "memory", "title": "Memory", "scene": "res://scenes/MemoryMenu.tscn"},
	{"id": "fallingletter", "title": "Falling Letter", "scene": "res://scenes/games/FallingLetter.tscn"},
	{"id": "findsound", "title": "Find Sound", "scene": "res://scenes/games/FindSound.tscn"},
	{"id": "puzzle", "title": "Puzzle", "scene": "res://scenes/games/Puzzle.tscn"},
	{"id": "findit", "title": "Find It", "scene": "res://scenes/games/FindIt.tscn"},
	{"id": "aquarium", "title": "Aquarium", "scene": "res://scenes/games/Aquarium.tscn"},
	{"id": "pong", "title": "Pong", "scene": "res://scenes/games/Pong.tscn"},
	{"id": "fourrow", "title": "Four in a Row", "scene": "res://scenes/games/FourRow.tscn"},
	{"id": "flashcards", "title": "Flashcards", "scene": "res://scenes/games/Flashcards.tscn"},
	{"id": "blockbreaker", "title": "Block Breaker", "scene": "res://scenes/games/BlockBreaker.tscn"},
	{"id": "simon", "title": "Simon", "scene": "res://scenes/games/Simon.tscn"},
	{"id": "electro", "title": "Electro", "scene": "res://scenes/games/Electro.tscn"},
	{"id": "tictactoe", "title": "Tic Tac Toe", "scene": "res://scenes/games/TicTacToe.tscn"},
	{"id": "wipe", "title": "Wipe", "scene": "res://scenes/games/Wipe.tscn"},
	{"id": "ichanger", "title": "Image Changer", "scene": "res://scenes/games/ImageChanger.tscn"},
	{"id": "numbers", "title": "Numbers", "scene": "res://scenes/games/Numbers.tscn"},
	{"id": "synonyms", "title": "Word Maker", "scene": "res://scenes/games/WordMaker.tscn"},
	{"id": "billiards", "title": "Billiards", "scene": "res://scenes/games/Billiards.tscn"},
	{"id": "packid", "title": "Packid", "scene": "res://scenes/games/Packid.tscn"},
]

const TILE_SCRIPT := preload("res://scripts/MenuTile.gd")

const HOVER_SOUND := "button_hover.wav"
const CLICK_SOUND := "wahoo.wav"

const TARGET_TILE := 260.0   # §F.3.1
const MAX_TILE := 300.0
const MIN_ICON := 96.0       # §F.1.4
const GAP := 24.0

@onready var _bg: ColorRect = $Background
@onready var _title: Label = %Title
@onready var _chrome: HBoxContainer = %Chrome
@onready var _tile_layer: Control = %TileLayer
@onready var _pager: HBoxContainer = %Pager
@onready var _page_label: Label = %PageLabel
@onready var _prev_btn: Button = %PrevPage
@onready var _next_btn: Button = %NextPage

var _theme_btn: Button
var _art_btn: Button
var _sound_btn: Button
var _sound_pop: PopupPanel
var _sound_checks := {}

var _tiles: Array[Button] = []
var _icons: Dictionary = {}
var _page := 0
var _pages := 1
var _per_page := 8
var _cols := 4


func _ready() -> void:
	AssetLoader.stop_all()   # nothing from the last game keeps sounding (§E.1)

	for g in GAMES:
		_icons[g.id] = AssetLoader.get_texture(g.id)

	_build_chrome()
	_apply_palette()

	GameContext.theme_changed.connect(_on_theme_changed)
	if AssetLoader.has_signal("art_style_changed"):
		AssetLoader.art_style_changed.connect(_on_art_changed)

	_prev_btn.pressed.connect(func() -> void: _turn_page(-1))
	_next_btn.pressed.connect(func() -> void: _turn_page(1))

	resized.connect(_relayout)
	_relayout.call_deferred()


# ---------------------------------------------------------------------------
# Layout (§F.1 / §F.3)
# ---------------------------------------------------------------------------

func _relayout() -> void:
	var avail := _tile_layer.size
	if avail.x < 50.0 or avail.y < 50.0:
		return

	_cols = clampi(int(floor(avail.x / TARGET_TILE)), 2, 5)
	var width_edge := (avail.x - GAP * (_cols - 1)) / float(_cols)
	var edge: float = minf(width_edge, MAX_TILE)
	edge = minf(edge, avail.y * 0.46)
	edge = maxf(edge, MIN_ICON + 40.0)      # room for icon + caption band

	var rows_per_page := maxi(1, int(floor((avail.y + GAP) / (edge + GAP))))
	_per_page = _cols * rows_per_page
	_pages = maxi(1, int(ceil(float(GAMES.size()) / float(_per_page))))
	_page = clampi(_page, 0, _pages - 1)

	var start := _page * _per_page
	var shown: int = mini(_per_page, GAMES.size() - start)
	var rows := int(ceil(float(shown) / float(_cols)))

	var grid_w := _cols * edge + (_cols - 1) * GAP
	var grid_h := rows * edge + (rows - 1) * GAP
	var ox := (avail.x - grid_w) * 0.5
	var oy := maxf(0.0, (avail.y - grid_h) * 0.5)

	for t in _tiles:
		t.queue_free()
	_tiles.clear()

	for i in shown:
		var g: Dictionary = GAMES[start + i]
		var tile := Button.new()
		tile.set_script(TILE_SCRIPT)
		_tile_layer.add_child(tile)
		tile.setup(g.id, g.title, _icons.get(g.id))
		tile.position = Vector2(ox + (i % _cols) * (edge + GAP),
			oy + (i / _cols) * (edge + GAP))
		tile.size = Vector2(edge, edge)
		tile.pressed.connect(_on_game_pressed.bind(g.id))
		tile.mouse_entered.connect(_play_hover)
		tile.focus_entered.connect(_play_hover)
		_tiles.append(tile)

	# focus chaining left<->right within a page
	for i in _tiles.size():
		var t := _tiles[i]
		t.focus_neighbor_left = t.get_path_to(_tiles[maxi(0, i - 1)])
		t.focus_neighbor_right = t.get_path_to(_tiles[mini(_tiles.size() - 1, i + 1)])
		var below := mini(_tiles.size() - 1, i + _cols)
		var above := maxi(0, i - _cols)
		t.focus_neighbor_bottom = t.get_path_to(_tiles[below])
		t.focus_neighbor_top = t.get_path_to(_tiles[above])

	_pager.visible = _pages > 1
	_page_label.text = "Page %d / %d" % [_page + 1, _pages]
	_prev_btn.disabled = _page <= 0
	_next_btn.disabled = _page >= _pages - 1

	if _tiles.size() > 0 and not _any_tile_has_focus():
		_tiles[0].grab_focus()


func _any_tile_has_focus() -> bool:
	for t in _tiles:
		if t.has_focus():
			return true
	return false


func _turn_page(delta: int) -> void:
	var p := clampi(_page + delta, 0, _pages - 1)
	if p == _page:
		return
	_page = p
	_play_hover()
	_relayout()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_exit_pressed()
	elif event is InputEventScreenDrag and absf(event.relative.x) > 24.0:
		_turn_page(-1 if event.relative.x > 0.0 else 1)
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Chrome (§F.4)
# ---------------------------------------------------------------------------

func _build_chrome() -> void:
	_theme_btn = Button.new()
	_theme_btn.custom_minimum_size = Vector2(150, 48)
	_theme_btn.focus_mode = Control.FOCUS_ALL
	_sync_theme_btn()
	_theme_btn.pressed.connect(func() -> void:
		GameContext.toggle_theme()
		_play_hover())
	_chrome.add_child(_theme_btn)

	var styles := AssetLoader.list_art_styles() if AssetLoader.has_method("list_art_styles") else PackedStringArray(["classic"])
	if styles.size() > 1:
		_art_btn = Button.new()
		_art_btn.custom_minimum_size = Vector2(170, 48)
		_art_btn.focus_mode = Control.FOCUS_ALL
		_sync_art_btn()
		_art_btn.pressed.connect(_cycle_art_style)
		_chrome.add_child(_art_btn)

	_sound_btn = Button.new()
	_sound_btn.custom_minimum_size = Vector2(150, 48)
	_sound_btn.focus_mode = Control.FOCUS_ALL
	_chrome.add_child(_sound_btn)
	_build_sound_popover()

	var exit_btn := Button.new()
	exit_btn.text = "Exit"
	exit_btn.custom_minimum_size = Vector2(110, 48)
	exit_btn.focus_mode = Control.FOCUS_ALL
	exit_btn.pressed.connect(_on_exit_pressed)
	exit_btn.focus_entered.connect(_play_hover)
	_chrome.add_child(exit_btn)


func _sync_theme_btn() -> void:
	_theme_btn.text = "Theme: Dark" if GameContext.theme_mode == "dark" else "Theme: Light"


func _sync_art_btn() -> void:
	if _art_btn == null:
		return
	_art_btn.text = "Art: %s" % AssetLoader.art_style.capitalize()


func _cycle_art_style() -> void:
	var styles := AssetLoader.list_art_styles()
	if styles.size() < 2:
		return
	var i := styles.find(AssetLoader.art_style)
	AssetLoader.set_art_style(styles[(i + 1) % styles.size()])
	_play_hover()


func _on_theme_changed() -> void:
	_sync_theme_btn()
	_apply_palette()
	for t in _tiles:
		t.queue_redraw()


func _on_art_changed() -> void:
	_sync_art_btn()
	for g in GAMES:
		_icons[g.id] = AssetLoader.get_texture(g.id)
	_relayout()


func _apply_palette() -> void:
	if _bg:
		_bg.color = GameContext.c("bg")
	if _title:
		_title.add_theme_color_override("font_color", GameContext.c("text"))
	if _page_label:
		_page_label.add_theme_color_override("font_color", GameContext.c("text_muted"))


# ---------------------------------------------------------------------------
# Sound popover (§E.3) — unchanged behaviour, rebuilt against the new button
# ---------------------------------------------------------------------------

func _build_sound_popover() -> void:
	_sound_btn.pressed.connect(_open_sound_popover)
	_sound_btn.focus_entered.connect(_play_hover)

	_sound_pop = PopupPanel.new()
	add_child(_sound_pop)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(220, 0)
	_sound_pop.add_child(box)
	var heading := Label.new()
	heading.text = "Sound"
	box.add_child(heading)
	var labels := {"music": "Music", "sfx": "Effects", "voice": "Voice"}
	for channel in ["music", "sfx", "voice"]:
		var cb := CheckBox.new()
		cb.text = labels[channel]
		cb.custom_minimum_size = Vector2(200, 44)
		cb.button_pressed = not AssetLoader.is_channel_muted(channel)
		cb.toggled.connect(_on_channel_toggled.bind(channel))
		box.add_child(cb)
		_sound_checks[channel] = cb
	_refresh_sound_btn()


func _open_sound_popover() -> void:
	_play_hover()
	for channel in _sound_checks:
		_sound_checks[channel].set_pressed_no_signal(not AssetLoader.is_channel_muted(channel))
	var anchor := _sound_btn.get_global_rect()
	_sound_pop.popup(Rect2i(
		Vector2i(int(anchor.position.x), int(anchor.position.y + anchor.size.y + 4)),
		Vector2i(240, 210)))


func _on_channel_toggled(pressed: bool, channel: String) -> void:
	AssetLoader.set_channel_muted(channel, not pressed)
	_refresh_sound_btn()
	if pressed and channel == "sfx":
		AssetLoader.play_sound("volumecheck.wav")


func _refresh_sound_btn() -> void:
	var any_on := false
	for channel in ["music", "sfx", "voice"]:
		if not AssetLoader.is_channel_muted(channel):
			any_on = true
			break
	_sound_btn.text = "Sound: On" if any_on else "Sound: Off"


# ---------------------------------------------------------------------------
# Launch
# ---------------------------------------------------------------------------

func _on_game_pressed(id: String) -> void:
	AssetLoader.play_sound(CLICK_SOUND)
	var game := _game_by_id(id)
	if game.is_empty():
		return
	var scene_path: String = game["scene"]
	if ResourceLoader.exists(scene_path):
		AssetLoader.stop_all()
		GameContext.reset_pools(id + ":")
		get_tree().change_scene_to_file(scene_path)
	else:
		push_warning("[MainMenu] scene missing: %s" % scene_path)


func _on_exit_pressed() -> void:
	AssetLoader.play_sound(CLICK_SOUND)
	get_tree().quit()


func _play_hover() -> void:
	AssetLoader.play_sound(HOVER_SOUND)


func _game_by_id(id: String) -> Dictionary:
	for game in GAMES:
		if game["id"] == id:
			return game
	return {}
