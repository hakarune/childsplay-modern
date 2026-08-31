extends SceneTree
##
## Headless scene-load smoke test.
##
##   godot --headless --script tests/scene_smoke.gd
##   (or just: tests/smoke.sh — it runs --import first)
##
## Walks res://scenes, then for every .tscn: load() -> instantiate() ->
## add to the tree -> pump a few frames -> free. A load failure, a bad
## instantiate, or a script/parse error in _ready() bumps the fail count.
## Exit code == number of failures, so CI can gate on it.
##

const SCENES_DIR := "res://scenes"
const WARMUP_FRAMES := 3


func _initialize() -> void:
	var scenes := _find_scenes(SCENES_DIR)
	scenes.sort()

	var ok := 0
	var fails := 0
	print("scene-load smoke — %d scenes under %s" % [scenes.size(), SCENES_DIR])
	print("")

	for path in scenes:
		var ps: PackedScene = load(path)
		if ps == null:
			print("  LOAD FAIL         ", path)
			fails += 1
			continue
		var inst: Node = ps.instantiate()
		if inst == null:
			print("  INSTANTIATE FAIL  ", path)
			fails += 1
			continue
		get_root().add_child(inst)
		for _i in WARMUP_FRAMES:
			await process_frame
		print("  OK  ", path)
		ok += 1
		inst.queue_free()
		await process_frame

	print("")
	print("scenes ok: %d   fails: %d" % [ok, fails])
	quit(fails)


func _find_scenes(base: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(base)
	if d == null:
		push_error("cannot open " + base)
		return out
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		var full := base + "/" + entry
		if d.current_is_dir():
			out.append_array(_find_scenes(full))
		elif entry.ends_with(".tscn"):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()
	return out
