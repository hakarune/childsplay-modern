extends Control
## Simon — repeat the growing colour-and-tone sequence. Six levels; the
## target length grows 2 → 7. A wrong tap just replays the same sequence
## (no lives, no game-over) — only forward progress.

const MAIN_MENU := "res://scenes/MainMenu.tscn"
const HUD := 56.0
const TARGETS := [2, 3, 4, 5, 6, 7, 8, 9]

# quadrant colour (on / off) + tone frequency. Order = TL, TR, BL, BR.
const PADS := [
	{ "on": "ff5a5a", "off": "7a2f2f", "freq": 262.0 },
	{ "on": "ffd93d", "off": "7a6a1c", "freq": 330.0 },
	{ "on": "5fce6b", "off": "2c5f32", "freq": 392.0 },
	{ "on": "4d96ff", "off": "2b4d7a", "freq": 494.0 },
]

const SND_GOOD := "good.ogg"
const SND_WRONG := "wrong.ogg"
const SND_WIN := "winner.ogg"

var _level := 0
var _seq: Array[int] = []
var _phase := "idle"              # idle | show | input | pause
var _show_state := "start"        # start | lit | gap
var _show_idx := 0
var _input_idx := 0
var _lit := -1
var _t := 0.0
var _flash := ""                  # "" | "good" | "wrong"
var _flash_t := 0.0
var _last_phase := ""

var _rects: Array[Rect2] = []
var _board := Rect2()
var _start_btn := Rect2()
var _tones: Array[AudioStreamWAV] = []

@onready var _info: Label = %InfoLabel
@onready var _hint: Label = %HintLabel
@onready var _back_button: Button = %BackButton
@onready var _popup: Control = %WinPopup
@onready var _popup_label: Label = %WinPopupLabel
@onready var _popup_next: Button = %WinPopupNext
@onready var _popup_replay: Button = %WinPopupReplay
@onready var _popup_menu: Button = %WinPopupMenu
@onready var _tone_player: AudioStreamPlayer = $Audio/Tone
@onready var _sfx_good: AudioStreamPlayer = $Audio/Good
@onready var _sfx_wrong: AudioStreamPlayer = $Audio/Wrong
@onready var _sfx_win: AudioStreamPlayer = $Audio/Win


func _ready() -> void:
	GameContext.theme_changed.connect(queue_redraw)
	for p in PADS:
		_tones.append(_make_tone(p["freq"], 0.42))
	var al := get_node_or_null("/root/AssetLoader")
	if al != null:
		_sfx_good.stream = al.get_stream(SND_GOOD)
		_sfx_wrong.stream = al.get_stream(SND_WRONG)
		_sfx_win.stream = al.get_stream(SND_WIN)
	_back_button.pressed.connect(_go_home)
	_popup_menu.pressed.connect(_go_home)
	_popup_replay.pressed.connect(func() -> void: _start_level(_level))
	_popup_next.pressed.connect(func() -> void: _start_level(_level + 1))
	_popup.visible = false
	resized.connect(_geo)
	_start_level(0)


func _make_tone(freq: float, secs: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * secs)
	var buf := PackedByteArray()
	buf.resize(n * 2)
	for i in n:
		var tt := float(i) / rate
		var env: float = minf(tt / 0.02, 1.0) * exp(-tt * 6.0)
		var v: float = sin(TAU * freq * tt) * env * 0.5
		buf.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = buf
	return w


func _start_level(n: int) -> void:
	_level = clampi(n, 0, TARGETS.size() - 1)
	_seq.clear()
	_phase = "idle"
	_show_state = "start"
	_show_idx = 0
	_input_idx = 0
	_lit = -1
	_t = 0.0
	_flash = ""
	_popup.visible = false
	_geo()
	_update_hud()


func _geo() -> void:
	var avail_h := size.y - HUD - 40.0
	var s: float = minf(size.x * 0.62, avail_h)
	_board = Rect2((size.x - s) / 2.0, HUD + 20.0 + (avail_h - s) / 2.0, s, s)
	var gap := s * 0.05
	var half := (s - gap) / 2.0
	var bx := _board.position.x
	var by := _board.position.y
	_rects = [
		Rect2(bx, by, half, half),
		Rect2(bx + half + gap, by, half, half),
		Rect2(bx, by + half + gap, half, half),
		Rect2(bx + half + gap, by + half + gap, half, half),
	]
	_start_btn = Rect2(size.x / 2.0 - 120.0, by + s / 2.0 - 40.0, 240.0, 80.0)


func _step_time() -> Vector2:
	var k := maxf(0.55, 1.0 - _level * 0.06)
	return Vector2(0.44 * k, 0.18 * k)


func _tone(idx: int, _dur := 0.0) -> void:
	if idx < 0 or idx >= _tones.size():
		return
	_tone_player.stream = _tones[idx]
	_tone_player.play()


func _begin_show() -> void:
	_phase = "show"
	_show_state = "start"
	_show_idx = 0
	_lit = -1
	_t = 0.0


func _append_and_show() -> void:
	_seq.append(randi() % 4)
	_phase = "pause"
	_t = 0.0


func _process(delta: float) -> void:
	if _flash != "":
		_flash_t += delta
		if _flash_t > 0.5:
			_flash = ""

	if _phase == "pause":
		_t += delta
		if _t > 0.55:
			_begin_show()
	elif _phase == "show":
		var st := _step_time()
		_t += delta
		if _show_state == "start":
			if _show_idx >= _seq.size():
				_phase = "input"
				_input_idx = 0
				_lit = -1
			else:
				_lit = _seq[_show_idx]
				_tone(_lit)
				_show_state = "lit"
				_t = 0.0
		elif _show_state == "lit" and _t >= st.x:
			_lit = -1
			_show_state = "gap"
			_t = 0.0
		elif _show_state == "gap" and _t >= st.y:
			_show_idx += 1
			_show_state = "start"
			_t = 0.0

	if _phase != _last_phase:
		_last_phase = _phase
		_update_hud()

	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _popup.visible:
		return
	var pos := Vector2.ZERO
	var tapped := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		pos = event.position
		tapped = true
	elif event is InputEventScreenTouch and not event.pressed:
		pos = event.position
		tapped = true
	if not tapped:
		return

	if _phase == "idle":
		if _start_btn.has_point(pos):
			_seq = [randi() % 4] as Array[int]
			_begin_show()
		return

	if _phase != "input":
		return

	var p := -1
	for i in _rects.size():
		if _rects[i].has_point(pos):
			p = i
			break
	if p < 0:
		return

	_lit = p
	_tone(p)

	if p == _seq[_input_idx]:
		_input_idx += 1
		if _input_idx >= _seq.size():
			if _seq.size() >= int(TARGETS[_level]):
				_level_done()
			else:
				_flash = "good"
				_flash_t = 0.0
				_play(_sfx_good)
				_append_and_show()
				_update_hud()
	else:
		_flash = "wrong"
		_flash_t = 0.0
		_play(_sfx_wrong)
		_phase = "pause"
		_t = -0.3


func _level_done() -> void:
	var last := _level >= TARGETS.size() - 1
	_phase = "idle"
	_lit = -1
	if last:
		_play(_sfx_win)
		_popup_label.text = "You matched every sequence!"
		_popup_next.visible = false
		_popup_replay.grab_focus()
	else:
		_play(_sfx_good)
		_popup_label.text = "Level %d done!" % (_level + 1)
		_popup_next.visible = true
		_popup_next.grab_focus()
	_popup.visible = true
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_home()


func _draw() -> void:
	draw_rect(Rect2(0, 0, size.x, size.y), GameContext.c("bg"))

	for i in _rects.size():
		var on := _lit == i or _flash == "good" \
			or (_flash == "wrong" and _input_idx < _seq.size() and i == _seq[_input_idx])
		var col := Color(PADS[i]["on"]) if on else Color(PADS[i]["off"])
		draw_rect(_rects[i], col)

	draw_circle(_board.position + _board.size / 2.0, _board.size.x * 0.14, GameContext.c("bg"))

	if _phase == "idle" and not _popup.visible:
		draw_rect(_start_btn, GameContext.c("accent"))
		var f := ThemeDB.fallback_font
		var fs := 30
		var tw := f.get_string_size("Start", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, _start_btn.position + Vector2(_start_btn.size.x / 2.0 - tw / 2.0, _start_btn.size.y / 2.0 + fs * 0.35),
			"Start", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _update_hud() -> void:
	var shown: int = mini(_seq.size(), int(TARGETS[_level]))
	_info.text = "L%d/%d   ·   length %d/%d" % [_level + 1, TARGETS.size(), shown, int(TARGETS[_level])]
	if _hint != null:
		_hint.text = {
			"idle": "press Start, then repeat the sequence",
			"show": "watch and listen…",
			"pause": "watch and listen…",
			"input": "your turn — tap the colours in order",
		}.get(_phase, "")


func _play(p: AudioStreamPlayer) -> void:
	if p != null and p.stream != null:
		p.play()


func _go_home() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
