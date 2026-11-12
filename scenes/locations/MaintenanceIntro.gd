extends LocationBase
class_name MaintenanceIntro
## One-time cutscene in front of the first Maintenance visit: the player sneaks
## into his uncle's factory without clocking in, and the head in his bag hacks the
## cleaning robot that's blocking the PERSONNEL ONLY door. Plays in the normal
## framed view, then hands off to the fullscreen Maintenance scene through
## Main.enter_maintenance_from_intro() - the same detour SleepPrompt makes in
## front of Sleep.
##
## Backgrounds, in order: the factory from outside (first page), the maintenance
## stairs (up to the peek around the corner), then the hallway with the cleaning
## robot for the rest.

## Outside the factory, shown on the opening page.
const OUTSIDE_BACKGROUND_PATH: String = "res://assets/textures/backgrounds/factory_outside.png"
## The maintenance stairs, shown briefly on the fourth page, right before the peek around the corner.
const STAIRS_BACKGROUND_PATH: String = "res://assets/textures/backgrounds/maintenance_stairs.png"
## The hallway outside the PERSONNEL ONLY door. Packed Aseprite sheet: the
## "background" layer is the framed picture, and the cleaning robot ("body") sits
## on top as a scene overlay until it leaves. Once she hacks it, "head_turn" is
## drawn over the body as it looks round.
const INTRO_SHEET_PATH: String = "res://assets/textures/backgrounds/maintenance_hallway.png"
const INTRO_SHEET_JSON_PATH: String = "res://assets/textures/backgrounds/maintenance_hallway.json"
const INTRO_BACKGROUND_LAYER: String = "background"
const CLEANING_ROBOT_BODY_LAYER: String = "body"
const CLEANING_ROBOT_HEAD_TURN_LAYER: String = "head_turn"
## The stairs take over from the outside on this page (the second one, 0-based 1),
## whatever it says, until the hallway cue.
const STAIRS_PAGE_INDEX: int = 1
## The page where he peeks round the corner into the hallway.
const HALLWAY_CUE: String = "peer around the corner"
## The page where her hack takes hold and the robot stops scrubbing.
const ROBOT_HACKED_CUE: String = "stops mid-scrub"
## The page where the hacked robot heads off down the hall and out of sight.
const ROBOT_LEAVES_CUE: String = "down the hall"

enum Stage { OUTSIDE, STAIRS, HALLWAY }

@onready var dialogue_box: DialogueBox = %DialogueBox

var _pages: Array = []
var _stage: Stage = Stage.OUTSIDE
var _cleaning_robot_overlay: Control = null
var _cleaning_robot_head_turn: TextureRect = null


func _ready() -> void:
	Dialogue.load_file("maintenance_intro", "res://data/dialogue/maintenance_intro.dlg")
	var main := get_tree().current_scene
	if main != null and main.has_method("hide_teacher_portrait"):
		main.hide_teacher_portrait()
	# Deferred: Main applies the location's preview_texture (the placeholder)
	# right after adding us, which would cover our background.
	_apply_background.call_deferred()
	_build_cleaning_robot()

	GameState.maintenance_intro_seen = true
	_pages = Dialogue.get_pages("maintenance_intro", "intro")
	dialogue_box.page_advanced.connect(_on_page_advanced)
	dialogue_box.finished.connect(_on_dialogue_finished)
	dialogue_box.play_pages(_pages)


## The hallway sheet's layers, each rebuilt at the full 500x125 cell.
func _intro_layer(layer: String) -> Texture2D:
	return PackedSpriteSheet.layer_textures(INTRO_SHEET_PATH, INTRO_SHEET_JSON_PATH).get(layer) as Texture2D


func _stage_texture(stage: Stage) -> Texture2D:
	match stage:
		Stage.OUTSIDE:
			return load(OUTSIDE_BACKGROUND_PATH) as Texture2D
		Stage.STAIRS:
			return load(STAIRS_BACKGROUND_PATH) as Texture2D
		_:
			return _intro_layer(INTRO_BACKGROUND_LAYER)


## Puts the current stage's picture in Main's frame. The cleaning robot is only
## in the hallway, so its overlay follows the stage too.
func _apply_background() -> void:
	var main := get_tree().current_scene
	if main != null and ("scene_image" in main):
		var tex := _stage_texture(_stage)
		if tex != null:
			main.scene_image.texture = tex
	if _stage != Stage.HALLWAY:
		_set_cleaning_robot_visible(false)


func _set_stage(stage: Stage) -> void:
	if stage == _stage:
		return
	_stage = stage
	_apply_background()
	if stage == Stage.HALLWAY:
		_set_cleaning_robot_visible(true)


## Builds the cleaning robot as a full-frame overlay (every sheet layer is
## 500x125, so it lines up exactly with the hallway). Hidden until the hallway.
func _build_cleaning_robot() -> void:
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
	_cleaning_robot_overlay.visible = false
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


func _set_cleaning_robot_visible(shown: bool) -> void:
	if _cleaning_robot_overlay != null and is_instance_valid(_cleaning_robot_overlay):
		_cleaning_robot_overlay.visible = shown


func _on_page_advanced(index: int) -> void:
	if index < 0 or index >= _pages.size():
		return
	var text := ""
	for line in _pages[index]:
		text += String(line) + " "
	var lower := text.to_lower()
	if index >= STAIRS_PAGE_INDEX and _stage == Stage.OUTSIDE:
		_set_stage(Stage.STAIRS)
	if lower.contains(HALLWAY_CUE):
		_set_stage(Stage.HALLWAY)
	if lower.contains(ROBOT_HACKED_CUE):
		_turn_cleaning_robot_head()
	if lower.contains(ROBOT_LEAVES_CUE):
		_set_cleaning_robot_visible(false)


func _on_dialogue_finished() -> void:
	var main: Node = get_tree().current_scene
	if main == null or not main.has_method("enter_maintenance_from_intro"):
		push_error("MaintenanceIntro: Main has no enter_maintenance_from_intro().")
		return
	main.call("enter_maintenance_from_intro")
