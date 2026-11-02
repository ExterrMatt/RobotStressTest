extends LocationBase
class_name MaintenanceIntro
## One-time cutscene in front of the first Maintenance visit: the player sneaks
## into his uncle's factory without clocking in, and the head in his bag hacks the
## cleaning robot that's blocking the PERSONNEL ONLY door. Plays in the normal
## framed view, then hands off to the fullscreen Maintenance scene through
## Main.enter_maintenance_from_intro() - the same detour SleepPrompt makes in
## front of Sleep.

## The hallway outside the PERSONNEL ONLY door. Packed Aseprite sheet: the
## "background" layer is the framed picture, and the cleaning robot ("body") sits
## on top as a scene overlay until it leaves. Once she hacks it, "head_turn" is
## drawn over the body as it looks round.
const INTRO_SHEET_PATH: String = "res://assets/textures/backgrounds/maintenance_hallway.png"
const INTRO_SHEET_JSON_PATH: String = "res://assets/textures/backgrounds/maintenance_hallway.json"
const INTRO_BACKGROUND_LAYER: String = "background"
const CLEANING_ROBOT_BODY_LAYER: String = "body"
const CLEANING_ROBOT_HEAD_TURN_LAYER: String = "head_turn"
## The page where her hack takes hold and the robot stops scrubbing.
const ROBOT_HACKED_CUE: String = "stops mid-scrub"
## The page where the hacked robot rolls off down the hall.
const ROBOT_LEAVES_CUE: String = "rolls down the hall"

@onready var dialogue_box: DialogueBox = %DialogueBox

var _pages: Array = []
var _cleaning_robot_overlay: Control = null
var _cleaning_robot_head_turn: TextureRect = null


func _ready() -> void:
	Dialogue.load_file("maintenance_intro", "res://data/dialogue/maintenance_intro.dlg")
	var main := get_tree().current_scene
	if main != null and main.has_method("hide_teacher_portrait"):
		main.hide_teacher_portrait()
	# Deferred: Main applies the location's preview_texture (the placeholder)
	# right after adding us, which would cover the hallway.
	_show_background.call_deferred()
	_show_cleaning_robot()

	GameState.maintenance_intro_seen = true
	_pages = Dialogue.get_pages("maintenance_intro", "intro")
	dialogue_box.page_advanced.connect(_on_page_advanced)
	dialogue_box.finished.connect(_on_dialogue_finished)
	dialogue_box.play_pages(_pages)


## The hallway sheet's layers, each rebuilt at the full 500x125 cell.
func _intro_layer(layer: String) -> Texture2D:
	return PackedSpriteSheet.layer_textures(INTRO_SHEET_PATH, INTRO_SHEET_JSON_PATH).get(layer) as Texture2D


func _show_background() -> void:
	var main := get_tree().current_scene
	if main == null or not ("scene_image" in main):
		return
	var tex := _intro_layer(INTRO_BACKGROUND_LAYER)
	if tex != null:
		main.scene_image.texture = tex


## Shows the cleaning robot as a full-frame overlay over the hallway (every sheet
## layer is 500x125, so it lines up exactly with the background).
func _show_cleaning_robot() -> void:
	var main: Node = get_tree().current_scene
	if main == null or not main.has_method("show_scene_overlay"):
		return
	_cleaning_robot_overlay = Control.new()
	_cleaning_robot_overlay.name = "CleaningRobotOverlay"
	_cleaning_robot_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_cleaning_robot_layer(CLEANING_ROBOT_BODY_LAYER)
	_cleaning_robot_head_turn = _add_cleaning_robot_layer(CLEANING_ROBOT_HEAD_TURN_LAYER)
	if _cleaning_robot_head_turn != null:
		_cleaning_robot_head_turn.visible = false
	main.show_scene_overlay(_cleaning_robot_overlay)


func _add_cleaning_robot_layer(layer: String) -> TextureRect:
	var texture := _intro_layer(layer)
	if texture == null:
		return null
	var rect := TextureRect.new()
	rect.name = layer.to_pascal_case()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cleaning_robot_overlay.add_child(rect)
	return rect


func _turn_cleaning_robot_head() -> void:
	if _cleaning_robot_head_turn != null and is_instance_valid(_cleaning_robot_head_turn):
		_cleaning_robot_head_turn.visible = true


func _hide_cleaning_robot() -> void:
	if _cleaning_robot_overlay != null and is_instance_valid(_cleaning_robot_overlay):
		_cleaning_robot_overlay.visible = false


func _on_page_advanced(index: int) -> void:
	if index < 0 or index >= _pages.size():
		return
	var text := ""
	for line in _pages[index]:
		text += String(line) + " "
	var lower := text.to_lower()
	if lower.contains(ROBOT_HACKED_CUE):
		_turn_cleaning_robot_head()
	if lower.contains(ROBOT_LEAVES_CUE):
		_hide_cleaning_robot()


func _on_dialogue_finished() -> void:
	var main: Node = get_tree().current_scene
	if main == null or not main.has_method("enter_maintenance_from_intro"):
		push_error("MaintenanceIntro: Main has no enter_maintenance_from_intro().")
		return
	main.call("enter_maintenance_from_intro")
