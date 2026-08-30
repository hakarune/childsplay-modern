extends Control
## Quiz — the shared multiple-choice quiz engine (Design Policy §J / §H).
##
## Boots with GameContext.quiz_deck; loads assets/data/quiz/<deck>.json,
## groups the questions by `level`, and runs each level as a short round.
## Show a question (spoken via TTS + a 🔊 button), tap a shuffled answer
## button. A wrong tap just shakes — no penalty (§H.1.3). Clear a level to
## advance; clear the last level to win.

const MAIN_MENU := "res://scenes/MainMenu.tscn"
const QUIZ_MENU := "res://scenes/QuizMenu.tscn"
const HUD := 64.0

const SND_GOOD := "good.ogg"
const SND_BAD := "wrong.ogg"
const SND_WIN := "winner.ogg"

const FALLBACK := {
	"name": "Quiz",
	"prompt": "tap the right answer",
	"questions": [
		{ "level": 1, "q": "2 + 2 = ?", "choices": ["4", "3", "5"], "answer": 0 },
		{ "level": 1, "q": "What colour is grass?", "choices": ["Green", "Blue", "Red"], "answer": 0 },
	],
}

var _deck: Dictionary = FALLBACK
var _level := 0
var _max_level := 1
var _questions: Array = []
var _qi := 0
var _choices: Array = []
var _answer := 0
var _image := ""
var _locked := 0.0
var _shake_btn: Button = null
var _shake_t := 0.0
var _answer_btns: Array[Button] = []

@onready var _info: Label = %InfoLabel
@onready var _back_button: Button = %BackButton
@onready var _answers: VBoxContainer = %Answers
@onready var _popup: Control = %WinPopup
@onready var _popup_label: Label = %WinPopupLabel
@onready var _popup_next: Button = %WinPopupNext
@onready var _popup_replay: Button = %WinPopupReplay
@onready var _popup_menu: Button = %WinPopupMenu
@onready var _sfx_good: AudioStreamPlayer = $Audio/Good
@onready var _sfx_bad: AudioStreamPlayer = $Audio/Bad
@onready var _sfx_win: AudioStreamPlayer = $Audio/Win


func _ready() -> void:
	GameContext.theme_changed.connect(_style_hud)
	_style_hud()
	_sfx_good.stream = AssetLoader.get_stream(SND_GOOD)
	_sfx_bad.stream = AssetLoader.get_stream(SND_BAD)
	_sfx_win.stream = AssetLoader.get_stream(SND_WIN)
	_back_button.pressed.connect(_go_home)
	_popup_menu.pressed.connect(_go_menu)
	_popup_replay.pressed.connect(func() -> void: _start_level(_level))
	_popup_next.pressed.connect(func() -> void: _start_level(_level + 1))
	_popup.visible = false

	var deck_id := str(GameContext.quiz_deck)
	var data := GameContext.load_json("quiz/" + deck_id)
	if data.get("questions", []) is Array and not data.get("questions", []).is_empty():
		_deck = data
	_max_level = 1
	for q in _deck["questions"]:
		_max_level = maxi(_max_level, int(q.get("level", 1)))

	_start_level(0)


func _start_level(n: int) -> void:
	_level = clampi(n, 0, _max_level - 1)
	var want := _level + 1
	var pool: Array = []
	for q in _deck["questions"]:
		if int(q.get("level", 1)) == want:
			pool.append(q)
	if pool.is_empty():
		pool = _deck["questions"].duplicate()
	pool.shuffle()
	_questions = pool.slice(0, mini(6, pool.size()))
	_qi = 0
	_locked = 0.0
	_shake_btn = null
	_popup.visible = false
	_load_question()


func _load_question() -> void:
	if _qi >= _questions.size():
		_level_done()
		return
	var q: Dictionary = _questions[_qi]
	var raw: Array = q["choices"]
	var order: Array = range(raw.size())
	order.shuffle()
	_choices = []
	for i in order:
		_choices.append(raw[i])
	_answer = order.find(int(q.get("answer", 0)))
	_image = str(q.get("image", ""))

	_build_answer_buttons()
	_layout_answers()
	_update_hud()
	queue_redraw()
	GameContext.speak(str(q.get("q", _deck.get("prompt", ""))))


func _build_answer_buttons() -> void:
	for b in _answers.get_children():
		b.queue_free()
	_answer_btns.clear()
	var bw: float = minf(560.0, size.x - 160.0)
	for i in _choices.size():
		var b := Button.new()
		b.text = str(_choices[i])
		b.custom_minimum_size = Vector2(bw, 78)   # §I.1.2 primary target ≥ 72
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(_on_answer.bind(i))
		_answers.add_child(b)
		_answer_btns.append(b)
	if _answer_btns.size() > 0:
		_answer_btns[0].grab_focus()


func _layout_answers() -> void:
	if _answers == null:
		return
	var bw: float = minf(560.0, size.x - 160.0)
	_answers.position = Vector2((size.x - bw) / 2.0, _question_bottom() + 30.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_answers()
		queue_redraw()


func _question_bottom() -> float:
	return HUD + 24.0 + (220.0 if _image != "" else 120.0)


func _on_answer(i: int) -> void:
	if _locked > 0.0 or _popup.visible:
		return
	if i == _answer:
		_play(_sfx_good)
		_locked = 0.45
		for b in _answer_btns:
			b.disabled = true
	else:
		_play(_sfx_bad)
		if i < _answer_btns.size():
			_shake_btn = _answer_btns[i]
			_shake_t = 0.0


func _process(delta: float) -> void:
	if _shake_btn != null:
		_shake_t += delta
		_shake_btn.position.x = sin(_shake_t * 50.0) * 8.0 * maxf(0.0, 1.0 - _shake_t / 0.4)
		if _shake_t > 0.4:
			_shake_btn.position.x = 0.0
			_shake_btn = null
	if _locked > 0.0:
		_locked -= delta
		if _locked <= 0.0:
			_locked = 0.0
			_qi += 1
			_load_question()


func _level_done() -> void:
	var last := _level >= _max_level - 1
	_play(_sfx_win)
	if last:
		_popup_label.text = "You finished the quiz!"
		_popup_next.visible = false
		_popup_replay.grab_focus()
	else:
		_popup_label.text = "Level %d done!" % (_level + 1)
		_popup_next.visible = true
		_popup_next.grab_focus()
	_popup.visible = true
	for b in _answer_btns:
		b.disabled = true


func _draw() -> void:
	draw_rect(Rect2(0, 0, size.x, size.y), GameContext.c("bg"))
	if _qi >= _questions.size():
		return
	var q: Dictionary = _questions[_qi]
	var font := ThemeDB.fallback_font

	var qb := Rect2(60.0, HUD + 24.0, size.x - 120.0, 220.0 if _image != "" else 120.0)
	draw_rect(qb, GameContext.c("surface"))

	var text_x := qb.position.x + qb.size.x / 2.0
	var align := HORIZONTAL_ALIGNMENT_CENTER
	if _image != "":
		var tex := AssetLoader.get_texture(_image)
		if tex != null:
			var box := qb.size.y - 24.0
			var s: float = minf(box / tex.get_width(), box / tex.get_height())
			var dw := tex.get_width() * s
			var dh := tex.get_height() * s
			draw_texture_rect(tex, Rect2(qb.position + Vector2(16.0, (qb.size.y - dh) / 2.0), Vector2(dw, dh)), false)
		text_x = qb.position.x + qb.size.y + 8.0
		align = HORIZONTAL_ALIGNMENT_LEFT

	var qtext := str(q.get("q", ""))
	var fs := 26
	var box_w: float = (qb.size.x - qb.size.y - 24.0) if _image != "" else (qb.size.x - 48.0)
	draw_multiline_string(font, Vector2(text_x if align == HORIZONTAL_ALIGNMENT_LEFT else qb.position.x + 24.0,
			qb.position.y + 40.0),
		qtext, HORIZONTAL_ALIGNMENT_LEFT, box_w, fs, 4, GameContext.c("text"))


func _update_hud() -> void:
	_info.text = "%s  ·  L%d/%d  ·  %d/%d" % [
		str(_deck.get("name", "Quiz")), _level + 1, _max_level, _qi + 1, _questions.size()]


func _style_hud() -> void:
	GameContext.style_hud_bar(self, HUD, [_info], [])
	queue_redraw()


func _play(p: AudioStreamPlayer) -> void:
	if p.stream != null:
		p.play()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_menu()


func _go_home() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


func _go_menu() -> void:
	get_tree().change_scene_to_file(QUIZ_MENU)
