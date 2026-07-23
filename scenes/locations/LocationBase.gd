extends Control
class_name LocationBase
## Base class for all location scenes.
##
## Each location scene extends this and calls finish(result) when the
## player completes the activity. Main listens for the finished signal
## and advances the day-cycle phase.
##
## Result dict convention (all keys optional):
##   money_delta: int       - added to GameState.money
##   suspicion_delta: int   - added to GameState.suspicion
##   anger_delta: int       - added to GameState.anger
##   ingredients: Dictionary[String, int]  - added to GameState.ingredients
##   skip_advance: bool     - if true, don't advance the phase (free action)
##
## Locations should NOT mutate GameState directly. They report a result and
## Main applies it. This keeps the audit trail centralized and makes it easy
## to add modifiers (e.g. suspicion-reduces-money) in one place later.
## Main also applies the flat skipped-stress-test anger penalty to Night
## activities that are not the Stress Test.

signal finished(result: Dictionary)

const DEFAULT_ENTRY_INPUT_LOCK_SECONDS: float = 0.2

var _finished_emitted: bool = false
var _entry_input_blocker_layer: CanvasLayer = null
var _entry_input_blocker: Control = null
var _entry_input_lock_serial: int = 0


## True when debug mode is on AND the player is currently holding Enter.
##
## The dialogue box already lets a held Enter fast-forward prose while debug
## mode is on. Intro obstacle minigames (the school question, Ed's shop, the
## sleep blanket, the work slots, the workshop craft, the stress test) break
## that flow because they need a manual click. Scenes poll this each frame so a
## held Enter can auto-resolve them too — letting a debug player speed through
## the whole intro without ever releasing Enter. Non-debug play is untouched.
func debug_enter_held() -> bool:
	return GameState.debug_mode_enabled \
		and (Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER))


## True when a DIFFERENT location has already become Main's active location —
## meaning the shared scene/inventory overlays now belong to it. Location swaps
## queue_free the outgoing node, so its _exit_tree can run a frame LATER, after
## the incoming location's _ready has already installed its own overlay. A
## location's _exit_tree teardown of the shared overlays must therefore bail when
## this returns true, or it wipes the incoming scene's art — this is what
## occasionally left the patrol drone invisible after a work/store run. Main
## always clears the outgoing overlay centrally before loading the next location,
## so skipping here never leaks.
func superseded_by_new_location(main: Node) -> bool:
	if main == null or not ("_current_location_node" in main):
		return false
	var current: Object = main._current_location_node
	return current != null and is_instance_valid(current) and current != self


func lock_entry_input(seconds: float = DEFAULT_ENTRY_INPUT_LOCK_SECONDS) -> void:
	if seconds <= 0.0:
		return

	_entry_input_lock_serial += 1
	var lock_serial := _entry_input_lock_serial
	_ensure_entry_input_blocker()
	_entry_input_blocker.visible = true

	await get_tree().create_timer(seconds).timeout
	if lock_serial != _entry_input_lock_serial:
		return
	if _entry_input_blocker != null and is_instance_valid(_entry_input_blocker):
		_entry_input_blocker.visible = false


func _ensure_entry_input_blocker() -> void:
	if _entry_input_blocker != null and is_instance_valid(_entry_input_blocker):
		return

	_entry_input_blocker_layer = CanvasLayer.new()
	_entry_input_blocker_layer.name = "EntryInputBlockerLayer"
	_entry_input_blocker_layer.layer = 4095
	add_child(_entry_input_blocker_layer)

	_entry_input_blocker = Control.new()
	_entry_input_blocker.name = "EntryInputBlocker"
	_entry_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_entry_input_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_entry_input_blocker_layer.add_child(_entry_input_blocker)


## Flattens a dialogue entry into a single string (its lines joined with
## spaces). Use it to pull one-off prose - a prompt, a button label - from a
## .dlg file instead of hardcoding it in a scene script, so every player-facing
## word stays editable in data/dialogue. Returns "" if the key is unknown.
func dlg_line(file_id: String, key: String, fmt: Dictionary = {}) -> String:
	var out: String = ""
	for page in Dialogue.get_pages(file_id, key, fmt):
		for line in page:
			if out != "":
				out += " "
			out += String(line)
	return out


## Convenience: build a result dict and emit. Subclasses call this when done.
## `contraband` is the display name of anything the player stole this scene
## (e.g. "pile of nanobots"); empty means they left clean. The patrol-drone
## encounter reads it to branch its dialogue.
func finish(
	money_delta: int = 0,
	suspicion_delta: int = 0,
	anger_delta: int = 0,
	ingredients: Dictionary = {},
	skip_advance: bool = false,
	contraband: String = "",
) -> void:
	if _finished_emitted:
		return
	_finished_emitted = true
	finished.emit({
		"money_delta": money_delta,
		"suspicion_delta": suspicion_delta,
		"anger_delta": anger_delta,
		"ingredients": ingredients,
		"skip_advance": skip_advance,
		"contraband": contraband,
	})
