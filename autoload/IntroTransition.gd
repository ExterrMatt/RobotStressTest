extends Node
## Cross-scene flag for the intro wipe.
##
## When the player picks New Game on MainMenu, we want Main.tscn to load
## fully, lay out its picture frame, and THEN play the FlowerLoad wipe
## starting at frame 9 (fully covered) inside that frame. This autoload
## carries the "please play the intro wipe on _ready()" signal across the
## scene swap, since MainMenu can't reach into Main.tscn's not-yet-existing
## nodes from its own side.
##
## Usage:
##   MainMenu sets `pending_intro = true` then calls change_scene_to_file().
##   Main.gd checks `IntroTransition.consume_intro()` in its _ready() and,
##   if true, plays the wipe from frame 9.
##
## Registered in project.godot under [autoload]:
##   IntroTransition="*res://autoload/IntroTransition.gd"

## Set by MainMenu before handing off to Main.tscn. Read once by Main.gd
## on _ready() via consume_intro(), which clears the flag.
var pending_intro: bool = false
var _pending_debug_jump: Dictionary = {}


func request_debug_jump(number: int, shift_held: bool, ctrl_held: bool) -> void:
	pending_intro = false
	_pending_debug_jump = {
		"number": number,
		"shift": shift_held,
		"ctrl": ctrl_held,
	}


## Returns whether an intro wipe was requested, and clears the flag.
## "Consume" semantics so subsequent visits to Main.tscn (returning from
## the menu later, for example) don't re-trigger the wipe.
func consume_intro() -> bool:
	var was_pending: bool = pending_intro
	pending_intro = false
	return was_pending


func consume_debug_jump() -> Dictionary:
	var request := _pending_debug_jump.duplicate()
	_pending_debug_jump.clear()
	return request
