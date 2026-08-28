extends Control
## Packid - a gentle maze muncher. Steer Packid with the arrow keys, eat
## every cherry, and don't let the roaming fruit bump into you. Getting
## bumped just resets your position with a friendly "oops"; there is no
## harsh game-over.

const MAIN_MENU := "res://scenes/MainMenu.tscn"
const PLAYER_SCENE := preload("res://scenes/components/PackidPlayer.tscn")
const GHOST_SCENE := preload("res://scenes/components/PackidGhost.tscn")

const TILE := 24.0
const WALL_SOURCE := 1
const DOT_SOURCE := 2
const WORLD_SCALE := 2.0

const GHOST_SKINS := ["appel.png", "banaan.png", "citroen.png", "peer.png"]
const GHOST_TINTS := [Color("ff8a8a"), Color("ffd166"), Color("8ac6ff"), Color("bd8cff")]

const SND_EAT := "eat.wav"
const SND_CAUGHT := "bump.wav"
const SND_WIN := "finlevel.wav"

const RESET_PAUSE := 0.9

# Each level generates an open "pillar" maze of the given size.
const LEVELS := [
	{ "name": "Sunny",  "cols": 15, "rows": 11, "ghosts": 1, "pac": 118.0, "ghost": 62.0 },
	{ "name": "Breezy", "cols": 17, "rows": 13, "ghosts": 2, "pac": 126.0, "ghost": 72.0 },
	{ "name": "Zippy",  "cols": 19, "rows": 13, "ghosts": 2, "pac": 134.0, "ghost": 86.0 },
]

var _level_index := 0
var _score := 0
var _oops := 0
var _cols := 0
var _rows := 0
var _active := false
var _resetting := false

var _player: PackidPlayer
var _ghosts: Array[PackidGhost] = []
var _player_start := Vector2i.ZERO
var _ghost_starts: Array[Vector2i] = []

@onready var _world: Node2D = $World
@onready var _maze: TileMapLayer = $World/Maze
@onready var _entities: Node2D = $World/Entities
@onready var _info_label: Label = %InfoLabel
@onready var _back_button: Button = %BackButton
@onready var _popup: Control = %WinPopup
@onready var _popup_label: Label = %WinPopupLabel
@onready var _popup_next: Button = %WinPopupNext
@onready var _popup_replay: Button = %WinPopupReplay
@onready var _popup_menu: Button = %WinPopupMenu

@onready var _sfx_eat: AudioStreamPlayer = $Audio/EatSound
@onready var _sfx_caught: AudioStreamPlayer = $Audio/CaughtSound
@onready var _sfx_win: AudioStreamPlayer = $Audio/WinSound


func _ready() -> void:
	_sfx_eat.stream = AssetLoader.get_stream(SND_EAT)
	_sfx_caught.stream = AssetLoader.get_stream(SND_CAUGHT)
	_sfx_win.stream = AssetLoader.get_stream(SND_WIN)

	_back_button.pressed.connect(_go_home)
	_popup_menu.pressed.connect(_go_home)
	_popup_replay.pressed.connect(func(): _start_level(_level_index))
	_popup_next.pressed.connect(func(): _start_level(_level_index + 1))
	_popup.visible = false

	get_viewport().size_changed.connect(_center_world)
	_start_level(0)


# ---------------------------------------------------------------------------
# Level build
# ---------------------------------------------------------------------------

func _start_level(index: int) -> void:
	_level_index = clampi(index, 0, LEVELS.size() - 1)
	var lvl: Dictionary = LEVELS[_level_index]
	_cols = lvl["cols"]
	_rows = lvl["rows"]
	_score = 0
	_oops = 0
	_active = false
	_resetting = false
	_popup.visible = false

	_build_maze()
	_spawn_entities(lvl)
	_center_world()
	_update_info()
	_active = true


func _build_maze() -> void:
	_maze.clear()
	# Border + interior pillars every 3rd column on even rows: this always
	# leaves fully-open corridors, so every cell stays reachable.
	for y in _rows:
		for x in _cols:
			var is_border := x == 0 or y == 0 or x == _cols - 1 or y == _rows - 1
			var is_pillar := x % 3 == 2 and y % 2 == 0
			if is_border or is_pillar:
				_maze.set_cell(Vector2i(x, y), WALL_SOURCE, Vector2i.ZERO)

	_player_start = _nearest_open(Vector2i(int(_cols / 2.0), _rows - 2))
	_ghost_starts.clear()
	var lvl: Dictionary = LEVELS[_level_index]
	var count: int = lvl["ghosts"]
	for i in count:
		var gx := int(_cols / 2.0) + (i - count / 2) * 2
		_ghost_starts.append(_nearest_open(Vector2i(gx, 1 + i * 2)))

	# Cherries on every open cell except the spawn cells.
	var reserved := {_player_start: true}
	for gs in _ghost_starts:
		reserved[gs] = true
	for y in _rows:
		for x in _cols:
			var c := Vector2i(x, y)
			if _maze.get_cell_source_id(c) == -1 and not reserved.has(c):
				_maze.set_cell(c, DOT_SOURCE, Vector2i.ZERO)


func _spawn_entities(lvl: Dictionary) -> void:
	for child in _entities.get_children():
		child.queue_free()
	_ghosts.clear()

	_player = PLAYER_SCENE.instantiate()
	_entities.add_child(_player)
	_player.configure(_is_wall)
	_player.speed = lvl["pac"]
	_player.place_at(_player_start)
	_player.arrived.connect(_on_player_arrived)

	for i in lvl["ghosts"]:
		var ghost: PackidGhost = GHOST_SCENE.instantiate()
		_entities.add_child(ghost)
		ghost.setup(_is_wall, GHOST_SKINS[i % GHOST_SKINS.size()], GHOST_TINTS[i % GHOST_TINTS.size()])
		ghost.speed = lvl["ghost"]
		ghost.place_at(_ghost_starts[i])
		_ghosts.append(ghost)


## Wall test handed to the actors.
func _is_wall(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= _cols or cell.y >= _rows:
		return true
	return _maze.get_cell_source_id(cell) == WALL_SOURCE


func _nearest_open(target: Vector2i) -> Vector2i:
	if not _is_wall(target):
		return target
	for radius in range(1, maxi(_cols, _rows)):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var c := target + Vector2i(dx, dy)
				if not _is_wall(c):
					return c
	return Vector2i(1, 1)


func _center_world() -> void:
	var view := get_viewport_rect().size
	var maze_px := Vector2(_cols * TILE, _rows * TILE) * WORLD_SCALE
	_world.scale = Vector2(WORLD_SCALE, WORLD_SCALE)
	_world.position = Vector2(
		(view.x - maze_px.x) * 0.5,
		84.0 + (view.y - 84.0 - maze_px.y) * 0.5
	)


# ---------------------------------------------------------------------------
# Play
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not _active or _resetting or _player == null:
		return
	for ghost in _ghosts:
		if _player.position.distance_to(ghost.position) < TILE * 0.72:
			_on_caught()
			return


func _on_player_arrived(cell: Vector2i) -> void:
	if not _active:
		return
	if _maze.get_cell_source_id(cell) == DOT_SOURCE:
		_maze.erase_cell(cell)
		_score += 1
		_play(_sfx_eat)
		_update_info()
		if _maze.get_used_cells_by_id(DOT_SOURCE).is_empty():
			_win()


func _on_caught() -> void:
	_resetting = true
	_oops += 1
	_play(_sfx_caught)
	_player.play_caught()
	for ghost in _ghosts:
		ghost.active = false
	_update_info()

	await get_tree().create_timer(RESET_PAUSE).timeout
	if not is_instance_valid(_player):
		return
	_player.place_at(_player_start)
	for i in _ghosts.size():
		_ghosts[i].place_at(_ghost_starts[i])
		_ghosts[i].active = true
	_resetting = false


func _win() -> void:
	_active = false
	_player.active = false
	for ghost in _ghosts:
		ghost.active = false
	_play(_sfx_win)

	var is_last := _level_index >= LEVELS.size() - 1
	_popup_label.text = "You ate every cherry!\nScore %d   Oops %d" % [_score, _oops]
	_popup_next.visible = not is_last
	_popup.visible = true
	(_popup_replay if is_last else _popup_next).grab_focus()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _update_info() -> void:
	_info_label.text = "Level %d / %d  -  %s      Score: %d      Oops: %d" % [
		_level_index + 1, LEVELS.size(), LEVELS[_level_index]["name"], _score, _oops
	]


func _play(player: AudioStreamPlayer) -> void:
	if player.stream != null:
		player.play()


func _go_home() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_home()
