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


## Convenience: build a result dict and emit. Subclasses call this when done.
## `extra` merges additional keys into the result (e.g. suspicion_floor_raise)
## for the handful of results that need effects beyond the standard deltas.
func finish(
	money_delta: int = 0,
	suspicion_delta: int = 0,
	anger_delta: int = 0,
	ingredients: Dictionary = {},
	skip_advance: bool = false,
	extra: Dictionary = {},
) -> void:
	if _finished_emitted:
		return
	_finished_emitted = true
	var result: Dictionary = {
		"money_delta": money_delta,
		"suspicion_delta": suspicion_delta,
		"anger_delta": anger_delta,
		"ingredients": ingredients,
		"skip_advance": skip_advance,
	}
	for key in extra:
		result[key] = extra[key]
	finished.emit(result)
