extends Control
## Image Changer — study the row of pictures, press Start, the cards flip
## down and back, and one picture has changed. Tap the card that changed.
## Four levels: 3 cards, 3 + shuffle, 4 cards, 4 + shuffle. Three rounds
## each.

const MAIN_MENU := "res://scenes/MainMenu.tscn"
const HUD := 56.0
const ROUNDS := 3

const LEVELS := [
	{ "cards": 3, "shuffle": false },
	{ "cards": 3, "shuffle": true },
	{ "cards": 4, "shuffle": false },
	{ "cards": 4, "shuffle": true },
]

const DECK := [
	"01_cat", "02_pig", "03_bear", "04_hippopotamus", "05_penguin", "06_cow",
	"07_sheep", "08_turtle", "09_panda", "10_chicken", "11_redbird", "12_wolf",
	"13_monkey", "14_fox", "16_elephant", "17_lion", "21_frog",
]

const SND_START := "pick.wav"
const SND_GOOD := "good.ogg"
const SND_WRONG := "wrong.ogg"
const SND_WIN := "winner.ogg"

var _level := 0
var _round := 0
var _phase := "study"             # study | hide | reveal | guess | result
var _t := 0.0
var _changed := false
var _result_advance := -1.0
var _cards: Array = []            # { id, x,y,w,h, flip, changed, wrong, right }
var _start_btn := Rect2()
var _tex_cache: Dictionary = {}
var _say_names := false
var _names_rect := Rect2(0, 14, 154, 36)

@onready var _info: Label = %InfoLabel
@onready var _status: Label = %StatusLabel
@onready var _back_button: Button = %BackButton
@onready var _popup: Control = %WinPopup
@onready var _popup_label: Label = %WinPopupLabel
@onready var _popup_next: Button = %WinPopupNext
@onready var _popup_replay: Button = %WinPopupReplay
@onready var _popup_menu: Button = %WinPopupMenu
@onready var _sfx_start: AudioStreamPlayer = $Audio/Start
@onready var _sfx_good: AudioStreamPlayer = $Audio/Good
@onready var _sfx_wrong: AudioStreamPlayer = $Audio/Wrong
@onready var _sfx_win: AudioStreamPlayer = $Audio/Win


func _ready() -> void:
	GameContext.theme_changed.connect(queue_redraw)
	var al := get_node_or_null("/root/AssetLoader")
	if al != null:
		_sfx_start.stream = al.get_stream(SND_START)
		_sfx_good.stream = al.get_stream(SND_GOOD)
		_sfx_wrong.stream = al.get_stream(SND_WRONG)
		_sfx_win.stream = al.get_stream(SND_WIN)
	_back_button.pressed.connect(_go_home)
	_popup_menu.pressed.connect(_go_home)
	_popup_replay.pressed.connect(func() -> void: _start_level(_level))
	_popup_next.pressed.connect(func() -> void: _start_level(_level + 1))
	_popup.visible = false
	resized.connect(_geo)
	_say_names = GameContext.name_toggle_get("ichanger")
	_geo_names()
	_start_level(0)


func _tex(id: String) -> Texture2D:
	if not _tex_cache.has(id):
		var al := get_node_or_null("/root/AssetLoader")
		_tex_cache[id] = al.get_texture("%s.png" % id) if al != null else null
	return _tex_cache[id]


func _start_level(n: int) -> void:
	_level = clampi(n, 0, LEVELS.size() - 1)
	_round = 0
	_popup.visible = false
	_new_round()


func _new_round() -> void:
	var lv: Dictionary = LEVELS[_level]
	var pool := DECK.duplicate()
	pool.shuffle()
	_cards = []
	for i in int(lv["cards"]):
		_cards.append({
			"id": pool[i], "x": 0.0, "y": 0.0, "w": 0.0, "h": 0.0,
			"flip": 0.0, "changed": false, "wrong": 0.0, "right": 0.0,
		})
	_phase = "study"
	_t = 0.0
	_changed = false
	_result_advance = -1.0
	_geo()
	_update_hud()
	queue_redraw()


func _geo_names() -> void:
	_names_rect = Rect2(size.x - 170.0, 14.0, 154.0, 36.0)


func _geo() -> void:
	_geo_names()
	if _cards.is_empty():
		return
	var n := _cards.size()
	var gap := 26.0
	var cw: float = clampf((size.x - 120.0 - gap * (n - 1)) / n, 120.0, 260.0)
	var ch: float = minf(cw * 1.32, size.y - HUD - 190.0)
	var total_w := n * cw + gap * (n - 1)
	var x0 := (size.x - total_w) / 2.0
	var y0 := HUD + 40.0 + (size.y - HUD - 40.0 - ch - 90.0) / 2.0
	for i in n:
		_cards[i]["x"] = x0 + i * (cw + gap)
		_cards[i]["y"] = y0
		_cards[i]["w"] = cw
		_cards[i]["h"] = ch
	_start_btn = Rect2(size.x / 2.0 - 110.0, y0 + ch + 34.0, 220.0, 62.0)


func _begin() -> void:
	if _phase != "study":
		return
	if _sfx_start.stream != null:
		_sfx_start.play()
	_phase = "hide"
	_t = 0.0


func _apply_change() -> void:
	var lv: Dictionary = LEVELS[_level]
	if lv["shuffle"]:
		_cards.shuffle()
	var used := {}
	for c in _cards:
		used[c["id"]] = true
	var fresh: Array = []
	for id in DECK:
		if not used.has(id):
			fresh.append(id)
	var nid: String = fresh[randi() % fresh.size()]
	var target: Dictionary = _cards[randi() % _cards.size()]
	target["id"] = nid
	target["changed"] = true
	_geo()
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	for c in _cards:
		c["wrong"] = maxf(0.0, c["wrong"] - delta)
		c["right"] = maxf(0.0, c["right"] - delta)

	if _result_advance >= 0.0:
		_result_advance -= delta
		if _result_advance < 0.0:
			_result_advance = -1.0
			if _round >= ROUNDS:
				_level_done()
			else:
				_changed = false
				_new_round()

	if _phase == "hide":
		var f: float = clampf(_t / 0.5, 0.0, 1.0)
		for c in _cards:
			c["flip"] = f
		if _t > 0.5 and not _changed:
			_changed = true
			_apply_change()
		if _t > 1.1:
			_phase = "reveal"
			_t = 0.0
	elif _phase == "reveal":
		var f: float = clampf(1.0 - _t / 0.5, 0.0, 1.0)
		for c in _cards:
			c["flip"] = f
		if _t > 0.55:
			_phase = "guess"
			for c in _cards:
				c["flip"] = 0.0
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

	if _names_rect.has_point(pos):
		_say_names = not _say_names
		GameContext.name_toggle_set("ichanger", _say_names)
		queue_redraw()
		return

	if _phase == "study":
		if _start_btn.has_point(pos):
			_begin()
		elif _say_names:
			for c in _cards:
				if Rect2(c["x"], c["y"], c["w"], c["h"]).has_point(pos):
					GameContext.speak(GameContext.name_from_id(str(c["id"])))
					break
		return
	if _phase != "guess":
		return

	var hit := {}
	for c in _cards:
		if Rect2(c["x"], c["y"], c["w"], c["h"]).has_point(pos):
			hit = c
			break
	if hit.is_empty():
		return

	if hit["changed"]:
		hit["right"] = 1.0
		if _sfx_good.stream != null:
			_sfx_good.play()
		if _say_names:
			GameContext.speak(GameContext.name_from_id(str(hit["id"])))
		_phase = "result"
		_t = 0.0
		_round += 1
		_result_advance = 0.9
		_update_hud()
	else:
		hit["wrong"] = 0.6
		if _sfx_wrong.stream != null:
			_sfx_wrong.play()
		for c in _cards:
			if c["changed"]:
				c["right"] = 0.6
	queue_redraw()


func _level_done() -> void:
	var last := _level >= LEVELS.size() - 1
	if _sfx_win.stream != null:
		_sfx_win.play()
	if last:
		_popup_label.text = "You spotted every change!"
		_popup_next.visible = false
		_popup_replay.grab_focus()
	else:
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
	var font := ThemeDB.fallback_font

	for c in _cards:
		var face_up: bool = c["flip"] < 0.5
		var sx: float = maxf(0.001, absf(1.0 - 2.0 * c["flip"]))
		var cx: float = c["x"] + c["w"] / 2.0
		var rect := Rect2(cx - c["w"] / 2.0 * sx, c["y"], c["w"] * sx, c["h"])
		draw_rect(rect, GameContext.c("surface") if face_up else GameContext.c("surface_alt"))

		if face_up:
			var tex := _tex(c["id"])
			if tex != null and sx > 0.4:
				var pad := 14.0
				var s: float = minf((c["w"] - pad * 2) / tex.get_width(), (c["h"] - pad * 2) / tex.get_height())
				var dw := tex.get_width() * s
				var dh := tex.get_height() * s
				draw_texture_rect(tex, Rect2(cx - dw / 2.0, c["y"] + (c["h"] - dh) / 2.0, dw, dh), false)
		elif sx > 0.4:
			var q := "?"
			var fs := 40
			var tw := font.get_string_size(q, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, Vector2(cx - tw / 2.0, c["y"] + c["h"] / 2.0 + fs * 0.35), q,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.25))

		if c["wrong"] > 0.0:
			draw_rect(Rect2(c["x"] + 3, c["y"] + 3, c["w"] - 6, c["h"] - 6),
				Color(1, 0.35, 0.35, clampf(c["wrong"] / 0.6, 0.0, 1.0)), false, 6.0)
		if c["right"] > 0.0:
			draw_rect(Rect2(c["x"] + 3, c["y"] + 3, c["w"] - 6, c["h"] - 6),
				Color(0.48, 0.88, 0.63, clampf(c["right"], 0.0, 1.0)), false, 7.0)

	if _phase == "study" and not _popup.visible:
		draw_rect(_start_btn, GameContext.c("accent"))
		var fs := 26
		var tw := font.get_string_size("Start", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, _start_btn.position + Vector2(_start_btn.size.x / 2.0 - tw / 2.0, _start_btn.size.y / 2.0 + fs * 0.35),
			"Start", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

	GameContext.draw_name_pill(self, _names_rect, _say_names)


func _update_hud() -> void:
	_info.text = "Level %d/%d   ·   round %d/%d" % [_level + 1, LEVELS.size(), mini(_round + 1, ROUNDS), ROUNDS]
	if _status != null:
		_status.text = {
			"study": "remember the pictures, then press Start",
			"hide": "watch closely...",
			"reveal": "watch closely...",
			"guess": "which picture changed?",
			"result": "nice!",
		}.get(_phase, "")


func _go_home() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
