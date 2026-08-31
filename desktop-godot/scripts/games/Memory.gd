extends Control
## Memory — classic picture-pairs game.
##
## Difficulty scales through a ladder of grid sizes. Each level builds a
## fresh deck by picking N random pictures from the legacy tileset (via
## AssetLoader), duplicating each into a pair, and shuffling them into the
## GridContainer. Two cards may be face-up at once; a match locks the pair,
## a mismatch flips them back after a short delay. Clearing every pair
## plays a fanfare and offers the next level.

const MEMORY_MENU := "res://scenes/MemoryMenu.tscn"
const CARD_SCENE := preload("res://scenes/components/MemoryCard.tscn")

const VARIANT_LABEL := {
	"pictures": "Pictures", "lower": "lowercase", "upper": "UPPERCASE", "numbers": "Numbers",
}

# Difficulty ladder: columns x rows (product must be even).
const LEVELS := [
	{ "name": "Toddler", "cols": 2, "rows": 2 },
	{ "name": "Easy",    "cols": 4, "rows": 3 },
	{ "name": "Medium",  "cols": 4, "rows": 4 },
	{ "name": "Hard",    "cols": 5, "rows": 4 },
]

# Picture pool: tileset_2 has unique filenames, so AssetLoader resolves
# each unambiguously. 21 pictures cover the largest deck (10 pairs).
const CARD_IMAGES := [
	"cat", "pig", "bear", "hippopotamus",
	"penguin", "cow", "sheep", "turtle",
	"panda", "chicken", "redbird", "wolf",
	"monkey", "fox", "bluebirds", "elephant",
	"lion", "gnu", "bluebaby", "greenbaby",
	"frog",
]
const BACK_IMAGE := "card_back"
const FRONT_IMAGE := "card_front"

const SND_FLIP := "dealcard1.wav"
const SND_MATCH := "good.ogg"
const SND_MISMATCH := "wrong.ogg"
const SND_WIN := "winner.ogg"

const PRE_MATCH_DELAY := 0.25
const MISMATCH_DELAY := 0.8

var _level_index := 0
var _flips := 0
var _matched_pairs := 0
var _total_pairs := 0
var _open_cards: Array[MemoryCard] = []
var _busy := false            # blocks input during resolve / win

var _back_tex: Texture2D
var _front_tex: Texture2D
var _variant := "pictures"
var _say_names := false
var _names_btn: Button

@onready var _grid: GridContainer = %CardGrid
@onready var _flip_label: Label = %FlipCounter
@onready var _level_label: Label = %LevelIndicator
@onready var _back_button: Button = %BackButton
@onready var _popup: Control = %WinPopup
@onready var _popup_label: Label = %WinPopupLabel
@onready var _popup_button: Button = %WinPopupNext

@onready var _sfx_flip: AudioStreamPlayer = $Audio/FlipSound
@onready var _sfx_match: AudioStreamPlayer = $Audio/MatchSound
@onready var _sfx_mismatch: AudioStreamPlayer = $Audio/MismatchSound
@onready var _sfx_win: AudioStreamPlayer = $Audio/WinSound


func _ready() -> void:
	GameContext.theme_changed.connect(_style_hud)
	_style_hud()
	_variant = GameContext.memory_variant
	if not VARIANT_LABEL.has(_variant):
		_variant = "pictures"
	_back_tex = AssetLoader.get_texture(BACK_IMAGE)
	_front_tex = AssetLoader.get_texture(FRONT_IMAGE)
	_sfx_flip.stream = AssetLoader.get_stream(SND_FLIP)
	_sfx_match.stream = AssetLoader.get_stream(SND_MATCH)
	_sfx_mismatch.stream = AssetLoader.get_stream(SND_MISMATCH)
	_sfx_win.stream = AssetLoader.get_stream(SND_WIN)

	_back_button.pressed.connect(_go_home)
	_popup_button.pressed.connect(_on_popup_button)
	_popup.visible = false

	# "say the names" toggle — pictures deck only (§E.3)
	if _variant == "pictures" and GameContext.has_voice():
		_say_names = GameContext.name_toggle_get("memory")
		_names_btn = Button.new()
		_names_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_names_btn.offset_left = -170.0
		_names_btn.offset_top = 12.0
		_names_btn.offset_right = -16.0
		_names_btn.custom_minimum_size = Vector2(154, 38)
		_names_btn.focus_mode = Control.FOCUS_ALL
		_names_btn.pressed.connect(_toggle_names)
		add_child(_names_btn)
		_sync_names_btn()

	_start_level(0)


func _toggle_names() -> void:
	_say_names = not _say_names
	GameContext.name_toggle_set("memory", _say_names)
	_sync_names_btn()


func _sync_names_btn() -> void:
	if _names_btn:
		_names_btn.text = "🔊 names on" if _say_names else "🔇 names off"


# ---------------------------------------------------------------------------
# Level setup
# ---------------------------------------------------------------------------

func _start_level(index: int) -> void:
	_level_index = clampi(index, 0, LEVELS.size() - 1)
	var lvl: Dictionary = LEVELS[_level_index]

	_flips = 0
	_matched_pairs = 0
	_open_cards.clear()
	_busy = false
	_popup.visible = false

	var faces: Array = _deck_faces()
	_total_pairs = mini(int(lvl["cols"] * lvl["rows"] / 2.0), faces.size())
	_grid.columns = lvl["cols"]
	_level_label.text = "Level %d / %d" % [_level_index + 1, LEVELS.size()]
	_update_flip_label()
	_build_deck(faces)


## A face is { "id": String, "img": String("") , "glyph": String("") }.
func _deck_faces() -> Array:
	var out: Array = []
	match _variant:
		"lower":
			for c in "abcdefghijklmnopqrstuvwxyz":
				out.append({ "id": c, "glyph": c })
		"upper":
			for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
				out.append({ "id": c, "glyph": c })
		"numbers":
			for c in "0123456789":
				out.append({ "id": c, "glyph": c })
		_:
			for name in CARD_IMAGES:
				out.append({ "id": name, "img": name })
	return out


func _build_deck(faces: Array) -> void:
	for c in _grid.get_children():
		c.queue_free()

	var pool: Array = faces.duplicate()
	pool.shuffle()
	var chosen: Array = pool.slice(0, _total_pairs)

	var deck: Array = []
	for face in chosen:
		deck.append(face)
		deck.append(face)
	deck.shuffle()

	for face in deck:
		var card: MemoryCard = CARD_SCENE.instantiate()
		_grid.add_child(card)
		if face.has("img"):
			card.setup(face["id"], AssetLoader.get_texture(face["img"]), _back_tex)
		else:
			card.setup_glyph(face["id"], face["glyph"], _back_tex, _front_tex)
		card.card_clicked.connect(_on_card_clicked)


# ---------------------------------------------------------------------------
# Match logic
# ---------------------------------------------------------------------------

func _on_card_clicked(card: MemoryCard) -> void:
	if _busy or card in _open_cards or card.is_matched:
		return

	card.flip_up()
	_play(_sfx_flip)
	if _say_names and _variant == "pictures":
		GameContext.speak(GameContext.name_from_id(card.card_id))
	_open_cards.append(card)

	if _open_cards.size() < 2:
		return

	_flips += 1
	_update_flip_label()

	var a: MemoryCard = _open_cards[0]
	var b: MemoryCard = _open_cards[1]
	if a.card_id == b.card_id:
		_resolve_match(a, b)
	else:
		_resolve_mismatch(a, b)


func _resolve_match(a: MemoryCard, b: MemoryCard) -> void:
	_busy = true
	await get_tree().create_timer(PRE_MATCH_DELAY).timeout
	a.set_matched()
	b.set_matched()
	_play(_sfx_match)
	_matched_pairs += 1
	_open_cards.clear()
	_update_flip_label()
	_busy = false

	if _matched_pairs == _total_pairs:
		_on_level_complete()


func _resolve_mismatch(a: MemoryCard, b: MemoryCard) -> void:
	_busy = true
	await get_tree().create_timer(MISMATCH_DELAY).timeout
	_play(_sfx_mismatch)
	a.flip_down()
	b.flip_down()
	_open_cards.clear()
	_busy = false


# ---------------------------------------------------------------------------
# Win / navigation
# ---------------------------------------------------------------------------

func _on_level_complete() -> void:
	_busy = true
	_play(_sfx_win)
	var is_last := _level_index >= LEVELS.size() - 1
	_popup_label.text = "Great job!\nYou cleared %d pairs in %d flips." % [_total_pairs, _flips]
	_popup_button.text = "Back to Menu" if is_last else "Next Level"
	_popup.visible = true
	_popup_button.grab_focus()


func _on_popup_button() -> void:
	if _level_index >= LEVELS.size() - 1:
		_go_home()
	else:
		_start_level(_level_index + 1)


func _go_home() -> void:
	get_tree().change_scene_to_file(MEMORY_MENU)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _update_flip_label() -> void:
	_flip_label.text = "Pairs: %d / %d" % [_matched_pairs, _total_pairs]


func _play(player: AudioStreamPlayer) -> void:
	if player.stream != null:
		player.play()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_home()


## Themed HUD bar + divider (Design Policy §G).
func _style_hud() -> void:
	GameContext.style_hud_bar(self, 80.0, [_flip_label, _level_label], [])
