extends Control
## Find It — spot the difference. The same painting is shown twice; the
## right copy has a few coloured spots added. Tap them all.

const MAIN_MENU := "res://scenes/MainMenu.tscn"
const HUD := 64.0

const LEVELS := [
	{ "diffs": 3, "r": 30.0 },
	{ "diffs": 5, "r": 25.0 },
	{ "diffs": 6, "r": 20.0 },
]
const PAINTINGS := ["bruegel0", "bruegel1", "gogh0", "gogh1", "gogh3", "monet0", "monet1", "monet3", "pieck0", "pieck1", "pieck2", "rembrandt0", "rembrandt1", "renoir0", "vermeer1", "vermeer2", "vermeer3"]
const BLOBS := [
	Color("ff5a5a"), Color("ffd93d"), Color("6bcb77"),
	Color("4d96ff"), Color("b980f0"), Color("ff9f45"), Color("31c2d6"),
]

const SND_GOOD := "good.ogg"
const SND_BAD := "bump.wav"
const SND_WIN := "winner.ogg"

var _level := 0
var _tex: Texture2D
var _left := Rect2()
var _right := Rect2()
var _diffs: Array = []          # [{ nx, ny, color, found }]
var _found := 0
var _tries := 0
var _miss = null                # { pos: Vector2, t: float }

@onready var _info_label: Label = %InfoLabel
@onready var _back_button: Button = %BackButton
@onready var _popup: Control = %WinPopup
@onready var _popup_label: Label = %WinPopupLabel
@onready var _popup_next: Button = %WinPopupNext
@onready var _popup_replay: Button = %WinPopupReplay
@onready var _popup_menu: Button = %WinPopupMenu
@onready var _sfx_good: AudioStreamPlayer = $Audio/GoodSound
@onready var _sfx_bad: AudioStreamPlayer = $Audio/BadSound
@onready var _sfx_win: AudioStreamPlayer = $Audio/WinSound


func _ready() -> void:
	GameContext.theme_changed.connect(_style_hud)
	_style_hud()
	_sfx_good.stream = AssetLoader.get_stream(SND_GOOD)
	_sfx_bad.stream = AssetLoader.get_stream(SND_BAD)
	_sfx_win.stream = AssetLoader.get_stream(SND_WIN)
	_back_button.pressed.connect(_go_home)
	_popup_menu.pressed.connect(_go_home)
	_popup_replay.pressed.connect(func() -> void: _start_level(_level))
	_popup_next.pressed.connect(func() -> void: _start_level(_level + 1))
	_popup.visible = false
	_start_level(0)


func _start_level(n: int) -> void:
	_level = clampi(n, 0, LEVELS.size() - 1)
	var lvl: Dictionary = LEVELS[_level]
	_tex = AssetLoader.get_texture(str(GameContext.draw_from_pool("backgrounds", PAINTINGS, 1)[0]))
	_found = 0
	_tries = 0
	_miss = null
	_popup.visible = false

	var isize := _tex.get_size() if _tex else Vector2(4, 3)
	var aspect := isize.x / isize.y
	var pw := 560.0
	var ph := pw / aspect
	if ph > 470.0:
		ph = 470.0
		pw = ph * aspect
	var gap := 40.0
	var x0 := (size.x - (pw * 2.0 + gap)) / 2.0
	var y0 := HUD + (size.y - HUD - ph) / 2.0
	_left = Rect2(x0, y0, pw, ph)
	_right = Rect2(x0 + pw + gap, y0, pw, ph)

	_diffs.clear()
	var guard := 0
	while _diffs.size() < int(lvl["diffs"]) and guard < 400:
		guard += 1
		var nx := randf_range(0.1, 0.9)
		var ny := randf_range(0.12, 0.88)
		var ok := true
		for d in _diffs:
			if Vector2(d["nx"] - nx, d["ny"] - ny).length() < 0.16:
				ok = false
				break
		if ok:
			_diffs.append({ "nx": nx, "ny": ny, "color": BLOBS[_diffs.size() % BLOBS.size()], "found": false })

	_update_hud()
	queue_redraw()


func _process(delta: float) -> void:
	if _miss != null:
		_miss["t"] += delta
		if _miss["t"] > 0.4:
			_miss = null
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _popup.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_tap(event.position)


func _panel_point(panel: Rect2, p: Vector2):
	if not panel.has_point(p):
		return null
	return Vector2((p.x - panel.position.x) / panel.size.x, (p.y - panel.position.y) / panel.size.y)


func _tap(p: Vector2) -> void:
	var np = _panel_point(_left, p)
	if np == null:
		np = _panel_point(_right, p)
	if np == null or _tex == null:
		return
	var tol := float(LEVELS[_level]["r"]) / _right.size.x * 1.4
	for d in _diffs:
		if not d["found"] and Vector2(d["nx"] - np.x, d["ny"] - np.y).length() < tol:
			d["found"] = true
			_found += 1
			_play(_sfx_good)
			_update_hud()
			queue_redraw()
			if _found == _diffs.size():
				_win()
			return
	_tries += 1
	_miss = { "pos": p, "t": 0.0 }
	_play(_sfx_bad)
	queue_redraw()


func _win() -> void:
	_play(_sfx_win)
	var is_last := _level >= LEVELS.size() - 1
	_popup_label.text = "You spotted them all!\n%d wrong tap%s" % [_tries, "" if _tries == 1 else "s"]
	_popup_next.visible = not is_last
	_popup.visible = true
	(_popup_replay if is_last else _popup_next).grab_focus()


func _draw() -> void:
	if _tex == null:
		return
	_draw_panel(_left, false)
	_draw_panel(_right, true)
	if _miss != null:
		var a: float = clampf(1.0 - _miss["t"] / 0.4, 0.0, 1.0)
		var pos: Vector2 = _miss["pos"]
		var s := 16.0
		draw_line(pos - Vector2(s, s), pos + Vector2(s, s), Color(1, 0.35, 0.35, a), 5.0)
		draw_line(pos + Vector2(s, -s), pos + Vector2(-s, s), Color(1, 0.35, 0.35, a), 5.0)


func _draw_panel(panel: Rect2, with_diffs: bool) -> void:
	var isize := _tex.get_size()
	draw_texture_rect_region(_tex, panel, Rect2(Vector2.ZERO, isize))
	for d in _diffs:
		var c := panel.position + Vector2(d["nx"] * panel.size.x, d["ny"] * panel.size.y)
		var r: float = LEVELS[_level]["r"]
		if d["found"]:
			draw_arc(c, r + 4.0, 0.0, TAU, 24, GameContext.c("good"), 5.0)
		elif with_diffs:
			draw_circle(c, r, d["color"])
			draw_arc(c, r, 0.0, TAU, 24, Color(0, 0, 0, 0.35), 2.0)
	draw_rect(panel, GameContext.c("line"), false, 3.0)


func _update_hud() -> void:
	_info_label.text = "Found %d / %d      Level %d / %d      (find what is different on the right)" % [
		_found, _diffs.size(), _level + 1, LEVELS.size()
	]


func _play(p: AudioStreamPlayer) -> void:
	if p.stream != null:
		p.play()


func _go_home() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_home()


## Themed HUD bar + divider so the top chrome reads against the play
## area in both palettes (Design Policy §G).
func _style_hud() -> void:
	GameContext.style_hud_bar(self, HUD, [_info_label], [])
	queue_redraw()
