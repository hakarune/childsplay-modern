extends TextureButton
class_name SoundCard
## A sound-memory card. It hides a sound clip rather than a picture: click
## it to hear the clip. Cards have three looks:
##   idle    - blue panel with a speaker/sound icon
##   playing - amber panel, the icon pulses while the clip plays
##   matched - green panel, the revealed picture and a check mark, locked
##
## The card plays its own clip (via its child AudioStreamPlayer) and tells
## the board what happened through `card_clicked` / `sample_finished`.

signal card_clicked(card: SoundCard)
signal sample_finished(card: SoundCard)

const COL_IDLE := Color("3b6ea5")
const COL_PLAYING := Color("e0a021")
const COL_MATCHED := Color("4a9d5b")

var sound_id: String = ""
var sound_stream: AudioStream
var is_matched := false
var is_playing := false

var _idle_tex: Texture2D
var _reveal_tex: Texture2D
var _pulse: Tween

@onready var _bg: Panel = $Bg
@onready var _icon: TextureRect = $Icon
@onready var _check: Label = $Check
@onready var _player: AudioStreamPlayer = $Player


func _ready() -> void:
	pressed.connect(_on_pressed)
	_player.finished.connect(_on_sample_finished)
	_check.visible = false
	_paint(COL_IDLE)


## Configure the card. `idle_tex` is the face-down icon; `reveal_tex` is
## shown once the card is matched.
func setup(id: String, stream: AudioStream, idle_tex: Texture2D, reveal_tex: Texture2D) -> void:
	sound_id = id
	sound_stream = stream
	_idle_tex = idle_tex
	_reveal_tex = reveal_tex
	is_matched = false
	is_playing = false
	if is_node_ready():
		_icon.texture = _idle_tex
		_check.visible = false
		disabled = false
		_paint(COL_IDLE)


func _on_pressed() -> void:
	if is_matched or is_playing:
		return
	play_sample()
	card_clicked.emit(self)


## Start this card's clip and switch to the pulsing "playing" look.
func play_sample() -> void:
	if sound_stream == null:
		# Nothing to play - still report "finished" so the board can advance.
		is_playing = false
		call_deferred("emit_signal", "sample_finished", self)
		return
	is_playing = true
	_player.stream = sound_stream
	_player.play()
	_paint(COL_PLAYING)
	_start_pulse()


func _on_sample_finished() -> void:
	is_playing = false
	_stop_pulse()
	if not is_matched:
		_paint(COL_IDLE)
	sample_finished.emit(self)


## Stop the clip without emitting sample_finished (board interrupting).
func stop_sample() -> void:
	if _player.playing:
		_player.stop()
	is_playing = false
	_stop_pulse()
	if not is_matched:
		_paint(COL_IDLE)


func set_matched() -> void:
	is_matched = true
	is_playing = false
	disabled = true
	_stop_pulse()
	if _reveal_tex != null:
		_icon.texture = _reveal_tex
	_check.visible = true
	_paint(COL_MATCHED)
	var t := create_tween()
	t.tween_property(_icon, "scale", Vector2(1.12, 1.12), 0.12).set_ease(Tween.EASE_OUT)
	t.tween_property(_icon, "scale", Vector2.ONE, 0.12)


func reset_to_idle() -> void:
	if is_matched:
		return
	is_playing = false
	_stop_pulse()
	_icon.texture = _idle_tex
	_check.visible = false
	_paint(COL_IDLE)


## Enable/disable clicks for the "busy" window (matched cards stay locked).
func set_interactable(v: bool) -> void:
	disabled = is_matched or not v


# --- visuals -------------------------------------------------------------

func _paint(color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(4)
	sb.border_color = color.lightened(0.3)
	_bg.add_theme_stylebox_override("panel", sb)


func _start_pulse() -> void:
	_stop_pulse()
	_icon.pivot_offset = _icon.size * 0.5
	_pulse = create_tween()
	_pulse.set_loops()
	_pulse.tween_property(_icon, "scale", Vector2(1.18, 1.18), 0.35).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_icon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)


func _stop_pulse() -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_pulse = null
	if is_instance_valid(_icon):
		_icon.scale = Vector2.ONE
