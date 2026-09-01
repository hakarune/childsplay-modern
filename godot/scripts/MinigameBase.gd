extends Control
class_name MinigameBase
## Common base for every activity scene.
##
## Handles the shared "activity state" lifecycle so individual games only
## implement their own logic. Emits `finished` when the child should be
## returned to the launcher dashboard.

signal finished

enum Phase { INTRO, PLAYING, SUMMARY }

var phase: int = Phase.INTRO
var score: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_start_intro()


func _start_intro() -> void:
	phase = Phase.INTRO
	# Subclasses may override to show instructions; default goes straight in.
	begin_play()


## Move into active play. Call from subclasses once assets are ready.
func begin_play() -> void:
	phase = Phase.PLAYING
	on_play_started()


## Wrap up the activity and hand control back to the launcher.
func end_activity() -> void:
	phase = Phase.SUMMARY
	on_play_finished()
	finished.emit()


# --- Hooks for subclasses -------------------------------------------------
func on_play_started() -> void:
	pass


func on_play_finished() -> void:
	pass
