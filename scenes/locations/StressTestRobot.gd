@tool
extends Control

signal visual_state_changed

const RobotHoverBox: GDScript = preload("res://scenes/locations/RobotHoverBox.gd")

const DEFAULT_FRAME_SIZE: Vector2i = Vector2i(250, 350)
const CLICK_ACTION_TOGGLE_VISIBILITY: int = 0
const CLICK_ACTION_PRIME_THEN_PLAY_ANIMATION: int = 1
const ANIMATION_PHASE_NONE: String = ""
const ANIMATION_PHASE_INTRO: String = "intro"
const ANIMATION_PHASE_LOOP: String = "loop"
const HOVER_BOX_OVERLAY_Z_INDEX: int = 1000
const WOOD_CREAK_SOUND_PATHS: Array[String] = [
	"res://assets/sounds/wood/wood_creak.mp3",
	"res://assets/sounds/wood/wood_creak_long.mp3",
	"res://assets/sounds/wood/wood_creak_slight.mp3",
]
const HAND_RUB_SOUND_PATHS: Array[String] = [
	"res://assets/sounds/hands/hand_rub_long_1.mp3",
	"res://assets/sounds/hands/hand_rub_long_2.mp3",
	"res://assets/sounds/hands/hand_rub_long_3.mp3",
	"res://assets/sounds/hands/hand_rub_loud.mp3",
]

## Chest overlays swapped by the per-side shoulder-pad toggles: each side shows
## its chest outline while that side's pad is on, and its chest details while
## the pad is off. The base chest stays visible in both states.
const CHEST_PATH: NodePath = ^"Torso/Chest"
const CHEST_DETAILS_LEFT_PATH: NodePath = ^"Torso/ChestDetailsLeft"
const CHEST_DETAILS_RIGHT_PATH: NodePath = ^"Torso/ChestDetailsRight"
const CHEST_OUTLINE_LEFT_PATH: NodePath = ^"Torso/ChestOutlineLeft"
const CHEST_OUTLINE_RIGHT_PATH: NodePath = ^"Torso/ChestOutlineRight"
const LEFT_SHOULDER_PAD_PATH: NodePath = ^"Arms/LeftShoulderPad"
const RIGHT_SHOULDER_PAD_PATH: NodePath = ^"Arms/RightShoulderPad"
const LEFT_SHOULDER_HOVER_BOX_NAME: String = "LeftShoulderHoverBox"
const RIGHT_SHOULDER_HOVER_BOX_NAME: String = "RightShoulderHoverBox"
const SHOULDER_HOVER_BOX_NAMES: Array[String] = [LEFT_SHOULDER_HOVER_BOX_NAME, RIGHT_SHOULDER_HOVER_BOX_NAME]

## The head-animation strips carry the shoulder pads and the per-side chest
## outline/details as their own columns. Each side mirrors the static robot:
## the pad and outline columns show while that side's pad is on, the details
## column shows while it is off.
const ANIM_LEFT_SHOULDER_PAD_PATHS: Array[NodePath] = [
	^"AnimationLayers/LeftShoulderPad",
	^"AnimationLayers/MouthBLoopMedium/LeftShoulderPad",
]
const ANIM_RIGHT_SHOULDER_PAD_PATHS: Array[NodePath] = [
	^"AnimationLayers/RightShoulderPad",
	^"AnimationLayers/MouthBLoopMedium/RightShoulderPad",
]
const ANIM_CHEST_OUTLINE_LEFT_PATHS: Array[NodePath] = [
	^"AnimationLayers/ChestOutlineLeft",
	^"AnimationLayers/MouthBLoopMedium/ChestOutlineLeft",
]
const ANIM_CHEST_OUTLINE_RIGHT_PATHS: Array[NodePath] = [
	^"AnimationLayers/ChestOutlineRight",
	^"AnimationLayers/MouthBLoopMedium/ChestOutlineRight",
]
const ANIM_CHEST_DETAILS_LEFT_PATHS: Array[NodePath] = [
	^"AnimationLayers/ChestDetailsLeft",
	^"AnimationLayers/MouthBLoopMedium/ChestDetailsLeft",
]
const ANIM_CHEST_DETAILS_RIGHT_PATHS: Array[NodePath] = [
	^"AnimationLayers/ChestDetailsRight",
	^"AnimationLayers/MouthBLoopMedium/ChestDetailsRight",
]

## Front cover for the neck, shown only while the head is the robot's sole
## remaining part (no chest, stomach, arms, hands, or legs). The texture is loaded at
## runtime so the scene keeps working until the art file is added.
const NECK_FRONT_PATH: NodePath = ^"Torso/NeckFront"
const NECK_FRONT_TEXTURE_PATH: String = "res://assets/textures/characters/robot/stresstest/head/neck_front.png"

## Head styles swapped by the Shift+H debug key. One is shown at a time on the
## static head and the matching column drives the head animation. The default is
## head_2 (index 1).
const HEAD_DEFAULT_INDEX: int = 1
const HEAD_HEAD2_INDEX: int = 1
const HEAD_STATIC_OPTIONS: Array[NodePath] = [
	^"Head/HeadBase",
	^"Head/Head2",
]
const HEAD_INTRO_ANIM_OPTIONS: Array[NodePath] = [
	^"AnimationLayers/Head",
	^"AnimationLayers/Head2",
]
const HEAD_LOOP_ANIM_OPTIONS: Array[NodePath] = [
	^"AnimationLayers/MouthBLoopMedium/Head",
	^"AnimationLayers/MouthBLoopMedium/Head2",
]

## Squint-eyes overlay toggled by the Ctrl+Shift+H debug key. Off by default.
## While the head_2 style is selected, the static squint eyes sit one pixel lower.
const SQUINT_DEFAULT_ENABLED: bool = false
const SQUINT_HEAD2_LOWER_PX: float = 1.0
const SQUINT_STATIC_PATH: NodePath = ^"Head/SquintEyes"
const SQUINT_ANIM_PATHS: Array[NodePath] = [
	^"AnimationLayers/SquintEyes",
	^"AnimationLayers/MouthBLoopMedium/SquintEyes",
]

## Hair-front styles cycled by the hair hover box, in click order. One style is
## shown at a time on the static head; the matching column drives the head
## animation. The default is the swing style.
const HAIR_HOVER_BOX_NAME: String = "HairHoverBox"
const HAIR_DEFAULT_INDEX: int = 1
const HAIR_STATIC_OPTIONS: Array[NodePath] = [
	^"Head/HairFrontNormal",
	^"Head/HairFrontSwing",
	^"Head/HairFrontBangs",
]
const HAIR_INTRO_ANIM_OPTIONS: Array[NodePath] = [
	^"AnimationLayers/HairFrontNormal",
	^"AnimationLayers/HairFrontSwing",
	^"AnimationLayers/HairFrontBangs",
]
const HAIR_LOOP_ANIM_OPTIONS: Array[NodePath] = [
	^"AnimationLayers/MouthBLoopMedium/HairFrontNormal",
	^"AnimationLayers/MouthBLoopMedium/HairFrontSwing",
	^"AnimationLayers/MouthBLoopMedium/HairFrontBangs",
]

# The old single "torso" part is split into two independently-gated parts:
# the chest (chest plates/outlines/details, coconuts, pepperonis, chest cover) and
# the stomach (the base body silhouette, crunch/abs, neck backing).
const CHEST_PART_PATHS: Array[NodePath] = [
	^"Torso/Chest",
	^"Torso/ChestDetailsLeft",
	^"Torso/ChestDetailsRight",
	^"Torso/ChestOutlineLeft",
	^"Torso/ChestOutlineRight",
	^"Torso/BigCoconuts",
	^"Torso/SmallCoconuts",
	^"Torso/Pepperonis",
	^"ChestCover",
	^"AnimationLayers/Chest",
	^"AnimationLayers/ChestDetailsLeft",
	^"AnimationLayers/ChestDetailsRight",
	^"AnimationLayers/ChestOutlineLeft",
	^"AnimationLayers/ChestOutlineRight",
	^"AnimationLayers/MouthBLoopMedium/Chest",
	^"AnimationLayers/MouthBLoopMedium/ChestDetailsLeft",
	^"AnimationLayers/MouthBLoopMedium/ChestDetailsRight",
	^"AnimationLayers/MouthBLoopMedium/ChestOutlineLeft",
	^"AnimationLayers/MouthBLoopMedium/ChestOutlineRight",
	# The leg/vegetable animation now carries its own chest-region columns, so
	# they are gated on owning a chest just like the static and head-animation
	# chest sprites.
	^"AnimationLayers/VegetableMissionIntro/Chest",
	^"AnimationLayers/VegetableMissionIntro/SmallCoconuts",
	^"AnimationLayers/VegetableMissionIntro/BigCoconuts",
	^"AnimationLayers/VegetableMissionIntro/Pepperonis",
	^"AnimationLayers/VegetableMissionLoopMedium/Chest",
	^"AnimationLayers/VegetableMissionLoopMedium/SmallCoconuts",
	^"AnimationLayers/VegetableMissionLoopMedium/BigCoconuts",
	^"AnimationLayers/VegetableMissionLoopMedium/Pepperonis",
]

## Cosmetic chest overlays gated on owning the matching GameState cosmetic item
## (in addition to the chest-part gate above). Each list covers the static
## sprite and both leg-animation columns for that item.
const BIG_COCONUTS_ITEM_PATHS: Array[NodePath] = [
	^"Torso/BigCoconuts",
	^"AnimationLayers/VegetableMissionIntro/BigCoconuts",
	^"AnimationLayers/VegetableMissionLoopMedium/BigCoconuts",
]
const SMALL_COCONUTS_ITEM_PATHS: Array[NodePath] = [
	^"Torso/SmallCoconuts",
	^"AnimationLayers/VegetableMissionIntro/SmallCoconuts",
	^"AnimationLayers/VegetableMissionLoopMedium/SmallCoconuts",
]
const CHEST_COVER_ITEM_PATHS: Array[NodePath] = [
	^"ChestCover",
]

## The chest sprite is shared when the head and pelvis animations run together:
## the head half draws the top of the cell, the pelvis half the bottom.
const HEAD_CHEST_ANIM_PATHS: Array[NodePath] = [
	^"AnimationLayers/Chest",
	^"AnimationLayers/MouthBLoopMedium/Chest",
]
const PELVIS_CHEST_ANIM_PATHS: Array[NodePath] = [
	^"AnimationLayers/VegetableMissionIntro/Chest",
	^"AnimationLayers/VegetableMissionLoopMedium/Chest",
]
const STOMACH_PART_PATHS: Array[NodePath] = [
	^"Torso/TorsoNeckBack",
	^"Torso/TorsoBase",
	^"Torso/TorsoCrunch",
]
const LEFT_ARM_PART_PATHS: Array[NodePath] = [
	^"Arms/LeftArm",
	^"Arms/LeftShoulderPad",
	^"AnimationArmLayers/LeftArm",
	^"AnimationArmLayers/MouthBLoopMedium/LeftArm",
	^"AnimationLayers/LeftShoulderPad",
	^"AnimationLayers/MouthBLoopMedium/LeftShoulderPad",
]
const RIGHT_ARM_PART_PATHS: Array[NodePath] = [
	^"Arms/RightArm",
	^"Arms/RightShoulderPad",
	^"AnimationArmLayers/RightArm",
	^"AnimationArmLayers/MouthBLoopMedium/RightArm",
	^"AnimationLayers/RightShoulderPad",
	^"AnimationLayers/MouthBLoopMedium/RightShoulderPad",
]
const LEFT_HAND_PART_PATHS: Array[NodePath] = [
	^"Hands/LeftPalmUp",
	^"Hands/LeftOpenFingers",
	^"Hands/LeftFlexedFingers",
]
const RIGHT_HAND_PART_PATHS: Array[NodePath] = [
	^"Hands/RightPalmUp",
	^"Hands/RightOpenFingers",
	^"Hands/RightFlexedFingers",
]

## Hand-pose options cycled by the per-hand hover boxes, in click order. One
## texture per hand is shown at a time; clicking the hand advances to the next.
const LEFT_HAND_TEXTURE_OPTIONS: Array[NodePath] = [
	^"Hands/LeftPalmUp",
	^"Hands/LeftOpenFingers",
	^"Hands/LeftFlexedFingers",
]
const RIGHT_HAND_TEXTURE_OPTIONS: Array[NodePath] = [
	^"Hands/RightPalmUp",
	^"Hands/RightOpenFingers",
	^"Hands/RightFlexedFingers",
]
const LEFT_HAND_HOVER_BOX_NAME: String = "LeftHandHoverBox"
const RIGHT_HAND_HOVER_BOX_NAME: String = "RightHandHoverBox"
const LEFT_LEG_PART_PATHS: Array[NodePath] = [
	^"Legs/LeftLeg",
	^"Legs/LeftLegSlightlyOut",
	^"Legs/LeftLegUpThigh",
	^"Legs/LeftLegUpShin",
]
const RIGHT_LEG_PART_PATHS: Array[NodePath] = [
	^"Legs/RightLeg",
	^"Legs/RightLegSlightlyOut",
	^"Legs/RightLegUpThigh",
	^"Legs/RightLegUpShin",
]

## Sleep-only leg pre-stage: the first click parts the legs into the
## "slightly out" pose before the following click lifts them. The standing
## legs are swapped for their slightly-out variants for this one stage.
const LEG_PRESTAGE_HIDDEN_PATHS: Array[NodePath] = [^"Legs/LeftLeg", ^"Legs/RightLeg"]
const LEG_PRESTAGE_SHOWN_PATHS: Array[NodePath] = [^"Legs/LeftLegSlightlyOut", ^"Legs/RightLegSlightlyOut"]
const LEG_PRESTAGE_BOX_NAME: String = "PelvisHoverBox"

## Per-leg pose cycle beneath the pelvis hover box: each click on a leg advances
## it one step through standing -> slightly-out -> raised (locked to the pelvis
## animation's first frame) -> standing, for that side only.
const LEFT_LEG_HOVER_BOX_NAME: String = "LeftLegHoverBox"
const RIGHT_LEG_HOVER_BOX_NAME: String = "RightLegHoverBox"

## Per-leg pose steps. RAISED matches frame 0 of the pelvis (vegetable-mission)
## animation, so the static raised leg hands off seamlessly once the pelvis
## animation begins.
const LEG_POSE_DEFAULT: int = 0
const LEG_POSE_SLIGHTLY_OUT: int = 1
const LEG_POSE_RAISED: int = 2
const LEG_POSE_COUNT: int = 3

## Static leg sprites shown for each per-side pose step. The pose selection owns
## these while the pelvis animation is not running; a missing leg still hides
## them all through the part-availability pass.
const LEFT_LEG_POSE_DEFAULT_PATHS: Array[NodePath] = [^"Legs/LeftLeg"]
const LEFT_LEG_POSE_SLIGHTLY_OUT_PATHS: Array[NodePath] = [^"Legs/LeftLegSlightlyOut"]
const LEFT_LEG_POSE_RAISED_PATHS: Array[NodePath] = [^"Legs/LeftLegUpThigh", ^"Legs/LeftLegUpShin"]
const RIGHT_LEG_POSE_DEFAULT_PATHS: Array[NodePath] = [^"Legs/RightLeg"]
const RIGHT_LEG_POSE_SLIGHTLY_OUT_PATHS: Array[NodePath] = [^"Legs/RightLegSlightlyOut"]
const RIGHT_LEG_POSE_RAISED_PATHS: Array[NodePath] = [^"Legs/RightLegUpThigh", ^"Legs/RightLegUpShin"]

## Cosmetic chest overlays whose leg-animation columns must not play while the
## chest cover is still equipped: the cover hides the chest, so the vegetables
## painted onto the raised-leg animation would show through it otherwise.
const CHEST_COVER_PATH: NodePath = ^"ChestCover"
const CHEST_COVER_GATED_ANIM_PATHS: Array[NodePath] = [
	^"AnimationLayers/VegetableMissionIntro/BigCoconuts",
	^"AnimationLayers/VegetableMissionIntro/SmallCoconuts",
	^"AnimationLayers/VegetableMissionIntro/Pepperonis",
	^"AnimationLayers/VegetableMissionLoopMedium/BigCoconuts",
	^"AnimationLayers/VegetableMissionLoopMedium/SmallCoconuts",
	^"AnimationLayers/VegetableMissionLoopMedium/Pepperonis",
]

## The vegetable-mission strips carry both hand grips as separate columns.
## Only one grip is shown at a time; the H key flips between them in debug mode.
const OVERGRIP_HAND_PATHS: Array[NodePath] = [
	^"AnimationLayers/VegetableMissionIntro/LeftHandOvergrip",
	^"AnimationLayers/VegetableMissionIntro/RightHandOvergrip",
	^"AnimationLayers/VegetableMissionLoopMedium/LeftHandOvergrip",
	^"AnimationLayers/VegetableMissionLoopMedium/RightHandOvergrip",
]
const UNDERGRIP_HAND_PATHS: Array[NodePath] = [
	^"AnimationLayers/VegetableMissionIntro/LeftHandUndergrip",
	^"AnimationLayers/VegetableMissionIntro/RightHandUndergrip",
	^"AnimationLayers/VegetableMissionLoopMedium/LeftHandUndergrip",
	^"AnimationLayers/VegetableMissionLoopMedium/RightHandUndergrip",
]

## The player's own hands, gripping the robot's raised legs during the pelvis
## animation. These are the human hands seen on-screen (both grip styles, in
## the intro and loop layers), grouped by side so the matching one can be
## hidden while that hand is busy driving a screw.
const LEFT_GRIP_HAND_PATHS: Array[NodePath] = [
	^"AnimationLayers/VegetableMissionIntro/LeftHandOvergrip",
	^"AnimationLayers/VegetableMissionIntro/LeftHandUndergrip",
	^"AnimationLayers/VegetableMissionLoopMedium/LeftHandOvergrip",
	^"AnimationLayers/VegetableMissionLoopMedium/LeftHandUndergrip",
]
const RIGHT_GRIP_HAND_PATHS: Array[NodePath] = [
	^"AnimationLayers/VegetableMissionIntro/RightHandOvergrip",
	^"AnimationLayers/VegetableMissionIntro/RightHandUndergrip",
	^"AnimationLayers/VegetableMissionLoopMedium/RightHandOvergrip",
	^"AnimationLayers/VegetableMissionLoopMedium/RightHandUndergrip",
]

@export var hover_box_paths: Array[NodePath] = [^"HeadHoverBox", ^"HairHoverBox", ^"PelvisHoverBox", ^"ChestCoverHoverBox", ^"LeftShoulderHoverBox", ^"RightShoulderHoverBox", ^"LeftHandHoverBox", ^"RightHandHoverBox", ^"LeftLegHoverBox", ^"RightLegHoverBox"]:
	set(value):
		hover_box_paths = value
		_request_configuration_refresh()

@export var animation_layers_path: NodePath = ^"AnimationLayers":
	set(value):
		animation_layers_path = value
		_request_configuration_refresh()

@export var sync_animation_layer_scale: bool = true

## Nodes that must stay hidden in-game and in hover previews until removed here.
@export var always_hidden_image_paths: Array[NodePath] = []:
	set(value):
		always_hidden_image_paths = value
		_request_configuration_refresh()

var _hover_boxes: Array[Control] = []
var _managed_paths: Array[NodePath] = []
var _base_visibility: Dictionary = {}
var _interaction_enabled: bool = true
var _editor_preview_was_active: bool = false
var _hand_grip_overgrip: bool = true

## Active layered animations, keyed by hover box. Each value is a Dictionary
## with "phase" (String), "playing" (bool) and "elapsed" (float). Normally at
## most one entry exists; debug shift-clicking can run head and pelvis at once.
var _animation_states: Dictionary = {}
## When enabled (Sleep scene) the leg lift gains a preliminary "slightly out"
## pose; the stress test leaves this off and lifts on the first click.
var _leg_slight_out_prestage_enabled: bool = false
var _leg_prestage_active: bool = false
## Currently selected hand-pose option per side (index into the option lists).
var _left_hand_texture_index: int = 0
var _right_hand_texture_index: int = 0
## Current per-side leg pose step (LEG_POSE_*). The pelvis animation may only
## begin once both sides reach LEG_POSE_RAISED.
var _left_leg_pose: int = LEG_POSE_DEFAULT
var _right_leg_pose: int = LEG_POSE_DEFAULT
## Currently selected hair-front style (index into the hair option lists).
var _hair_texture_index: int = HAIR_DEFAULT_INDEX
## Currently selected head style (index into the head option lists).
var _head_texture_index: int = HEAD_DEFAULT_INDEX
## Whether the squint-eyes overlay is shown.
var _squint_eyes_enabled: bool = SQUINT_DEFAULT_ENABLED
var _rng := RandomNumberGenerator.new()
var _wood_creak_sounds: Array[AudioStream] = []
var _hand_rub_sounds: Array[AudioStream] = []
var _wood_creak_audio_player: AudioStreamPlayer = null
var _hand_rub_audio_player: AudioStreamPlayer = null
## Sides ("left"/"right") whose player hand is currently hidden because that
## hand is holding the screwdriver on that side during a stress-test repair.
var _repair_hidden_hand_sides: Dictionary = {}


func _ready() -> void:
	_initialize_neck_front_texture()
	_refresh_configuration()
	_sync_animation_layers_to_robot_size()
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	_connect_robot_part_state()
	if not Engine.is_editor_hint():
		_rng.randomize()
		_initialize_interaction_sounds()
	set_process(true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_update_editor_preview()
		_enforce_always_hidden_paths()
		return

	_update_hover_boxes()
	if not _animation_states.is_empty():
		_advance_animations(delta)
	_enforce_always_hidden_paths()


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventKey:
		_handle_debug_key(event as InputEventKey)
		return
	if not _interaction_enabled:
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	var clicked_box := _find_clicked_hover_box(mouse_event.global_position)
	if clicked_box == null:
		return

	_handle_hover_box_click(clicked_box, mouse_event.shift_pressed)
	get_viewport().set_input_as_handled()


func _handle_debug_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode != KEY_H:
		return
	if not _debug_mode_enabled():
		return
	if event.ctrl_pressed and event.shift_pressed:
		_toggle_squint_eyes()
	elif event.shift_pressed and not event.ctrl_pressed:
		_swap_head_texture()
	elif not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
		_toggle_hand_grip()
	else:
		return
	get_viewport().set_input_as_handled()


func _toggle_hand_grip() -> void:
	_hand_grip_overgrip = not _hand_grip_overgrip
	_apply_visibility_state()


## Swaps the head between the two head styles (head and head_2).
func _swap_head_texture() -> void:
	if HEAD_STATIC_OPTIONS.is_empty():
		return
	_head_texture_index = (_head_texture_index + 1) % HEAD_STATIC_OPTIONS.size()
	_apply_visibility_state()


## Shows or hides the squint-eyes overlay on the head.
func _toggle_squint_eyes() -> void:
	_squint_eyes_enabled = not _squint_eyes_enabled
	_apply_visibility_state()


func _debug_mode_enabled() -> bool:
	var state := get_node_or_null("/root/GameState")
	return state != null and bool(state.get("debug_mode_enabled"))


## Hides whichever hand grip is not currently selected so the two
## overlapping grip columns never render at once.
func _apply_hand_grip_selection(resolved: Dictionary) -> void:
	var hidden_paths := UNDERGRIP_HAND_PATHS if _hand_grip_overgrip else OVERGRIP_HAND_PATHS
	for path in hidden_paths:
		resolved[path] = false


func prime_head_animation() -> bool:
	var box := _find_animation_hover_box()
	if box == null or _animation_states.has(box):
		return false
	_finish_layered_animation(false)
	_prime_layered_animation(box)
	return true


func play_head_animation() -> bool:
	var box := _find_animation_hover_box()
	if box == null:
		return false
	if not _animation_states.has(box):
		_finish_layered_animation(false)
		_prime_layered_animation(box)
	var state: Dictionary = _animation_states[box]
	if bool(state.get("playing", false)):
		return false
	state["elapsed"] = 0.0
	state["playing"] = true
	_play_hand_rub_sound()
	return true


func toggle_pelvis_pose() -> void:
	var box := _find_hover_box_by_name("PelvisHoverBox")
	if box == null:
		box = _find_toggle_hover_box()
	if box != null:
		if not _is_hover_box_available(box):
			return
		_toggle_box_effect(box)


## Hides or restores the player's hand on the given side while a screw on that
## side is being driven. The player pulls that hand off the robot to hold the
## screwdriver, so the gripping hand disappears for the length of the
## screwdriver animation. Only has a visible effect while the pelvis animation
## is showing those hands; otherwise it is a harmless no-op.
func set_repair_hand_hidden(side: String, hidden: bool) -> void:
	var key := side.to_lower()
	if key != "left" and key != "right":
		return
	if bool(_repair_hidden_hand_sides.get(key, false)) == hidden:
		return
	if hidden:
		_repair_hidden_hand_sides[key] = true
	else:
		_repair_hidden_hand_sides.erase(key)
	if not Engine.is_editor_hint():
		_apply_visibility_state()


## Enables the "slightly out" leg pre-stage (Sleep scene). While enabled, the
## first click on the leg parts it into the slightly-out pose and only the next
## click lifts it; the stress test keeps this off so the leg lifts immediately.
func set_leg_slight_out_prestage_enabled(value: bool) -> void:
	if _leg_slight_out_prestage_enabled == value:
		return
	_leg_slight_out_prestage_enabled = value
	if not value and _leg_prestage_active:
		_leg_prestage_active = false
		if not Engine.is_editor_hint():
			_apply_visibility_state()


func set_head_interaction_enabled(value: bool) -> void:
	_interaction_enabled = value
	for box in _hover_boxes:
		if box != null and is_instance_valid(box):
			var visible_value := value and _is_hover_box_available(box)
			box.visible = visible_value and _does_hover_box_show_border(box)
			if not visible_value and box.has_method("set_hovered"):
				box.call("set_hovered", false)


func set_interaction_enabled(value: bool) -> void:
	set_head_interaction_enabled(value)


func reset_interactions_to_default() -> void:
	_animation_states.clear()
	_leg_prestage_active = false
	_left_leg_pose = LEG_POSE_DEFAULT
	_right_leg_pose = LEG_POSE_DEFAULT
	_left_hand_texture_index = 0
	_right_hand_texture_index = 0
	_hair_texture_index = HAIR_DEFAULT_INDEX
	_head_texture_index = HEAD_DEFAULT_INDEX
	_squint_eyes_enabled = SQUINT_DEFAULT_ENABLED
	_repair_hidden_hand_sides.clear()
	for box in _hover_boxes:
		if box == null or not is_instance_valid(box):
			continue
		if box.has_method("set_runtime_active"):
			box.call("set_runtime_active", bool(box.get("active_by_default")))
		if box.has_method("set_hovered"):
			box.call("set_hovered", false)
	_apply_visibility_state()
	_update_hover_boxes()


func is_in_default_pose() -> bool:
	if not _animation_states.is_empty():
		return false
	if _leg_prestage_active:
		return false
	if _left_leg_pose != LEG_POSE_DEFAULT or _right_leg_pose != LEG_POSE_DEFAULT:
		return false
	if _left_hand_texture_index != 0 or _right_hand_texture_index != 0:
		return false
	if _hair_texture_index != HAIR_DEFAULT_INDEX:
		return false
	if _head_texture_index != HEAD_DEFAULT_INDEX:
		return false
	if _squint_eyes_enabled != SQUINT_DEFAULT_ENABLED:
		return false
	for box in _hover_boxes:
		if box == null or not is_instance_valid(box):
			continue
		if _is_box_effect_active(box) != bool(box.get("active_by_default")):
			return false
	return true


func hovered_hover_box_description() -> String:
	var box := _find_hover_box_at(get_global_mouse_position())
	if box == null:
		return ""
	if String(box.name) == "HeadHoverBox":
		var head_state: Dictionary = _animation_states.get(box, {})
		if head_state.is_empty():
			return "Raise Head"
		if String(head_state.get("phase", "")) == ANIMATION_PHASE_INTRO and not bool(head_state.get("playing", false)):
			return "Animate Head"
		return "Lower Head"
	if String(box.name) == "PelvisHoverBox":
		if _box_has_layered_animation(box):
			var pelvis_state: Dictionary = _animation_states.get(box, {})
			if pelvis_state.is_empty():
				# In the stress test the legs are raised individually beforehand,
				# so the pelvis only begins the animation; the Sleep pre-stage
				# still raises the legs itself.
				return "Raise Legs" if _leg_slight_out_prestage_enabled else "Animate Legs"
			if String(pelvis_state.get("phase", "")) == ANIMATION_PHASE_INTRO and not bool(pelvis_state.get("playing", false)):
				return "Animate Legs"
			return "Lower Legs"
		return "Lower Legs" if _is_box_effect_active(box) else "Raise Legs"
	if String(box.name) == "ChestCoverHoverBox":
		return "Remove Chest Cover" if _is_chest_cover_visible() else "Equip Chest Cover"
	if _is_shoulder_hover_box(box):
		return "Equip Shoulder Pad" if _is_box_effect_active(box) else "Remove Shoulder Pad"
	if _is_leg_pose_hover_box(box):
		match _leg_pose_for_box(box):
			LEG_POSE_DEFAULT:
				return "Spread Leg"
			LEG_POSE_SLIGHTLY_OUT:
				return "Raise Leg"
			_:
				return "Lower Leg"
	if _is_hand_hover_box(box):
		return "Switch Hand"
	if _is_hair_hover_box(box):
		return "Switch Hairstyle"
	return String(box.get("hover_description"))


func _on_resized() -> void:
	_sync_animation_layers_to_robot_size()


func _connect_robot_part_state() -> void:
	if Engine.is_editor_hint():
		return
	var state := get_node_or_null("/root/GameState")
	if state == null or not state.has_signal("robot_parts_changed"):
		return
	var changed_callable := Callable(self, "_on_robot_parts_changed")
	if not state.is_connected("robot_parts_changed", changed_callable):
		state.connect("robot_parts_changed", changed_callable)
	if state.has_signal("cosmetic_items_changed") \
			and not state.is_connected("cosmetic_items_changed", changed_callable):
		state.connect("cosmetic_items_changed", changed_callable)


func _on_robot_parts_changed(_parts: Dictionary) -> void:
	_update_hover_boxes()
	_apply_visibility_state()


func _sync_animation_layers_to_robot_size() -> void:
	if not sync_animation_layer_scale:
		return
	var layers := _get_animation_layers()
	if layers == null:
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return
	layers.scale = Vector2(
		size.x / float(DEFAULT_FRAME_SIZE.x),
		size.y / float(DEFAULT_FRAME_SIZE.y)
	)


func _request_configuration_refresh() -> void:
	if not is_inside_tree():
		return
	call_deferred("_refresh_configuration")


func _refresh_configuration() -> void:
	_collect_hover_boxes()
	_rebuild_visibility_cache()
	if not Engine.is_editor_hint():
		_apply_visibility_state()


func _collect_hover_boxes() -> void:
	_hover_boxes.clear()
	var changed_callable := Callable(self, "_on_hover_box_configuration_changed")
	for path in hover_box_paths:
		var box := get_node_or_null(path) as Control
		if box == null:
			push_warning("Hover box not found: %s" % path)
			continue
		_hover_boxes.append(box)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.z_index = HOVER_BOX_OVERLAY_Z_INDEX
		box.z_as_relative = false
		if box.has_signal("configuration_changed") \
				and not box.is_connected("configuration_changed", changed_callable):
			box.connect("configuration_changed", changed_callable)


func _on_hover_box_configuration_changed() -> void:
	_rebuild_visibility_cache()
	if Engine.is_editor_hint():
		if _any_editor_preview_active():
			_apply_visibility_state(true)
	else:
		_apply_visibility_state()
	_update_hover_boxes()


func _rebuild_visibility_cache() -> void:
	_managed_paths.clear()
	_base_visibility.clear()
	_add_managed_paths(always_hidden_image_paths)
	_add_robot_part_managed_paths()
	_add_managed_path(NECK_FRONT_PATH)
	_add_managed_path(animation_layers_path)
	for box in _hover_boxes:
		if box == null or not is_instance_valid(box):
			continue
		if box.has_method("get_all_managed_paths"):
			_add_managed_paths(box.call("get_all_managed_paths"))

	for path in _managed_paths:
		var node := get_node_or_null(path) as CanvasItem
		if node == null:
			push_warning("Managed image node not found: %s" % path)
			continue
		_base_visibility[path] = node.visible


func _add_managed_paths(paths: Array) -> void:
	for path in paths:
		_add_managed_path(NodePath(String(path)))


func _add_managed_path(path: NodePath) -> void:
	if path == NodePath(""):
		return
	if not _managed_paths.has(path):
		_managed_paths.append(path)


func _update_editor_preview() -> void:
	_collect_hover_boxes()
	var preview_active := _any_editor_preview_active()
	if preview_active:
		if not _editor_preview_was_active:
			_rebuild_visibility_cache()
		_editor_preview_was_active = true
		_apply_visibility_state(true)
		return

	if _editor_preview_was_active:
		_restore_base_visibility()
		_editor_preview_was_active = false

	_rebuild_visibility_cache()


func _any_editor_preview_active() -> bool:
	for box in _hover_boxes:
		if box != null and is_instance_valid(box) and bool(box.get("editor_preview_active")):
			return true
	return false


func _update_hover_boxes() -> void:
	for box in _hover_boxes:
		if box == null or not is_instance_valid(box):
			continue
		var box_available := _is_hover_box_available(box)
		if not _interaction_enabled or not box_available:
			box.visible = false
			if box.has_method("set_hovered"):
				box.call("set_hovered", false)
			continue
		box.visible = _does_hover_box_show_border(box)
		var force_box_visible := bool(box.get("force_visible"))
		var hovered := force_box_visible or box.get_global_rect().has_point(get_global_mouse_position())
		if box.has_method("set_hovered"):
			box.call("set_hovered", hovered)


func _find_clicked_hover_box(global_position: Vector2) -> Control:
	return _find_hover_box_at(global_position)


func _find_hover_box_at(global_position: Vector2) -> Control:
	if not _interaction_enabled:
		return null
	var boxes := _hover_boxes.duplicate()
	boxes.sort_custom(func(a: Control, b: Control) -> bool:
		return _get_box_priority(a) > _get_box_priority(b)
	)
	for box in boxes:
		if box == null or not is_instance_valid(box):
			continue
		if not _is_hover_box_available(box):
			continue
		if not box.is_inside_tree():
			continue
		if box.get_global_rect().has_point(global_position):
			return box
	return null


func _handle_hover_box_click(box: Control, shift_pressed: bool = false) -> void:
	var action := int(box.get("click_action"))
	if action == CLICK_ACTION_PRIME_THEN_PLAY_ANIMATION:
		_handle_layered_animation_click(box, shift_pressed)
		return
	if _is_hand_hover_box(box):
		_cycle_hand_texture(box)
		return
	if _is_hair_hover_box(box):
		_cycle_hair_texture()
		return
	if _is_leg_pose_hover_box(box):
		_cycle_leg_pose(box)
		return
	_toggle_box_effect(box)


func _is_leg_pose_hover_box(box: Control) -> bool:
	if box == null:
		return false
	var box_name := String(box.name)
	return box_name == LEFT_LEG_HOVER_BOX_NAME or box_name == RIGHT_LEG_HOVER_BOX_NAME


## Advances the clicked leg one step through its pose cycle
## (standing -> slightly-out -> raised -> standing). The box's runtime-active
## flag mirrors "moved from standing" so the screw controllers still treat a
## moved leg as busy, exactly like the pelvis animation.
func _cycle_leg_pose(box: Control) -> void:
	var pose := _next_leg_pose(_leg_pose_for_box(box))
	_set_leg_pose_for_box(box, pose)
	if box.has_method("set_runtime_active"):
		box.call("set_runtime_active", pose != LEG_POSE_DEFAULT)
	_play_wood_creak_sound()
	_apply_visibility_state()


func _next_leg_pose(pose: int) -> int:
	return (pose + 1) % LEG_POSE_COUNT


func _leg_pose_for_box(box: Control) -> int:
	if box != null and String(box.name) == LEFT_LEG_HOVER_BOX_NAME:
		return _left_leg_pose
	return _right_leg_pose


func _set_leg_pose_for_box(box: Control, pose: int) -> void:
	if box != null and String(box.name) == LEFT_LEG_HOVER_BOX_NAME:
		_left_leg_pose = pose
	else:
		_right_leg_pose = pose


func _both_legs_raised() -> bool:
	return _left_leg_pose == LEG_POSE_RAISED and _right_leg_pose == LEG_POSE_RAISED


func _is_hair_hover_box(box: Control) -> bool:
	return box != null and String(box.name) == HAIR_HOVER_BOX_NAME


## Advances to the next hair-front style, wrapping around. The selection drives
## both the static head and the matching head-animation column.
func _cycle_hair_texture() -> void:
	if HAIR_STATIC_OPTIONS.is_empty():
		return
	_hair_texture_index = (_hair_texture_index + 1) % HAIR_STATIC_OPTIONS.size()
	_apply_visibility_state()


func _is_hand_hover_box(box: Control) -> bool:
	if box == null:
		return false
	var box_name := String(box.name)
	return box_name == LEFT_HAND_HOVER_BOX_NAME or box_name == RIGHT_HAND_HOVER_BOX_NAME


## Advances the clicked hand to the next pose option, wrapping around.
func _cycle_hand_texture(box: Control) -> void:
	if String(box.name) == LEFT_HAND_HOVER_BOX_NAME and not LEFT_HAND_TEXTURE_OPTIONS.is_empty():
		_left_hand_texture_index = (_left_hand_texture_index + 1) % LEFT_HAND_TEXTURE_OPTIONS.size()
	elif String(box.name) == RIGHT_HAND_HOVER_BOX_NAME and not RIGHT_HAND_TEXTURE_OPTIONS.is_empty():
		_right_hand_texture_index = (_right_hand_texture_index + 1) % RIGHT_HAND_TEXTURE_OPTIONS.size()
	_apply_visibility_state()


func _is_shoulder_hover_box(box: Control) -> bool:
	return box != null and SHOULDER_HOVER_BOX_NAMES.has(String(box.name))


func _toggle_box_effect(box: Control) -> void:
	if box.has_method("toggle_runtime_active"):
		box.call("toggle_runtime_active")
	_apply_visibility_state()


func _handle_layered_animation_click(box: Control, shift_pressed: bool = false) -> void:
	if not _box_has_layered_animation(box):
		_toggle_box_effect(box)
		return

	if _leg_slight_out_prestage_enabled and _is_leg_prestage_box(box) \
			and not _animation_states.has(box):
		if not _leg_prestage_active:
			_enter_leg_prestage()
			return
		# Second click: leave the slightly-out pose and lift the leg as usual.
		_leg_prestage_active = false

	if not _animation_states.has(box):
		# Only one layered animation may run at a time, except in debug mode
		# where shift-clicking lets the head and pelvis animations coexist.
		if not (shift_pressed and _debug_mode_enabled()):
			_finish_layered_animation(false)
		_prime_layered_animation(box)
		return

	var state: Dictionary = _animation_states[box]
	var playing := bool(state.get("playing", false))
	if String(state.get("phase", "")) == ANIMATION_PHASE_LOOP and playing:
		_finish_animation_for_box(box)
		return

	if playing:
		return

	state["elapsed"] = 0.0
	state["playing"] = true
	_play_hand_rub_sound()
	_apply_visibility_state()


func _is_leg_prestage_box(box: Control) -> bool:
	return box != null and String(box.name) == LEG_PRESTAGE_BOX_NAME


## Parts the legs into the slightly-out pose without lifting them, as the first
## step of the Sleep-scene leg interaction.
func _enter_leg_prestage() -> void:
	_finish_layered_animation(false)
	_leg_prestage_active = true
	_play_wood_creak_sound()
	_apply_visibility_state()


func _prime_layered_animation(box: Control) -> void:
	_leg_prestage_active = false
	_animation_states[box] = {
		"phase": ANIMATION_PHASE_INTRO,
		"playing": false,
		"elapsed": 0.0,
	}
	if box.has_method("set_runtime_active"):
		box.call("set_runtime_active", true)
	_set_animation_frame_for_box(box, ANIMATION_PHASE_INTRO, 0)
	_refresh_active_animation_frames()
	_play_wood_creak_sound()
	_apply_visibility_state()


func _advance_animations(delta: float) -> void:
	for box in _animation_states.keys():
		if box == null or not is_instance_valid(box):
			_animation_states.erase(box)
			_apply_visibility_state()
			continue
		_advance_animation_for_box(box, delta)


func _advance_animation_for_box(box: Control, delta: float) -> void:
	var state: Dictionary = _animation_states[box]
	if not bool(state.get("playing", false)):
		return

	var phase := String(state.get("phase", ANIMATION_PHASE_INTRO))
	var fps := maxf(0.1, float(box.get("animation_fps")))
	state["elapsed"] = float(state.get("elapsed", 0.0)) + delta
	var frame := int(floor(float(state["elapsed"]) * fps))
	var frame_count := _get_phase_frame_count(box, phase)

	if frame >= frame_count:
		if phase == ANIMATION_PHASE_INTRO \
				and bool(box.get("loop_after_intro")) \
				and not _get_animation_phase_paths(box, ANIMATION_PHASE_LOOP).is_empty():
			state["phase"] = ANIMATION_PHASE_LOOP
			state["elapsed"] = 0.0
			_set_animation_frame_for_box(box, ANIMATION_PHASE_LOOP, 0)
			_apply_visibility_state()
			return

		if phase == ANIMATION_PHASE_LOOP:
			state["elapsed"] = 0.0
			_set_animation_frame_for_box(box, phase, 0)
			_apply_visibility_state()
			return

		_finish_animation_for_box(box)
		return

	_set_animation_frame_for_box(box, phase, frame)


## Ends the layered animation on one hover box, leaving any other running
## animation (debug dual mode) untouched.
func _finish_animation_for_box(box: Control, apply_state: bool = true) -> void:
	_leg_prestage_active = false
	_animation_states.erase(box)
	if box != null and is_instance_valid(box) and box.has_method("set_runtime_active"):
		box.call("set_runtime_active", false)
	if apply_state:
		_refresh_active_animation_frames()
		_apply_visibility_state()


## Ends every running layered animation.
func _finish_layered_animation(apply_state: bool = true) -> void:
	_leg_prestage_active = false
	for box in _animation_states.keys():
		if box != null and is_instance_valid(box) and box.has_method("set_runtime_active"):
			box.call("set_runtime_active", false)
	_animation_states.clear()
	if apply_state:
		_apply_visibility_state()


func _apply_visibility_state(force_editor: bool = false) -> void:
	if Engine.is_editor_hint() and not force_editor:
		return
	if _base_visibility.is_empty():
		_rebuild_visibility_cache()

	var resolved := _base_visibility.duplicate()
	var boxes := _hover_boxes.duplicate()
	boxes.sort_custom(func(a: Control, b: Control) -> bool:
		return _get_box_priority(a) < _get_box_priority(b)
	)

	for box in boxes:
		if box == null or not is_instance_valid(box):
			continue
		if not _is_box_effect_active(box):
			continue
		_apply_box_visibility_to_dictionary(box, resolved)
		_apply_box_animation_visibility_to_dictionary(box, resolved)

	_apply_hand_grip_selection(resolved)
	_apply_animation_parent_visibility(resolved)
	_apply_always_hidden_to_dictionary(resolved)
	_apply_leg_prestage_visibility(resolved)
	_apply_leg_pose_selection(resolved)
	_apply_hand_texture_selection(resolved)
	_apply_hair_texture_selection(resolved)
	_apply_head_texture_selection(resolved)
	_apply_squint_eyes_state(resolved)
	_apply_robot_part_availability_to_dictionary(resolved)
	_apply_cosmetic_item_availability_to_dictionary(resolved)
	_apply_chest_cover_gated_animations(resolved)
	_apply_repair_hidden_hands_to_dictionary(resolved)
	_apply_shoulder_pad_state(resolved)
	_apply_neck_front_state(resolved)
	_apply_resolved_visibility(resolved)
	_apply_squint_eyes_offset()


func _restore_base_visibility() -> void:
	for path in _base_visibility:
		_set_canvas_item_visible(NodePath(String(path)), bool(_base_visibility[path]))
	_enforce_always_hidden_paths()


func _apply_box_visibility_to_dictionary(box: Control, resolved: Dictionary) -> void:
	for path in box.get("hidden_while_active_image_paths"):
		resolved[NodePath(String(path))] = false
	for path in box.get("shown_while_active_image_paths"):
		resolved[NodePath(String(path))] = true


func _apply_box_animation_visibility_to_dictionary(box: Control, resolved: Dictionary) -> void:
	if not _box_has_layered_animation(box):
		return

	for path in _get_box_animation_paths(box):
		resolved[NodePath(String(path))] = false

	var phase := _get_visible_animation_phase_for_box(box)
	if phase == ANIMATION_PHASE_NONE:
		return

	if Engine.is_editor_hint():
		_set_animation_frame_for_box(box, phase, 0)
	for path in _get_animation_phase_paths(box, phase):
		resolved[NodePath(String(path))] = true


func _apply_animation_parent_visibility(resolved: Dictionary) -> void:
	if animation_layers_path == NodePath(""):
		return
	for box in _hover_boxes:
		if box == null or not is_instance_valid(box):
			continue
		for path in _get_box_animation_paths(box):
			if bool(resolved.get(NodePath(String(path)), false)):
				resolved[animation_layers_path] = true
				return


func _apply_always_hidden_to_dictionary(resolved: Dictionary) -> void:
	for path in always_hidden_image_paths:
		resolved[path] = false


## Shows the slightly-out legs in place of the standing legs while the Sleep
## leg pre-stage is active. Runs before the part-availability pass so a removed
## leg still hides its slightly-out variant.
func _apply_leg_prestage_visibility(resolved: Dictionary) -> void:
	if not _leg_prestage_active:
		return
	for path in LEG_PRESTAGE_HIDDEN_PATHS:
		resolved[path] = false
	for path in LEG_PRESTAGE_SHOWN_PATHS:
		resolved[path] = true


## Resolves the static legs to their current per-side pose. The pelvis animation
## and the Sleep pre-stage both own the legs while active, so this defers to them
## and only drives the static legs when neither is running. Runs before the
## part-availability pass so a removed leg still hides every pose sprite.
func _apply_leg_pose_selection(resolved: Dictionary) -> void:
	# In the editor the leg boxes' own preview paths drive the slightly-out pose;
	# the runtime pose cycle only exists in game.
	if Engine.is_editor_hint():
		return
	if _leg_prestage_active:
		return
	if _is_named_box_effect_active("PelvisHoverBox"):
		return
	_apply_single_leg_pose(
		resolved,
		_left_leg_pose,
		LEFT_LEG_POSE_DEFAULT_PATHS,
		LEFT_LEG_POSE_SLIGHTLY_OUT_PATHS,
		LEFT_LEG_POSE_RAISED_PATHS
	)
	_apply_single_leg_pose(
		resolved,
		_right_leg_pose,
		RIGHT_LEG_POSE_DEFAULT_PATHS,
		RIGHT_LEG_POSE_SLIGHTLY_OUT_PATHS,
		RIGHT_LEG_POSE_RAISED_PATHS
	)


func _apply_single_leg_pose(
	resolved: Dictionary,
	pose: int,
	default_paths: Array[NodePath],
	slightly_out_paths: Array[NodePath],
	raised_paths: Array[NodePath]
) -> void:
	_set_paths_visible(resolved, default_paths, pose == LEG_POSE_DEFAULT)
	_set_paths_visible(resolved, slightly_out_paths, pose == LEG_POSE_SLIGHTLY_OUT)
	_set_paths_visible(resolved, raised_paths, pose == LEG_POSE_RAISED)


func _set_paths_visible(resolved: Dictionary, paths: Array[NodePath], value: bool) -> void:
	for path in paths:
		resolved[path] = value


## Keeps the cosmetic vegetable columns of the raised-leg animation from playing
## while the chest cover is still equipped (visible). The cover conceals the
## chest, so the coconuts/pepperonis painted onto the animation must stay hidden.
func _apply_chest_cover_gated_animations(resolved: Dictionary) -> void:
	if not bool(resolved.get(CHEST_COVER_PATH, false)):
		return
	_hide_paths(resolved, CHEST_COVER_GATED_ANIM_PATHS)


## Shows the selected pose per hand and hides the other options. Runs before the
## part-availability pass so a removed hand still hides every option.
func _apply_hand_texture_selection(resolved: Dictionary) -> void:
	_apply_single_hand_texture_selection(resolved, LEFT_HAND_TEXTURE_OPTIONS, _left_hand_texture_index)
	_apply_single_hand_texture_selection(resolved, RIGHT_HAND_TEXTURE_OPTIONS, _right_hand_texture_index)


func _apply_single_hand_texture_selection(resolved: Dictionary, options: Array[NodePath], index: int) -> void:
	if options.is_empty():
		return
	var selected := index % options.size()
	for i in range(options.size()):
		resolved[options[i]] = (i == selected)


## Shows the selected hair-front style and hides the others. The static head hair
## is only shown while the head is lowered (the head animation supplies its own
## hair strip); the animation hair columns keep only the selected style visible.
func _apply_hair_texture_selection(resolved: Dictionary) -> void:
	if HAIR_STATIC_OPTIONS.is_empty():
		return
	var selected := _hair_texture_index % HAIR_STATIC_OPTIONS.size()
	var head_active := _is_named_box_effect_active("HeadHoverBox")
	for i in range(HAIR_STATIC_OPTIONS.size()):
		resolved[HAIR_STATIC_OPTIONS[i]] = (not head_active) and (i == selected)
		if i == selected:
			continue
		if i < HAIR_INTRO_ANIM_OPTIONS.size():
			resolved[HAIR_INTRO_ANIM_OPTIONS[i]] = false
		if i < HAIR_LOOP_ANIM_OPTIONS.size():
			resolved[HAIR_LOOP_ANIM_OPTIONS[i]] = false


## Shows the selected head style and hides the other. Like the hair, the static
## head styles are only shown while the head is lowered; during the animation the
## matching head column stays visible and the other is hidden.
func _apply_head_texture_selection(resolved: Dictionary) -> void:
	if HEAD_STATIC_OPTIONS.is_empty():
		return
	var selected := _head_texture_index % HEAD_STATIC_OPTIONS.size()
	var head_active := _is_named_box_effect_active("HeadHoverBox")
	for i in range(HEAD_STATIC_OPTIONS.size()):
		resolved[HEAD_STATIC_OPTIONS[i]] = (not head_active) and (i == selected)
		if i == selected:
			continue
		if i < HEAD_INTRO_ANIM_OPTIONS.size():
			resolved[HEAD_INTRO_ANIM_OPTIONS[i]] = false
		if i < HEAD_LOOP_ANIM_OPTIONS.size():
			resolved[HEAD_LOOP_ANIM_OPTIONS[i]] = false


## Resolves the squint-eyes overlay. It is shown on the static head only while
## enabled and the head is lowered; while it is toggled off the static and
## animation squint eyes are hidden everywhere.
func _apply_squint_eyes_state(resolved: Dictionary) -> void:
	var head_active := _is_named_box_effect_active("HeadHoverBox")
	resolved[SQUINT_STATIC_PATH] = _squint_eyes_enabled and not head_active
	if not _squint_eyes_enabled:
		_hide_paths(resolved, SQUINT_ANIM_PATHS)


## Nudges the static squint eyes down one pixel while the head_2 style is shown
## in the default (lowered) pose, so they line up with that head's eye sockets.
func _apply_squint_eyes_offset() -> void:
	var node := get_node_or_null(SQUINT_STATIC_PATH) as Control
	if node == null:
		return
	var lowered := _squint_eyes_enabled \
			and _head_texture_index == HEAD_HEAD2_INDEX \
			and not _is_named_box_effect_active("HeadHoverBox")
	var offset := SQUINT_HEAD2_LOWER_PX if lowered else 0.0
	node.offset_top = offset
	node.offset_bottom = offset


func _apply_robot_part_availability_to_dictionary(resolved: Dictionary) -> void:
	_apply_paths_available(resolved, CHEST_PART_PATHS, _robot_part_count("chest") >= 1)
	_apply_paths_available(resolved, STOMACH_PART_PATHS, _robot_part_count("stomach") >= 1)

	var arm_count := _robot_part_count("arm")
	_apply_paths_available(resolved, LEFT_ARM_PART_PATHS, arm_count >= 1)
	_apply_paths_available(resolved, RIGHT_ARM_PART_PATHS, arm_count >= 2)

	var hand_count := _robot_part_count("hand")
	_apply_paths_available(resolved, LEFT_HAND_PART_PATHS, hand_count >= 1)
	_apply_paths_available(resolved, RIGHT_HAND_PART_PATHS, hand_count >= 2)

	var leg_count := _robot_part_count("leg")
	_apply_paths_available(resolved, LEFT_LEG_PART_PATHS, leg_count >= 1)
	_apply_paths_available(resolved, RIGHT_LEG_PART_PATHS, leg_count >= 2)


## Hides each cosmetic chest overlay whose GameState item the player does not
## own. Runs after the chest-part pass, so an unowned item hides even when a
## chest is present, and a removed chest still hides everything above.
func _apply_cosmetic_item_availability_to_dictionary(resolved: Dictionary) -> void:
	_apply_paths_available(resolved, BIG_COCONUTS_ITEM_PATHS, _cosmetic_item_owned("big_coconuts"))
	_apply_paths_available(resolved, SMALL_COCONUTS_ITEM_PATHS, _cosmetic_item_owned("small_coconuts"))
	_apply_paths_available(resolved, CHEST_COVER_ITEM_PATHS, _cosmetic_item_owned("chest_cover"))


func _cosmetic_item_owned(id: String) -> bool:
	var state := get_node_or_null("/root/GameState")
	if state != null and state.has_method("has_cosmetic_item"):
		return bool(state.call("has_cosmetic_item", id))
	# Editor / no GameState: mirror the shipped defaults so the scene preview
	# matches a fresh game (big coconuts + chest cover on, small coconuts off).
	return id != "small_coconuts"


func _apply_repair_hidden_hands_to_dictionary(resolved: Dictionary) -> void:
	if bool(_repair_hidden_hand_sides.get("left", false)):
		_apply_paths_available(resolved, LEFT_GRIP_HAND_PATHS, false)
	if bool(_repair_hidden_hand_sides.get("right", false)):
		_apply_paths_available(resolved, RIGHT_GRIP_HAND_PATHS, false)


## Resolves the two independent shoulder-pad toggles. For each side: while the
## pad is on, that side's chest outline shows and its chest details stay hidden;
## while the pad is removed, the pad is hidden and the details replace the
## outline. The static overlays follow the static chest, and the matching
## animation columns follow the head animation the same way.
func _apply_shoulder_pad_state(resolved: Dictionary) -> void:
	_apply_side_shoulder_pad_state(
		resolved,
		_is_named_box_effect_active(LEFT_SHOULDER_HOVER_BOX_NAME),
		LEFT_SHOULDER_PAD_PATH,
		CHEST_OUTLINE_LEFT_PATH,
		CHEST_DETAILS_LEFT_PATH,
		ANIM_LEFT_SHOULDER_PAD_PATHS,
		ANIM_CHEST_OUTLINE_LEFT_PATHS,
		ANIM_CHEST_DETAILS_LEFT_PATHS
	)
	_apply_side_shoulder_pad_state(
		resolved,
		_is_named_box_effect_active(RIGHT_SHOULDER_HOVER_BOX_NAME),
		RIGHT_SHOULDER_PAD_PATH,
		CHEST_OUTLINE_RIGHT_PATH,
		CHEST_DETAILS_RIGHT_PATH,
		ANIM_RIGHT_SHOULDER_PAD_PATHS,
		ANIM_CHEST_OUTLINE_RIGHT_PATHS,
		ANIM_CHEST_DETAILS_RIGHT_PATHS
	)


func _apply_side_shoulder_pad_state(
	resolved: Dictionary,
	pad_removed: bool,
	pad_path: NodePath,
	outline_path: NodePath,
	details_path: NodePath,
	anim_pad_paths: Array[NodePath],
	anim_outline_paths: Array[NodePath],
	anim_details_paths: Array[NodePath]
) -> void:
	var chest_visible := bool(resolved.get(CHEST_PATH, false))
	resolved[outline_path] = chest_visible and not pad_removed
	resolved[details_path] = chest_visible and pad_removed
	if pad_removed:
		resolved[pad_path] = false
		_hide_paths(resolved, anim_pad_paths)
		_hide_paths(resolved, anim_outline_paths)
	else:
		_hide_paths(resolved, anim_details_paths)


func _hide_paths(resolved: Dictionary, paths: Array[NodePath]) -> void:
	for path in paths:
		resolved[path] = false


func _apply_paths_available(resolved: Dictionary, paths: Array[NodePath], available: bool) -> void:
	if available:
		return
	for path in paths:
		resolved[path] = false


## Shows the neck's front cover while the head is the robot's only remaining
## part; any other equipped part (or the raised-head animation) hides it.
func _apply_neck_front_state(resolved: Dictionary) -> void:
	var head_only := _robot_part_count("chest") < 1 \
			and _robot_part_count("stomach") < 1 \
			and _robot_part_count("arm") < 1 \
			and _robot_part_count("hand") < 1 \
			and _robot_part_count("leg") < 1
	resolved[NECK_FRONT_PATH] = head_only \
			and not _is_named_box_effect_active("HeadHoverBox")


## The neck-front texture is loaded at runtime so the scene stays valid while
## the art file has not been created yet.
func _initialize_neck_front_texture() -> void:
	var node := get_node_or_null(NECK_FRONT_PATH) as TextureRect
	if node == null or node.texture != null:
		return
	if ResourceLoader.exists(NECK_FRONT_TEXTURE_PATH, "Texture2D"):
		node.texture = load(NECK_FRONT_TEXTURE_PATH) as Texture2D


func _add_robot_part_managed_paths() -> void:
	_add_managed_paths(CHEST_PART_PATHS)
	_add_managed_paths(STOMACH_PART_PATHS)
	_add_managed_paths(LEFT_ARM_PART_PATHS)
	_add_managed_paths(RIGHT_ARM_PART_PATHS)
	_add_managed_paths(LEFT_HAND_PART_PATHS)
	_add_managed_paths(RIGHT_HAND_PART_PATHS)
	_add_managed_paths(LEFT_LEG_PART_PATHS)
	_add_managed_paths(RIGHT_LEG_PART_PATHS)


func _robot_part_count(id: String) -> int:
	if Engine.is_editor_hint():
		return 2
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return 0
	if state.has_method("get_robot_part_count"):
		return int(state.call("get_robot_part_count", id))
	if id == "leg":
		return int(state.get("equipped_limbs"))
	return 0


func _is_hover_box_available(box: Control) -> bool:
	if box == null or not is_instance_valid(box):
		return false
	if _is_hover_box_blocked_by_repair(box):
		return false
	# Pelvis (leg animation) needs a stomach; the chest cover and shoulder pads
	# sit on the chest, so they need a chest.
	if box.name == "PelvisHoverBox":
		if _robot_part_count("stomach") < 1:
			return false
		# The Sleep pre-stage keeps the old behaviour where the pelvis itself
		# raises the legs; the stress test instead requires both legs to already
		# be raised individually before the pelvis can begin the animation. Once
		# the animation is running the box stays available so it can be advanced
		# or stopped.
		if _leg_slight_out_prestage_enabled or _animation_states.has(box):
			return true
		return _both_legs_raised()
	if box.name == "ChestCoverHoverBox" or _is_shoulder_hover_box(box):
		return _robot_part_count("chest") >= 1
	if box.name == LEFT_HAND_HOVER_BOX_NAME:
		return _robot_part_count("hand") >= 1
	if box.name == RIGHT_HAND_HOVER_BOX_NAME:
		return _robot_part_count("hand") >= 2
	if box.name == LEFT_LEG_HOVER_BOX_NAME:
		return _robot_part_count("leg") >= 1
	if box.name == RIGHT_LEG_HOVER_BOX_NAME:
		return _robot_part_count("leg") >= 2
	return true


func _is_hover_box_blocked_by_repair(box: Control) -> bool:
	for repair in _repair_controllers():
		if repair.has_method("blocks_hover_box") and bool(repair.call("blocks_hover_box", box)):
			return true
	return false


func _repair_controllers() -> Array[Node]:
	var controllers: Array[Node] = []
	_collect_repair_controllers(self, controllers)
	return controllers


func _collect_repair_controllers(node: Node, out: Array[Node]) -> void:
	for child in node.get_children():
		if child.has_method("blocks_hover_box"):
			out.append(child)
		_collect_repair_controllers(child, out)


func _enforce_always_hidden_paths() -> void:
	for path in always_hidden_image_paths:
		_set_canvas_item_visible(path, false)


func _apply_resolved_visibility(resolved: Dictionary) -> void:
	for path in resolved:
		_set_canvas_item_visible(NodePath(String(path)), bool(resolved[path]))
	visual_state_changed.emit()


func _set_canvas_item_visible(path: NodePath, value: bool) -> void:
	var node := get_node_or_null(path) as CanvasItem
	if node == null:
		return
	node.visible = value


## Re-applies each running animation's current frame. Called when the set of
## active animations changes so the chest-split state is re-evaluated for every
## running box (e.g. the pelvis chest drops to its bottom half the moment the
## head animation joins in, even while paused on a frame).
func _refresh_active_animation_frames() -> void:
	for box in _animation_states.keys():
		if box == null or not is_instance_valid(box):
			continue
		var state: Dictionary = _animation_states[box]
		var phase := String(state.get("phase", ANIMATION_PHASE_INTRO))
		var fps := maxf(0.1, float(box.get("animation_fps")))
		var frame_count := _get_phase_frame_count(box, phase)
		var frame := clampi(int(floor(float(state.get("elapsed", 0.0)) * fps)), 0, maxi(0, frame_count - 1))
		_set_animation_frame_for_box(box, phase, frame)


## True while the head and pelvis layered animations are both running and the
## robot has a chest, so their shared chest sprite must be split top/bottom.
func _chest_split_active() -> bool:
	if Engine.is_editor_hint():
		return false
	var head := _find_hover_box_by_name("HeadHoverBox")
	var pelvis := _find_hover_box_by_name("PelvisHoverBox")
	if head == null or pelvis == null:
		return false
	if not (_animation_states.has(head) and _animation_states.has(pelvis)):
		return false
	return _robot_part_count("chest") >= 1


func _set_animation_frame_for_box(box: Control, phase: String, frame: int) -> void:
	var frame_size: Vector2i = box.get("animation_frame_size")
	if frame_size.x <= 0 or frame_size.y <= 0:
		frame_size = DEFAULT_FRAME_SIZE

	var split := _chest_split_active()
	var half_height := int(frame_size.y / 2)
	var paths := _get_animation_phase_paths(box, phase)
	for column in range(paths.size()):
		var path := NodePath(String(paths[column]))
		var node := get_node_or_null(path) as Sprite2D
		if node == null:
			continue
		var rx := float(column * frame_size.x)
		var ry := float(frame * frame_size.y)
		var rw := float(frame_size.x)
		var rh := float(frame_size.y)
		var offset_y := 0.0
		# While the head and pelvis animations run together the chest cell is
		# split down the middle: the head keeps the top half, the pelvis draws
		# its bottom half shifted down so the two halves meet in the middle.
		if split:
			if HEAD_CHEST_ANIM_PATHS.has(path):
				rh = float(half_height)
			elif PELVIS_CHEST_ANIM_PATHS.has(path):
				ry += float(half_height)
				rh = float(half_height)
				offset_y = float(half_height)
		node.region_rect = Rect2(rx, ry, rw, rh)
		node.offset = Vector2(node.offset.x, offset_y)
	visual_state_changed.emit()


func _get_animation_phase_paths(box: Control, phase: String) -> Array:
	if box.has_method("get_animation_phase_paths"):
		return box.call("get_animation_phase_paths", phase)
	if phase == ANIMATION_PHASE_LOOP:
		return box.get("loop_animation_nodes")
	return box.get("intro_animation_nodes")


func _get_box_animation_paths(box: Control) -> Array[NodePath]:
	var merged: Array[NodePath] = []
	_merge_paths(merged, box.get("intro_animation_nodes"))
	_merge_paths(merged, box.get("loop_animation_nodes"))
	return merged


func _merge_paths(target: Array[NodePath], paths: Array) -> void:
	for path in paths:
		var node_path := NodePath(String(path))
		if not target.has(node_path):
			target.append(node_path)


func _get_visible_animation_phase_for_box(box: Control) -> String:
	if Engine.is_editor_hint():
		if bool(box.get("editor_preview_loop_animation")) \
				and not _get_animation_phase_paths(box, ANIMATION_PHASE_LOOP).is_empty():
			return ANIMATION_PHASE_LOOP
		if not _get_animation_phase_paths(box, ANIMATION_PHASE_INTRO).is_empty():
			return ANIMATION_PHASE_INTRO
		return ANIMATION_PHASE_NONE

	var state: Dictionary = _animation_states.get(box, {})
	if state.is_empty():
		return ANIMATION_PHASE_NONE
	return String(state.get("phase", ANIMATION_PHASE_NONE))


func _get_phase_frame_count(box: Control, phase: String) -> int:
	if phase == ANIMATION_PHASE_LOOP:
		return maxi(1, int(box.get("loop_frame_count")))
	return maxi(1, int(box.get("intro_frame_count")))


func _box_has_layered_animation(box: Control) -> bool:
	if box == null or not is_instance_valid(box):
		return false
	if box.has_method("has_layered_animation"):
		return bool(box.call("has_layered_animation"))
	return not _get_box_animation_paths(box).is_empty()


func _is_box_effect_active(box: Control) -> bool:
	if box.has_method("is_effect_active"):
		return bool(box.call("is_effect_active"))
	return false


func _does_hover_box_show_border(box: Control) -> bool:
	return bool(box.get("show_border"))


func _is_named_box_effect_active(box_name: String) -> bool:
	var box := _find_hover_box_by_name(box_name)
	return box != null and _is_box_effect_active(box)


func _is_chest_cover_visible() -> bool:
	var cover := get_node_or_null(^"ChestCover") as CanvasItem
	return cover != null and cover.visible


func _get_box_priority(box: Control) -> int:
	return int(box.get("priority"))


func _find_animation_hover_box() -> Control:
	for box in _hover_boxes:
		if box != null and is_instance_valid(box) \
				and int(box.get("click_action")) == CLICK_ACTION_PRIME_THEN_PLAY_ANIMATION:
			return box
	return null


func _find_toggle_hover_box() -> Control:
	for box in _hover_boxes:
		if box != null and is_instance_valid(box) \
				and int(box.get("click_action")) == CLICK_ACTION_TOGGLE_VISIBILITY:
			return box
	return null


func _find_hover_box_by_name(box_name: String) -> Control:
	for box in _hover_boxes:
		if box != null and is_instance_valid(box) and box.name == box_name:
			return box
	return null


func _initialize_interaction_sounds() -> void:
	_wood_creak_sounds = _load_audio_streams(WOOD_CREAK_SOUND_PATHS)
	_hand_rub_sounds = _load_audio_streams(HAND_RUB_SOUND_PATHS)
	if not _wood_creak_sounds.is_empty():
		_wood_creak_audio_player = AudioStreamPlayer.new()
		_wood_creak_audio_player.name = "WoodCreakAudioPlayer"
		add_child(_wood_creak_audio_player)
	if not _hand_rub_sounds.is_empty():
		_hand_rub_audio_player = AudioStreamPlayer.new()
		_hand_rub_audio_player.name = "HandRubAudioPlayer"
		add_child(_hand_rub_audio_player)


func _load_audio_streams(paths: Array[String]) -> Array[AudioStream]:
	var streams: Array[AudioStream] = []
	for path in paths:
		var stream := load(path) as AudioStream
		if stream != null:
			streams.append(stream)
	return streams


func _play_wood_creak_sound() -> void:
	_play_random_stream(_wood_creak_audio_player, _wood_creak_sounds)


func _play_hand_rub_sound() -> void:
	_play_random_stream(_hand_rub_audio_player, _hand_rub_sounds)


func _play_random_stream(player: AudioStreamPlayer, streams: Array[AudioStream]) -> void:
	if Engine.is_editor_hint() or player == null or streams.is_empty():
		return
	player.stream = streams[_rng.randi_range(0, streams.size() - 1)]
	player.pitch_scale = 1.0
	player.volume_db = 0.0
	player.play()


func _get_animation_layers() -> Control:
	return get_node_or_null(animation_layers_path) as Control
