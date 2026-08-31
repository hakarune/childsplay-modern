extends Control
## Flashcards — picture + word cards. Press the speaker to hear the word.
##
## English is spoken with the OS text-to-speech (DisplayServer.tts_*).
## German / Dutch / French / Spanish play the recorded Childsplay clips we
## ship, falling back to TTS in that language if a clip is missing. If no
## TTS voice is installed the card still shows the picture + word.

const MAIN_MENU := "res://scenes/MainMenu.tscn"

const DECK := [
	{ "word": "bear", "img": "03_bear" },
	{ "word": "cow", "img": "06_cow" },
	{ "word": "dog", "img": "dog" },
	{ "word": "elephant", "img": "16_elephant" },
	{ "word": "fox", "img": "14_fox" },
	{ "word": "frog", "img": "21_frog" },
	{ "word": "hippopotamus", "img": "04_hippopotamus" },
	{ "word": "horse", "img": "horse" },
	{ "word": "lion", "img": "17_lion" },
	{ "word": "pig", "img": "02_pig" },
	{ "word": "penguin", "img": "05_penguin" },
	{ "word": "rooster", "img": "rooster" },
]

const LANGS := [
	{ "code": "en", "label": "English", "bcp": "en" },
	{ "code": "de", "label": "Deutsch", "bcp": "de" },
	{ "code": "nl", "label": "Nederlands", "bcp": "nl" },
	{ "code": "fr", "label": "Francais", "bcp": "fr" },
	{ "code": "es", "label": "Espanol", "bcp": "es" },
]

var _i := 0
var _lang := 0
var _tts_voice := ""

@onready var _picture: TextureRect = %Picture
@onready var _word_label: Label = %WordLabel
@onready var _info_label: Label = %InfoLabel
@onready var _back_button: Button = %BackButton
@onready var _prev_button: Button = %PrevButton
@onready var _next_button: Button = %NextButton
@onready var _say_button: Button = %SayButton
@onready var _lang_bar: HBoxContainer = %LangBar
@onready var _clip: AudioStreamPlayer = $Audio/ClipPlayer


func _ready() -> void:
	GameContext.theme_changed.connect(_style_hud)
	_style_hud()
	_back_button.pressed.connect(_go_home)
	_prev_button.pressed.connect(func() -> void: _show(_i - 1))
	_next_button.pressed.connect(func() -> void: _show(_i + 1))
	_say_button.pressed.connect(_say)

	var voices := DisplayServer.tts_get_voices()
	if voices.size() > 0:
		_tts_voice = voices[0]["id"]

	for k in LANGS.size():
		var b := Button.new()
		b.text = LANGS[k]["label"]
		b.custom_minimum_size = Vector2(150, 46)
		b.toggle_mode = true
		b.pressed.connect(_on_lang.bind(k))
		_lang_bar.add_child(b)
	_refresh_lang_buttons()

	_show(0)


func _show(index: int) -> void:
	_i = wrapi(index, 0, DECK.size())
	var card: Dictionary = DECK[_i]
	_picture.texture = AssetLoader.get_texture(card["img"])
	_word_label.text = card["word"]
	_info_label.text = "%d / %d" % [_i + 1, DECK.size()]
	_say()


func _on_lang(k: int) -> void:
	_lang = k
	_refresh_lang_buttons()
	_say()


func _refresh_lang_buttons() -> void:
	for k in _lang_bar.get_child_count():
		_lang_bar.get_child(k).button_pressed = (k == _lang)


func _say() -> void:
	var word: String = DECK[_i]["word"]
	var lang: Dictionary = LANGS[_lang]

	if lang["code"] != "en":
		# flashcards/<word>_<lang>.ogg — flat, unique names, so the normal
		# AssetLoader index resolves it like any other clip.
		var key := "%s_%s.ogg" % [word, lang["code"]]
		if AssetLoader.has_stream(key):
			_clip.stream = AssetLoader.get_stream(key)
			_clip.play()
			return

	_speak(word, lang["bcp"])


func _speak(text: String, bcp: String) -> void:
	if DisplayServer.tts_get_voices().is_empty():
		return
	var voice := _tts_voice
	var matches := DisplayServer.tts_get_voices_for_language(bcp)
	if matches.size() > 0:
		voice = matches[0]
	if voice == "":
		return
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, voice)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_home()
	elif event.is_action_pressed("ui_left"):
		_show(_i - 1)
	elif event.is_action_pressed("ui_right"):
		_show(_i + 1)


func _go_home() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


## Themed HUD bar + divider (Design Policy §G).
func _style_hud() -> void:
	GameContext.style_hud_bar(self, 72.0, [_info_label], [])
