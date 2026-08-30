extends Control
## Wipe — a painting hidden under a grey cover. Drag the sponge to wipe the
## cover away and reveal the picture. Clear enough of it to finish the
## level. Six paintings; the target rises and the sponge shrinks.

const MAIN_MENU := "res://scenes/MainMenu.tscn"
const HUD := 56.0
const CELL := 20.0

# Shared painting pool with Puzzle; tier per painting from
# assets/data/backgrounds.json, no-repeat shared across a session (§B.4).
const PAINTINGS := ["bruegel0", "bruegel1", "gogh0", "gogh1", "gogh3", "monet0", "monet1", "monet3", "pieck0", "pieck1", "pieck2", "rembrandt0", "rembrandt1", "renoir0", "vermeer1", "vermeer2", "vermeer3"]
const LEVEL_COUNT := 12
const SND_WIPE := "pick.wav"
const SND_WIN := "winner.ogg"

var _tiers: Dictionary = {}

func _level_target(i: int) -> float:
	return 0.65 + (0.99 - 0.65) * (float(i) / float(LEVEL_COUNT - 1))

func _level_sponge(i: int) -> float:
	return round(54.0 - (54.0 - 26.0) * (float(i) / float(LEVEL_COUNT - 1)))

func _level_tier(i: int) -> String:
	return "easy" if i < 4 else ("med" if i < 8 else "hard")

var _level := 0
var _tex: Texture2D = null
var _done := false
var _drag := false
var _ptr := Vector2(-999, -999)
var _has_ptr := false
var _frame := Rect2()
var _cols := 0
var _rows := 0
var _cover: PackedByteArray = PackedByteArray()
var _wipe_cd := 0.0
var _tex_cache: Dictionary = {}

@onready var _info: Label = %InfoLabel
@onready var _back_button: Button = %BackButton
@onready var _popup: Control = %WinPopup
@onready var _popup_label: Label = %WinPopupLabel
@onready var _popup_next: Button = %WinPopupNext
@onready var _popup_replay: Button = %WinPopupReplay
@onready var _popup_menu: Button = %WinPopupMenu
@onready var _sfx_wipe: AudioStreamPlayer = $Audio/Wipe
@onready var _sfx_win: AudioStreamPlayer = $Audio/Win


func _ready() -> void:
	_tiers = GameContext.load_json("backgrounds").get("tiers", {})
	GameContext.theme_changed.connect(_style_hud)
	_style_hud()
	var al := get_node_or_null("/root/AssetLoader")
	if al != null:
		_sfx_wipe.stream = al.get_stream(SND_WIPE)
		_sfx_win.stream = al.get_stream(SND_WIN)
	_back_button.pressed.connect(_go_home)
	_popup_menu.pressed.connect(_go_home)
	_popup_replay.pressed.connect(func() -> void: _start_level(_level))
	_popup_next.pressed.connect(func() -> void: _start_level(_level + 1))
	_popup.visible = false
	resized.connect(_geo)
	_start_level(0)


func _tex_for(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		var al := get_node_or_null("/root/AssetLoader")
		_tex_cache[name] = al.get_texture(name) if al != null else null
	return _tex_cache[name]


func _start_level(n: int) -> void:
	_level = clampi(n, 0, LEVEL_COUNT - 1)
	_done = false
	_drag = false
	_has_ptr = false
	_cover = PackedByteArray()
	_cols = 0
	_rows = 0
	_tex = _tex_for(str(GameContext.draw_tiered("backgrounds", PAINTINGS, _tiers, _level_tier(_level), 1)[0]))
	_popup.visible = false
	_geo()
	_update_hud()
	queue_redraw()


func _geo() -> void:
	var avail_w := size.x - 100.0
	var avail_h := size.y - HUD - 90.0
	var aspect := 8.0 / 5.0
	if _tex != null and _tex.get_height() > 0:
		aspect = float(_tex.get_width()) / float(_tex.get_height())
	var fw := avail_w
	var fh := fw / aspect
	if fh > avail_h:
		fh = avail_h
		fw = fh * aspect
	_frame = Rect2((size.x - fw) / 2.0, HUD + 20.0 + (avail_h - fh) / 2.0, fw, fh)

	var cols: int = maxi(8, roundi(fw / CELL))
	var rows: int = maxi(6, roundi(fh / CELL))
	var prev := _cover
	var prev_c := _cols
	var prev_r := _rows
	_cols = cols
	_rows = rows
	_cover = PackedByteArray()
	_cover.resize(cols * rows)
	_cover.fill(1)
	if prev.size() > 0 and prev_c > 0 and prev_r > 0:
		for r in rows:
			for c in cols:
				var pc: int = mini(prev_c - 1, int(float(c) / cols * prev_c))
				var pr: int = mini(prev_r - 1, int(float(r) / rows * prev_r))
				_cover[r * cols + c] = prev[pr * prev_c + pc]


func _revealed() -> float:
	if _cover.size() == 0:
		return 0.0
	var open := 0
	for v in _cover:
		if v == 0:
			open += 1
	return float(open) / _cover.size()


func _wipe_at(p: Vector2) -> void:
	if _done or _cover.size() == 0:
		return
	var f := _frame
	if p.x < f.position.x - 20.0 or p.x > f.position.x + f.size.x + 20.0 \
			or p.y < f.position.y - 20.0 or p.y > f.position.y + f.size.y + 20.0:
		return
	var cw := f.size.x / _cols
	var ch := f.size.y / _rows
	var rad: float = _level_sponge(_level)
	var c0: int = clampi(int((p.x - rad - f.position.x) / cw), 0, _cols - 1)
	var c1: int = clampi(int(ceil((p.x + rad - f.position.x) / cw)), 0, _cols - 1)
	var r0: int = clampi(int((p.y - rad - f.position.y) / ch), 0, _rows - 1)
	var r1: int = clampi(int(ceil((p.y + rad - f.position.y) / ch)), 0, _rows - 1)
	var changed := false
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var idx := r * _cols + c
			if _cover[idx] == 0:
				continue
			var cx := f.position.x + (c + 0.5) * cw
			var cy := f.position.y + (r + 0.5) * ch
			if (cx - p.x) * (cx - p.x) + (cy - p.y) * (cy - p.y) <= rad * rad:
				_cover[idx] = 0
				changed = true
	if changed and _wipe_cd <= 0.0:
		if _sfx_wipe.stream != null:
			_sfx_wipe.pitch_scale = 1.4
			_sfx_wipe.volume_db = -10.0
			_sfx_wipe.play()
		_wipe_cd = 0.08
	if changed:
		queue_redraw()
		_update_hud()
	if _revealed() >= _level_target(_level):
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	_cover.fill(0)
	if _sfx_win.stream != null:
		_sfx_win.play()
	var last := _level >= LEVEL_COUNT - 1
	if last:
		_popup_label.text = "Every painting uncovered!"
		_popup_next.visible = false
		_popup_replay.grab_focus()
	else:
		_popup_label.text = "Nice wiping!"
		_popup_next.visible = true
		_popup_next.grab_focus()
	_popup.visible = true
	_update_hud()
	queue_redraw()


func _process(delta: float) -> void:
	if _wipe_cd > 0.0:
		_wipe_cd = maxf(0.0, _wipe_cd - delta)


func _gui_input(event: InputEvent) -> void:
	if _popup.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_has_ptr = true
		_ptr = event.position
		if event.pressed:
			_drag = true
			_wipe_at(event.position)
		else:
			_drag = false
		queue_redraw()
	elif event is InputEventScreenTouch:
		_has_ptr = true
		_ptr = event.position
		_drag = event.pressed
		if event.pressed:
			_wipe_at(event.position)
		queue_redraw()
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		_has_ptr = true
		_ptr = event.position
		if _drag:
			_wipe_at(event.position)
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_home()


func _draw() -> void:
	draw_rect(Rect2(0, 0, size.x, size.y), GameContext.c("bg"))
	var f := _frame
	if _tex != null:
		draw_texture_rect(_tex, f, false)
	else:
		draw_rect(f, GameContext.c("surface"))

	if _cover.size() > 0:
		var cw := f.size.x / _cols
		var ch := f.size.y / _rows
		for r in _rows:
			for c in _cols:
				if _cover[r * _cols + c] == 0:
					continue
				var shade := (60 + (c * 7 + r * 13) % 22) / 255.0
				draw_rect(Rect2(f.position.x + c * cw - 0.5, f.position.y + r * ch - 0.5, cw + 1.0, ch + 1.0),
					Color(shade, shade + 0.016, shade + 0.04))

	draw_rect(f, GameContext.c("line"), false, 4.0)

	if _has_ptr and not _done and not _popup.visible:
		draw_arc(_ptr, _level_sponge(_level), 0.0, TAU, 48, Color(1, 1, 1, 0.6), 3.0)


func _update_hud() -> void:
	var pct := roundi(_revealed() * 100.0)
	var goal := roundi(_level_target(_level) * 100.0)
	_info.text = "L%d/%d   ·   %d%%  (goal %d%%)" % [_level + 1, LEVEL_COUNT, pct, goal]


func _go_home() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


## Themed HUD bar + divider so the top chrome reads against the play
## area in both palettes (Design Policy §G).
func _style_hud() -> void:
	GameContext.style_hud_bar(self, HUD, [_info], [])
	queue_redraw()
