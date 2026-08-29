extends Node
## GameContext — tiny autoload for handing a choice to the next scene.
##
## Godot's change_scene_to_file() can't pass arguments, so the Memory
## sub-menu stashes the picked deck here and Memory.gd reads it on _ready.

## One of: "pictures", "lower", "upper", "numbers"
var memory_variant := "pictures"
