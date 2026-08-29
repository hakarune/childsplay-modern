extends Control
## Word Maker (legacy `synonyms`, adapted for young English readers). You
## are given a starting letter; tap the on-screen keyboard (or type) to
## build words that begin with it. Real words from the built-in list score;
## find enough to clear the level. Five letters, 2 → 6 words.

const MAIN_MENU := "res://scenes/MainMenu.tscn"
const HUD := 56.0

const WORD_LIST := [
	"sun", "sit", "sad", "sea", "see", "sock", "sing", "snake", "star", "stop",
	"six", "sky", "soap", "soup", "sand", "seed", "ship", "shop", "snow", "spin",
	"swim", "sheep", "spider", "seal", "song", "sofa",
	"bat", "bad", "bed", "bee", "big", "bus", "bug", "box", "boy", "bird",
	"blue", "boat", "book", "ball", "bell", "bear", "bone", "bump", "band", "barn",
	"best", "bath", "bake", "bread", "brush", "brown",
	"cat", "cap", "car", "cow", "cub", "cup", "can", "cot", "cake", "corn",
	"coat", "cave", "coin", "cold", "clap", "club", "crab", "crow", "cube", "camp",
	"card", "care", "cart", "clock", "cloud", "chair",
	"top", "tap", "ten", "toe", "tub", "tan", "tag", "tin", "toy", "tree",
	"time", "town", "tail", "tape", "team", "tent", "test", "tick", "tide", "tiny",
	"toad", "tool", "tour", "trap", "train", "truck",
	"pan", "pen", "pig", "pit", "pot", "pup", "pat", "paw", "pin", "park",
	"pink", "play", "plum", "pond", "pool", "pull", "push", "pear", "peas", "plan",
	"plus", "prize", "print", "path", "plane", "plant",
]

const LEVELS := [
	{ "letter": "s", "target": 2 },
	{ "letter": "b", "target": 3 },
	{ "letter": "c", "target": 4 },
	{ "letter": "t", "target": 4 },
	{ "letter": "p", "target": 5 },
]

const KB_ROWS := ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]

const SND_KEY := "pick.wav"
const SND_GOOD := "good.ogg"
const SND_WRONG := "wrong.ogg"
const SND_WIN := "winner.ogg"

var _level := 0
var _word := ""
var _found: Array[String] = []
var _shake := 0.0
var _words: Dictionary = {}
var _keys: Array = []             # { ch, x, y, w, h }
var _del_key := {}
var _ok_key := {}

@onready var _info: Label = %InfoLabel
@onready var _status: Label = %StatusLabel
@onready var _back_button: Button = %BackButton
@onready var _popup: Control = %WinPopup
@onready var _popup_label: Label = %WinPopupLabel
@onready var _popup_next: Button = %WinPopupNext
@onready var _popup_replay: Button = %WinPopupReplay
@onready var _popup_menu: Button = %WinPopupMenu
@onready var _sfx_key: AudioStreamPlayer = $Audio/Key
@onready var _sfx_good: AudioStreamPlayer = $Audio/Good
@onready var _sfx_wrong: AudioStreamPlayer = $Audio/Wrong
@onready var _sfx_win: AudioStreamPlayer = $Audio/Win


func _ready() -> void:
	for w in WORD_LIST:
		_words[w] = true
	var al := get_node_or_null("/root/AssetLoader")
	if al != null:
		_sfx_key.stream = al.get_stream(SND_KEY)
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


func _start_level(n: int) -> void:
	_level = clampi(n, 0, LEVELS.size() - 1)
	_word = ""
	_found.clear()
	_shake = 0.0
	_popup.visible = false
	_geo()
	_update_hud()
	queue_redraw()


func _geo() -> void:
	var gap := 8.0
	var kw: float = minf(96.0, (size.x - 40.0 - 9.0 * gap) / 10.0)
	var kh: float = minf(64.0, kw * 0.9)
	var bottom := size.y - 28.0
	_keys = []
	for r in KB_ROWS.size():
		var row: String = KB_ROWS[r]
		var total := row.length() * kw + (row.length() - 1) * gap
		var x0 := (size.x - total) / 2.0
		var y := bottom - (KB_ROWS.size() + 1 - r) * (kh + gap)
		for i in row.length():
			_keys.append({ "ch": row[i], "x": x0 + i * (kw + gap), "y": y, "w": kw, "h": kh })
	var ay := bottom - (kh + gap)
	var aw := kw * 4.0 + gap * 3.0
	_del_key = { "ch": "\b", "label": "DEL", "x": size.x / 2.0 - aw - gap / 2.0, "y": ay, "w": aw, "h": kh }
	_ok_key = { "ch": "\n", "label": "Enter", "x": size.x / 2.0 + gap / 2.0, "y": ay, "w": aw, "h": kh }


func _type(ch: String) -> void:
	if _popup.visible:
		return
	if _sfx_key.stream != null:
		_sfx_key.volume_db = -12.0
		_sfx_key.play()
	if _word.length() < 9:
		_word += ch.to_lower()
	queue_redraw()


func _backspace() -> void:
	if _popup.visible:
		return
	_word = _word.substr(0, maxi(0, _word.length() - 1))
	queue_redraw()


func _submit() -> void:
	if _popup.visible:
		return
	var w := _word.to_lower()
	var lv: Dictionary = LEVELS[_level]
	var letter: String = lv["letter"]
	var good: bool = w.length() >= 3 and w.substr(0, 1) == letter and _words.has(w) and not (w in _found)
	if good:
		_found.append(w)
		_word = ""
		if _sfx_good.stream != null:
			_sfx_good.play()
		if _found.size() >= int(lv["target"]):
			_level_done()
	else:
		_shake = 0.4
		_word = ""
		if _sfx_wrong.stream != null:
			_sfx_wrong.play()
	_update_hud()
	queue_redraw()


func _level_done() -> void:
	var last := _level >= LEVELS.size() - 1
	if _sfx_win.stream != null:
		_sfx_win.play()
	if last:
		_popup_label.text = "You are a word maker!"
		_popup_next.visible = false
		_popup_replay.grab_focus()
	else:
		_popup_label.text = "Level %d done!" % (_level + 1)
		_popup_next.visible = true
		_popup_next.grab_focus()
	_popup.visible = true
	_update_hud()


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
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
	if Rect2(_del_key["x"], _del_key["y"], _del_key["w"], _del_key["h"]).has_point(pos):
		_backspace()
		return
	if Rect2(_ok_key["x"], _ok_key["y"], _ok_key["w"], _ok_key["h"]).has_point(pos):
		_submit()
		return
	for k in _keys:
		if Rect2(k["x"], k["y"], k["w"], k["h"]).has_point(pos):
			_type(k["ch"])
			return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_home()
		return
	if _popup.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = (event as InputEventKey).keycode
		if kc == KEY_BACKSPACE:
			_backspace()
		elif kc == KEY_ENTER or kc == KEY_KP_ENTER or kc == KEY_SPACE:
			_submit()
		elif kc >= KEY_A and kc <= KEY_Z:
			_type(char(kc))


func _draw() -> void:
	draw_rect(Rect2(0, 0, size.x, size.y), Color("141b26"))
	var font := ThemeDB.fallback_font
	var lv: Dictionary = LEVELS[_level]

	var prompt := "make words that start with  \"%s\"" % String(lv["letter"]).to_upper()
	var ps := 26
	var pw := font.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, ps).x
	draw_string(font, Vector2(size.x / 2.0 - pw / 2.0, HUD + 52.0), prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, ps, Color("9fb4d8"))

	var tray_w: float = minf(560.0, size.x - 120.0)
	var tray_x := size.x / 2.0 - tray_w / 2.0
	var tray_y := HUD + 76.0
	var sh := sin(_shake * 60.0) * 6.0 if _shake > 0.0 else 0.0
	draw_rect(Rect2(tray_x + sh, tray_y, tray_w, 74.0), Color("5b2b2b") if _shake > 0.0 else Color("232f45"))
	var shown := _word.to_upper() if _word != "" else "..."
	var ts := 44
	var tw := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
	draw_string(font, Vector2(size.x / 2.0 - tw / 2.0 + sh, tray_y + 52.0), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color("eef2f7"))

	var fy := tray_y + 100.0
	for w in _found:
		var fs := 22
		var fw := font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(size.x / 2.0 - fw / 2.0, fy), w, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("7be0a0"))
		fy += 30.0
	var prog := "%d / %d" % [_found.size(), int(lv["target"])]
	var pgw := font.get_string_size(prog, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(font, Vector2(size.x / 2.0 - pgw / 2.0, fy + 6.0), prog, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("9fb4d8"))

	for k in _keys:
		_draw_key(font, k, 26)
	_draw_key(font, _del_key, 22)
	_draw_key(font, _ok_key, 22)


func _draw_key(font: Font, k: Dictionary, fs: int) -> void:
	draw_rect(Rect2(k["x"], k["y"], k["w"], k["h"]), Color("2b3856"))
	var lbl: String = k.get("label", k["ch"])
	var tw := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(k["x"] + k["w"] / 2.0 - tw / 2.0, k["y"] + k["h"] / 2.0 + fs * 0.35),
		lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("eef2f7"))


func _update_hud() -> void:
	var lv: Dictionary = LEVELS[_level]
	_info.text = "Level %d/%d   ·   %d/%d words" % [_level + 1, LEVELS.size(), _found.size(), int(lv["target"])]
	if _status != null:
		_status.text = "tap letters, then Enter"


func _go_home() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
