extends Control
## FallingLetter — type the letter on each balloon before it reaches the
## ground. Miss three and the round ends with a friendly score board.
##
## Letters spawn on a Timer from random X positions at the top of the play
## area. Typing a letter pops the LOWEST matching balloon (most urgent).
## As the score climbs, balloons fall faster and spawn more often.

const MAIN_MENU := "res://scenes/MainMenu.tscn"
const LETTER_SCENE := preload("res://scenes/components/LetterItem.tscn")

const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

const START_LIVES := 3
const DANGER_ZONE_H := 90.0

const START_SPEED := 90.0        # px/sec
const SPEED_PER_POINT := 6.0
const MAX_SPEED := 340.0

const START_SPAWN := 1.9         # seconds between balloons
const SPAWN_PER_POINT := 0.045
const MIN_SPAWN := 0.65

const BUBBLE_COLORS := [
	Color("ff6b6b"), Color("ffd93d"), Color("6bcB77"),
	Color("4d96ff"), Color("b980f0"), Color("ff9f45"),
]

const SND_SPAWN := "pick.wav"
const SND_HIT := "zap.ogg"
const SND_MISS := "bump.wav"
const SND_END := "winner.ogg"

const HEART_FULL := "♥"
const HEART_EMPTY := "♡"

var _score := 0
var _lives := START_LIVES
var _active := false
var _letters: Array[LetterItem] = []

@onready var _play_area: Control = %PlayArea
@onready var _score_label: Label = %ScoreLabel
@onready var _lives_box: HBoxContainer = %LivesBox
@onready var _back_button: Button = %BackButton
@onready var _spawn_timer: Timer = %SpawnTimer
@onready var _game_over_panel: Control = %GameOverPanel
@onready var _summary: Label = %GameOverSummary
@onready var _play_again: Button = %PlayAgainButton
@onready var _menu_button: Button = %MenuButton

@onready var _sfx_spawn: AudioStreamPlayer = $Audio/SpawnSound
@onready var _sfx_hit: AudioStreamPlayer = $Audio/HitSound
@onready var _sfx_miss: AudioStreamPlayer = $Audio/MissSound
@onready var _sfx_end: AudioStreamPlayer = $Audio/EndSound


func _ready() -> void:
	_sfx_spawn.stream = AssetLoader.get_stream(SND_SPAWN)
	_sfx_hit.stream = AssetLoader.get_stream(SND_HIT)
	_sfx_miss.stream = AssetLoader.get_stream(SND_MISS)
	_sfx_end.stream = AssetLoader.get_stream(SND_END)

	_back_button.pressed.connect(_go_home)
	_menu_button.pressed.connect(_go_home)
	_play_again.pressed.connect(_start_game)
	_spawn_timer.timeout.connect(_on_spawn_timer)

	_start_game()


# ---------------------------------------------------------------------------
# Round lifecycle
# ---------------------------------------------------------------------------

func _start_game() -> void:
	for letter in _letters:
		if is_instance_valid(letter):
			letter.queue_free()
	_letters.clear()

	_score = 0
	_lives = START_LIVES
	_active = true
	_game_over_panel.visible = false
	_update_score()
	_update_lives()

	_spawn_timer.wait_time = START_SPAWN
	_spawn_timer.start()
	_spawn_letter()


func _game_over() -> void:
	_active = false
	_spawn_timer.stop()
	for letter in _letters:
		if is_instance_valid(letter):
			letter.freeze()
	_play(_sfx_end)
	_summary.text = "You caught %d letter%s!" % [_score, "" if _score == 1 else "s"]
	_game_over_panel.visible = true
	_play_again.grab_focus()


# ---------------------------------------------------------------------------
# Spawning & difficulty
# ---------------------------------------------------------------------------

func _on_spawn_timer() -> void:
	if _active:
		_spawn_letter()


func _spawn_letter() -> void:
	var letter: LetterItem = LETTER_SCENE.instantiate()
	var ch := ALPHABET[randi() % ALPHABET.length()]
	var area := _play_area.size
	var boundary_y := area.y - DANGER_ZONE_H
	var max_x: float = maxf(0.0, area.x - LetterItem.SIZE.x)

	_play_area.add_child(letter)
	letter.position = Vector2(randf_range(0.0, max_x), -LetterItem.SIZE.y)
	letter.setup(ch, _current_speed(), boundary_y, BUBBLE_COLORS.pick_random())
	letter.missed.connect(_on_letter_missed)
	_letters.append(letter)

	_play(_sfx_spawn)
	_spawn_timer.wait_time = _current_spawn_interval()


func _current_speed() -> float:
	return minf(MAX_SPEED, START_SPEED + _score * SPEED_PER_POINT)


func _current_spawn_interval() -> float:
	return maxf(MIN_SPAWN, START_SPAWN - _score * SPAWN_PER_POINT)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_home()
		return

	if not _active:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	var key: int = event.keycode
	if key >= KEY_A and key <= KEY_Z:
		_try_hit(String.chr(key))
		get_viewport().set_input_as_handled()


## Pop the lowest on-screen balloon whose letter matches `ch`.
func _try_hit(ch: String) -> void:
	var target: LetterItem = null
	for letter in _letters:
		if not is_instance_valid(letter):
			continue
		if letter.target_char == ch and (target == null or letter.position.y > target.position.y):
			target = letter

	if target == null:
		return  # no match: no penalty, just ignore

	_letters.erase(target)
	target.pop()
	_score += 1
	_update_score()
	_play(_sfx_hit)


func _on_letter_missed(letter: LetterItem) -> void:
	_letters.erase(letter)
	if not _active:
		return
	_lives -= 1
	_play(_sfx_miss)
	_update_lives()
	if _lives <= 0:
		_game_over()


# ---------------------------------------------------------------------------
# HUD helpers
# ---------------------------------------------------------------------------

func _update_score() -> void:
	_score_label.text = "Score: %d" % _score


func _update_lives() -> void:
	var hearts := _lives_box.get_children()
	for i in hearts.size():
		hearts[i].text = HEART_FULL if i < _lives else HEART_EMPTY
		hearts[i].modulate.a = 1.0 if i < _lives else 0.4


func _go_home() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


func _play(player: AudioStreamPlayer) -> void:
	if player.stream != null:
		player.play()
