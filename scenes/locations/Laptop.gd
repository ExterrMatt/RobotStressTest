extends LocationBase
## Debug "laptop" scene: a couple of cheat buttons that pre-arm the next stress
## test. It is reached the same way as the other debug-only scenes — via the
## numbered scene-jump hotkey (see Main._debug_open_laptop) — while the bedroom's
## "Laptop" option itself stays visible-but-disabled for now.
##
## The buttons write to GameState (stress_test_bonus_time_seconds and
## stress_test_awareness_threshold_multiplier); StressTest reads both as it
## starts. Leaving is a free action, so the phase is not consumed.

const TIME_BONUS_STEP_SECONDS: float = 30.0
const AWARENESS_THRESHOLD_FACTOR: float = 2.0

@onready var status_label: Label = %StatusLabel
@onready var add_time_button: Button = %AddTimeButton
@onready var double_awareness_button: Button = %DoubleAwarenessButton


func _ready() -> void:
	add_time_button.pressed.connect(_on_add_time_pressed)
	double_awareness_button.pressed.connect(_on_double_awareness_pressed)
	_refresh_status()

	# The back action lives in Main's picture-frame corner button, like the other
	# location scenes.
	var main: Node = get_tree().current_scene
	if main and main.has_method("show_corner_button"):
		main.show_corner_button("<- BACK", _on_back_pressed)


func _on_add_time_pressed() -> void:
	GameState.stress_test_bonus_time_seconds += TIME_BONUS_STEP_SECONDS
	_refresh_status()


func _on_double_awareness_pressed() -> void:
	GameState.stress_test_awareness_threshold_multiplier *= AWARENESS_THRESHOLD_FACTOR
	_refresh_status()


func _refresh_status() -> void:
	if status_label == null:
		return
	status_label.text = "Next stress test:\nBonus time  +%.0fs\nAwareness threshold  x%.0f" % [
		GameState.stress_test_bonus_time_seconds,
		GameState.stress_test_awareness_threshold_multiplier,
	]


func _on_back_pressed() -> void:
	# Free action - return to the bedroom without advancing the phase.
	finish(0, 0, 0, {}, true)
