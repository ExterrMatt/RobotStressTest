extends LocationBase
## Plays a single scripted event dialogue outside the intro sequence (e.g. the
## uncle's biweekly rent, the robot's suspicious morning). Main configures the
## event by setting metadata on the instance before it enters the tree:
##   event_key:             dialogue key in events.dlg
##   event_portrait:        "uncle" | "robot" | "drone" | "" (visual to show)
##   event_money_delta:     applied to GameState when the dialogue ends
##   event_anger_delta:     applied to GameState when the dialogue ends
##   event_suspicion_delta: applied to GameState when the dialogue ends
##   event_suspicion_floor_raise: permanent suspicion floor raised on end
##
## The result always sets skip_advance so the player returns to the same
## phase's day-planner instead of losing an activity slot to the conversation.

const EVENTS_FILE_ID := "events"
const EVENTS_PATH := "res://data/dialogue/events.dlg"
const UNCLE_TEXTURE_PATH := "res://assets/textures/characters/uncle/blue_shirt_uncle1.png"
const ROBOT_BACKGROUND_TEXTURE_PATH := "res://assets/textures/backgrounds/robot_eyes_open.png"
## Placeholder background for the patrol-drone encounter until dedicated art
## exists. Swap this for a drone scene when one is drawn.
const DRONE_BACKGROUND_PLACEHOLDER_PATH := "res://assets/textures/backgrounds/scene_placeholder.png"
const UNCLE_PORTRAIT_SCALE: float = 1.1

@onready var dialogue_box: DialogueBox = %DialogueBox

var _event_key: String = ""
var _portrait: String = ""
var _money_delta: int = 0
var _anger_delta: int = 0
var _suspicion_delta: int = 0
var _suspicion_floor_raise: int = 0


func _ready() -> void:
	Dialogue.load_file(EVENTS_FILE_ID, EVENTS_PATH)
	dialogue_box.finished.connect(_on_dialogue_finished)
	_event_key = String(get_meta("event_key", ""))
	_portrait = String(get_meta("event_portrait", ""))
	_money_delta = int(get_meta("event_money_delta", 0))
	_anger_delta = int(get_meta("event_anger_delta", 0))
	_suspicion_delta = int(get_meta("event_suspicion_delta", 0))
	_suspicion_floor_raise = int(get_meta("event_suspicion_floor_raise", 0))
	_apply_visuals()
	dialogue_box.play_pages(
		Dialogue.get_pages(EVENTS_FILE_ID, _event_key, {"name": GameState.get_player_name()})
	)


func _apply_visuals() -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	if _portrait == "uncle":
		if main.has_method("hide_teacher_portrait"):
			main.hide_teacher_portrait()
		var uncle_tex := load(UNCLE_TEXTURE_PATH) as Texture2D
		if uncle_tex != null and main.has_method("show_bottom_center_portrait"):
			main.show_bottom_center_portrait(uncle_tex, UNCLE_PORTRAIT_SCALE, "Uncle")
		return
	if _portrait == "robot":
		if main.has_method("hide_teacher_portrait"):
			main.hide_teacher_portrait()
		_set_background(ROBOT_BACKGROUND_TEXTURE_PATH)
		return
	if _portrait == "drone":
		if main.has_method("hide_teacher_portrait"):
			main.hide_teacher_portrait()
		_set_background(DRONE_BACKGROUND_PLACEHOLDER_PATH)
		return
	if main.has_method("hide_teacher_portrait"):
		main.hide_teacher_portrait()


func _set_background(texture_path: String) -> void:
	var main := get_tree().current_scene
	if main == null or not ("scene_image" in main):
		return
	var tex := load(texture_path) as Texture2D
	if tex != null:
		main.scene_image.texture = tex


func _on_dialogue_finished() -> void:
	# skip_advance keeps the player in the current phase; Main returns to the
	# day-planner and applies the deltas. suspicion_floor_raise is applied by
	# Main after the suspicion delta so a caught crime locks in a permanent floor.
	finish(
		_money_delta,
		_suspicion_delta,
		_anger_delta,
		{},
		true,
		{"suspicion_floor_raise": _suspicion_floor_raise}
	)
