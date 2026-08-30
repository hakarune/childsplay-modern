extends Control
## SoundMemory - like Memory, but each card hides a sound instead of a
## picture. Click a card to hear its clip; find the two cards that sound
## the same. Matched pairs reveal the matching picture.

const MAIN_MENU := "res://scenes/MemoryMenu.tscn"
const CARD_SCENE := preload("res://scenes/components/SoundCard.tscn")

# Difficulty ladder (columns x rows, product must be even): 2x2, 4x2, 4x3.
const LEVELS := [
	{ "name": "Toddler", "cols": 2, "rows": 2 },
	{ "name": "Easy",    "cols": 4, "rows": 2 },
	{ "name": "Medium",  "cols": 4, "rows": 3 },
]

# Sound ids that exist in SoundmemoryData/Sounds AND have a matching
# picture resolvable through AssetLoader (FindsoundData images).
const SOUND_POOL := [
	"cow", "dog", "frog", "lion", "rooster", "sheep", "elephant", "horse",
	"drum", "flute", "guitar", "harp", "piano", "violin", "banjo", "cello",
	"boat", "car", "plane", "police", "rocket",
]
const IDLE_ICON := "soundbut.png"

const SND_MATCH := "good.ogg"
const SND_MISMATCH := "wrong.ogg"
const SND_FANFARE := "winner.ogg"

const MISMATCH_PAD := 0.35
const MISMATCH_HOLD := 0.55

var _level_index := 0
var _attempts := 0
var _matched_pairs := 0
var _total_pairs := 0

var _first: SoundCard
var _second: SoundCard
var _busy := false

var _idle_tex: Texture2D

@onready var _grid: GridContainer = %CardGrid
@onready var _attempt_label: Label = %AttemptLabel
@onready var _level_label: Label = %LevelIndicator
@onready var _back_button: Button = %BackButton
@onready var _popup: Control = %WinPopup
@onready var _popup_label: Label = %WinPopupLabel
@onready var _popup_button: Button = %WinPopupNext
@onready var _popup_menu: Button = %WinPopupMenu

@onready var _sfx_match: AudioStreamPlayer = $Audio/MatchSound
@onready var _sfx_mismatch: AudioStreamPlayer = $Audio/MismatchSound
@onready var _sfx_fanfare: AudioStreamPlayer = $Audio/FanfareSound


func _ready() -> void:
	GameContext.theme_changed.connect(_style_hud)
	_style_hud()
	_idle_tex = AssetLoader.get_texture(IDLE_ICON)
	_sfx_match.stream = AssetLoader.get_stream(SND_MATCH)
	_sfx_mismatch.stream = AssetLoader.get_stream(SND_MISMATCH)
	_sfx_fanfare.stream = AssetLoader.get_stream(SND_FANFARE)

	_back_button.pressed.connect(_go_home)
	_popup_menu.pressed.connect(_go_home)
	_popup_button.pressed.connect(_on_popup_next)
	_popup.visible = false

	_start_level(0)


# ---------------------------------------------------------------------------
# Level setup
# ---------------------------------------------------------------------------

func _start_level(index: int) -> void:
	_level_index = clampi(index, 0, LEVELS.size() - 1)
	var lvl: Dictionary = LEVELS[_level_index]

	_attempts = 0
	_matched_pairs = 0
	_first = null
	_second = null
	_busy = false
	_popup.visible = false

	_total_pairs = int(lvl["cols"] * lvl["rows"] / 2.0)
	_grid.columns = lvl["cols"]
	_level_label.text = "Level %d / %d  -  %s" % [_level_index + 1, LEVELS.size(), lvl["name"]]
	_update_attempts()
	_build_deck()


func _build_deck() -> void:
	for c in _grid.get_children():
		c.queue_free()

	var pool: Array = SOUND_POOL.duplicate()
	pool.shuffle()
	var chosen: Array = pool.slice(0, _total_pairs)

	var deck: Array = []
	for sound_id in chosen:
		deck.append(sound_id)
		deck.append(sound_id)
	deck.shuffle()

	for sound_id in deck:
		var card: SoundCard = CARD_SCENE.instantiate()
		_grid.add_child(card)
		card.setup(
			sound_id,
			AssetLoader.get_stream(sound_id + ".ogg"),
			_idle_tex,
			AssetLoader.get_texture(sound_id + ".png")
		)
		card.card_clicked.connect(_on_card_clicked)
		card.sample_finished.connect(_on_sample_finished)


# ---------------------------------------------------------------------------
# Match logic
# ---------------------------------------------------------------------------

func _on_card_clicked(card: SoundCard) -> void:
	if _busy or card.is_matched or card == _first:
		return

	if _first == null:
		_first = card
		return

	# Second pick: lock the board, let this clip finish, then compare.
	_second = card
	_attempts += 1
	_update_attempts()
	_busy = true
	_set_cards_interactable(false)
	if _first.is_playing:
		_first.stop_sample()


func _on_sample_finished(card: SoundCard) -> void:
	if _busy and card == _second:
		_compare()


func _compare() -> void:
	if _first.sound_id == _second.sound_id:
		_play(_sfx_match)
		_first.set_matched()
		_second.set_matched()
		_matched_pairs += 1
		_update_attempts()
		_reset_turn(true)
		if _matched_pairs == _total_pairs:
			_on_level_complete()
	else:
		await get_tree().create_timer(MISMATCH_PAD).timeout
		_play(_sfx_mismatch)
		await get_tree().create_timer(MISMATCH_HOLD).timeout
		_first.reset_to_idle()
		_second.reset_to_idle()
		_reset_turn(true)


func _reset_turn(reenable: bool) -> void:
	_first = null
	_second = null
	_busy = false
	if reenable:
		_set_cards_interactable(true)


func _set_cards_interactable(v: bool) -> void:
	for c in _grid.get_children():
		if c is SoundCard:
			c.set_interactable(v)


# ---------------------------------------------------------------------------
# Win / navigation
# ---------------------------------------------------------------------------

func _on_level_complete() -> void:
	_busy = true
	_play(_sfx_fanfare)
	var is_last := _level_index >= LEVELS.size() - 1
	_popup_label.text = "You matched every sound\nin %d tries!" % _attempts
	_popup_button.visible = not is_last
	_popup_button.text = "Next Level"
	_popup.visible = true
	(_popup_menu if is_last else _popup_button).grab_focus()


func _on_popup_next() -> void:
	_start_level(_level_index + 1)


func _go_home() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _update_attempts() -> void:
	_attempt_label.text = "Tries: %d    Pairs: %d / %d" % [_attempts, _matched_pairs, _total_pairs]


func _play(player: AudioStreamPlayer) -> void:
	if player.stream != null:
		player.play()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_home()


## Themed HUD bar + divider (Design Policy §G).
func _style_hud() -> void:
	GameContext.style_hud_bar(self, 80.0, [_level_label], [])
