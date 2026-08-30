extends Control
## Aquarium — a calm digital fish tank. No score: watch the fish, poke one
## for a bubble + its name, or tap the water to drop food the nearby fish
## swim over to.

const MAIN_MENU := "res://scenes/MainMenu.tscn"
const FISH_SCENE := preload("res://scenes/components/AquariumFish.tscn")

const BUBBLE_TEX := "blub0.png"
const SND_BLUB := "blub0.wav"
const SND_SPLASH := "poolsplash.wav"
const SND_AMBIENT := "glockenschmoutz.ogg"

const FISH_COUNT := 12

# id -> friendly name (frames are <id>_0.png / <id>_1.png via AssetLoader)
const SPECIES := [
	["shark1", "shark", 0.9], ["manta", "manta ray", 0.8], ["eel", "eel", 0.9],
	["discus2", "discus", 1.0], ["QueenAngel", "angelfish", 1.2],
	["butfish", "butterfly fish", 1.1], ["blueking2", "blue tang", 1.0],
	["collaris", "tang", 1.3], ["six_barred", "wrasse", 1.2],
	["cichlid1", "cichlid", 1.3], ["newf1", "goldfish", 1.0],
	["f01", "emperor angelfish", 1.2], ["f04", "Moorish idol", 1.2], ["f06", "bass", 1.1],
	["f09", "pomfret", 1.2], ["f13", "snapper", 1.1],
]

var _bounds := Rect2(0, 84, 1280, 720 - 84 - 40)
var _t := 0.0
var _bg_home := Vector2.ZERO
var _food: Array = []          # [{ "node": Sprite2D, "fans": Array[AquariumFish] }]
var _fish: Array = []

@onready var _background: Sprite2D = $World/Background
@onready var _fish_root: Node2D = $World/Fish
@onready var _fx_root: Node2D = $World/Fx
@onready var _labels_root: Control = $Labels
@onready var _bubble_tex: Texture2D = AssetLoader.get_texture(BUBBLE_TEX)
@onready var _back_button: Button = %BackButton
@onready var _ambient: AudioStreamPlayer = $Audio/Ambient
@onready var _sfx_blub: AudioStreamPlayer = $Audio/Blub
@onready var _sfx_splash: AudioStreamPlayer = $Audio/Splash


func _ready() -> void:
	get_viewport().physics_object_picking = true

	_back_button.pressed.connect(_go_home)

	_sfx_blub.stream = AssetLoader.get_stream(SND_BLUB)
	_sfx_splash.stream = AssetLoader.get_stream(SND_SPLASH)
	var amb := AssetLoader.get_stream(SND_AMBIENT)
	if amb:
		if "loop" in amb:
			amb.loop = true
		_ambient.stream = amb
		_ambient.play()

	# cover-fit the tank photo, then fade it back so the procedural
	# Material-3 gradient in _draw() reads through it (drop an svg/png into
	# backgrounds/aquarium_* to replace the photo layer).
	if _background.texture:
		var isize := _background.texture.get_size()
		var s: float = maxf((1280.0 + 60.0) / isize.x, 720.0 / isize.y)
		_background.scale = Vector2(s, s)
	_background.position = Vector2(640, 360)
	_background.modulate.a = 0.4
	_bg_home = _background.position

	GameContext.theme_changed.connect(queue_redraw)
	_spawn_fish()


func _draw() -> void:
	# deep tonal gradient (Material-3 flavour), painted under the child
	# Sprite2D / fish nodes
	var light := GameContext.theme_mode == "light"
	var top_col := Color("0d6b7a") if light else Color("052b36")
	var mid_col := Color("2a97a0") if light else Color("0c4d5d")
	var bot_col := Color("57bcbe") if light else Color("12707a")
	var h := size.y
	var bands := 24
	for i in bands:
		var f := float(i) / float(bands - 1)
		var col := top_col.lerp(mid_col, minf(1.0, f * 2.0)) if f < 0.5 \
			else mid_col.lerp(bot_col, (f - 0.5) * 2.0)
		draw_rect(Rect2(0, h * f, size.x, h / float(bands) + 1.0), col)
	# three slow light shafts
	for i in 3:
		var cx := size.x * (0.25 + i * 0.28) + sin(_t * 0.05 + i * 2.0) * 60.0
		var pts := PackedVector2Array([
			Vector2(cx - 40, 0), Vector2(cx + 40, 0),
			Vector2(cx + 150, size.y), Vector2(cx + 60, size.y)])
		draw_colored_polygon(pts, Color(0.6, 0.9, 1.0, 0.05 if not light else 0.08))


func _spawn_fish() -> void:
	var pool := SPECIES.duplicate()
	pool.shuffle()
	for i in FISH_COUNT:
		var sp: Array = pool[i % pool.size()]
		var f0 := AssetLoader.get_texture(sp[0] + "_0.png")
		var f1 := AssetLoader.get_texture(sp[0] + "_1.png")
		var fish: AquariumFish = FISH_SCENE.instantiate()
		_fish_root.add_child(fish)
		fish.position = Vector2(randf_range(80, 1200), randf_range(_bounds.position.y + 60, _bounds.end.y - 60))
		fish.setup(f0, f1, sp[1], sp[2])
		fish.set_bounds(_bounds)
		fish.poked.connect(_on_fish_poked)
		_fish.append(fish)


func _process(delta: float) -> void:
	_t += delta
	_background.position.x = _bg_home.x + sin(_t * 0.12) * 22.0
	queue_redraw()   # animate the light shafts in _draw()

	# hover pulse under the mouse
	var m := get_local_mouse_position()
	for fish in _fish:
		if is_instance_valid(fish) and fish.hit_rect().has_point(m):
			fish.hover_pulse()
			break

	# a fish that reaches its food eats it
	for entry in _food.duplicate():
		var node: Sprite2D = entry["node"]
		if not is_instance_valid(node):
			_food.erase(entry)
			continue
		for fish in entry["fans"]:
			if is_instance_valid(fish) and fish.global_position.distance_to(node.global_position) < 30.0:
				_eat_food(entry)
				break


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_home()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_drop_food(get_local_mouse_position())


# ---------------------------------------------------------------------------
# Interactions
# ---------------------------------------------------------------------------

func _on_fish_poked(fish: AquariumFish) -> void:
	_play(_sfx_blub)
	_bubble_burst(fish.position, 7)
	_float_name(fish.species_name, fish.position)


func _drop_food(pos: Vector2) -> void:
	_play(_sfx_splash)
	_ripple(pos)

	var node := Sprite2D.new()
	node.texture = _bubble_tex
	node.scale = Vector2(0.4, 0.4)
	node.modulate = Color(0.82, 0.58, 0.3)
	node.position = pos
	_fx_root.add_child(node)

	var fans: Array = _fish.filter(func(f): return is_instance_valid(f))
	fans.sort_custom(func(a, b): return a.position.distance_to(pos) < b.position.distance_to(pos))
	fans = fans.slice(0, 4)
	for f in fans:
		f.target = node

	var entry := { "node": node, "fans": fans }
	_food.append(entry)

	var t := create_tween()
	t.tween_property(node, "position:y", pos.y + 130.0, 5.0)
	t.tween_callback(func() -> void: _eat_food(entry))


func _eat_food(entry: Dictionary) -> void:
	if not _food.has(entry):
		return
	_food.erase(entry)
	var node: Sprite2D = entry["node"]
	if is_instance_valid(node):
		_bubble_burst(node.position, 4)
		node.queue_free()
	for f in _fish:
		if is_instance_valid(f) and f.target == node:
			f.target = null


# ---------------------------------------------------------------------------
# FX
# ---------------------------------------------------------------------------

func _ripple(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = _bubble_tex
	s.position = pos
	s.modulate = Color(0.87, 0.95, 1.0, 0.7)
	s.scale = Vector2(0.3, 0.3)
	_fx_root.add_child(s)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(s, "scale", Vector2(4.0, 4.0), 0.9)
	t.tween_property(s, "modulate:a", 0.0, 0.9)
	t.chain().tween_callback(s.queue_free)


func _bubble_burst(pos: Vector2, n: int) -> void:
	for i in n:
		var b := Sprite2D.new()
		b.texture = _bubble_tex
		b.position = pos + Vector2(randf_range(-14, 14), randf_range(-8, 8))
		b.scale = Vector2.ONE * randf_range(0.15, 0.4)
		b.modulate = Color(0.9, 0.97, 1.0, 0.8)
		_fx_root.add_child(b)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(b, "position:y", b.position.y - randf_range(60, 130), randf_range(0.7, 1.2))
		t.tween_property(b, "modulate:a", 0.0, 1.0)
		t.chain().tween_callback(b.queue_free)


func _float_name(text: String, pos: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.position = pos - Vector2(60, 46)
	l.size = Vector2(120, 32)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_labels_root.add_child(l)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 40.0, 1.4)
	t.tween_property(l, "modulate:a", 0.0, 1.4)
	t.chain().tween_callback(l.queue_free)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _play(player: AudioStreamPlayer) -> void:
	if player.stream != null:
		player.play()


func _go_home() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)
