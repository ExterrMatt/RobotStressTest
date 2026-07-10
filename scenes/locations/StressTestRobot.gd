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
const TORSO_CRUNCH_PATH: NodePath = ^"Torso/TorsoCrunch"
const INTRO_ANIMATION_TORSO_PATH: NodePath = ^"AnimationLayers/Torso"
const LOOP_ANIMATION_TORSO_PATH: NodePath = ^"AnimationLayers/MouthBLoopMedium/Torso"
const LEGS_PATH: NodePath = ^"Legs"
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

## Chest textures swapped by the shoulder-pad toggle: the outlined chest is
## shown while the pads are on, the outline-free chest while they are off.
const CHEST_PATH: NodePath = ^"Torso/Chest"
const CHEST_NO_OUTLINE_PATH: NodePath = ^"Torso/ChestNoOutline"
const LEFT_SHOULDER_PAD_PATH: NodePath = ^"Arms/LeftShoulderPad"
const RIGHT_SHOULDER_PAD_PATH: NodePath = ^"Arms/RightShoulderPad"
const SHOULDER_HOVER_BOX_NAMES: Array[String] = ["LeftShoulderHoverBox", "RightShoulderHoverBox"]

## The animation strip carries the chest as three stacked columns (base chest,
## chest details, outline). The shoulder-pad toggle mirrors the static robot:
## the outline shows while the pads are on and the chest details show while they
## are off, so exactly one of these overlays is visible during the head anim.
const ANIM_OUTLINE_PATHS: Array[NodePath] = [
	^"AnimationLayers/Outline",
	^"AnimationLayers/MouthBLoopMedium/Outline",
]
const ANIM_CHEST_DETAILS_PATHS: Array[NodePath] = [
	^"AnimationLayers/ChestDetails",
	^"AnimationLayers/MouthBLoopMedium/ChestDetails",
]

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

const TORSO_PART_PATHS: Array[NodePath] = [
	^"Torso/TorsoNeckBack",
	^"Torso/TorsoBase",
	^"Torso/Chest",
	^"Torso/ChestNoOutline",
	^"Torso/BigCoconuts",
	^"Torso/Nipples",
	^"Torso/TorsoCrunch",
	^"BoobCover",
	^"AnimationLayers/Torso",
	^"AnimationLayers/ChestDetails",
	^"AnimationLayers/Outline",
	^"AnimationLayers/Nipples",
	^"AnimationLayers/Torso/Nipples",
	^"AnimationLayers/MouthBLoopMedium/Torso",
	^"AnimationLayers/MouthBLoopMedium/ChestDetails",
	^"AnimationLayers/MouthBLoopMedium/Outline",
	^"AnimationLayers/MouthBLoopMedium/Nipples",
]
const LEFT_ARM_PART_PATHS: Array[NodePath] = [
	^"Arms/LeftArm",
	^"Arms/LeftShoulderPad",
	^"AnimationArmLayers/LeftArm",
	^"AnimationArmLayers/MouthBLoopMedium/LeftArm",
]
const RIGHT_ARM_PART_PATHS: Array[NodePath] = [
	^"Arms/RightArm",
	^"Arms/RightShoulderPad",
	^"AnimationArmLayers/RightArm",
	^"AnimationArmLayers/MouthBLoopMedium/RightArm",
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

@export var hover_box_paths: Array[NodePath] = [^"HeadHoverBox", ^"HairHoverBox", ^"PelvisHoverBox", ^"BoobCoverHoverBox", ^"LeftShoulderHoverBox", ^"RightShoulderHoverBox", ^"LeftHandHoverBox", ^"RightHandHoverBox"]:
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

var _active_animation_box: Control = null
var _animation_phase: String = ANIMATION_PHASE_NONE
var _animation_playing: bool = false
var _animation_elapsed: float = 0.0
## When enabled (Sleep scene) the leg lift gains a preliminary "slightly out"
## pose; the stress test leaves this off and lifts on the first click.
var _leg_slight_out_prestage_enabled: bool = false
var _leg_prestage_active: bool = false
## Currently selected hand-pose option per side (index into the option lists).
var _left_hand_texture_index: int = 0
var _right_hand_texture_index: int = 0
## Currently selected hair-front style (index into the hair option lists).
var _hair_texture_index: int = HAIR_DEFAULT_INDEX
## Currently selected head style (index into the head option lists).
var _head_texture_index: int = HEAD_DEFAULT_INDEX
## Whether the squint-eyes overlay is shown.
var _squint_eyes_enabled: bool = SQUINT_DEFAULT_ENABLED
var _animation_torso_restore_state: Dictionary = {}
var _raised_legs_restore_index: int = -1
var _rng := RandomNumberGenerator.new()
var _wood_creak_sounds: Array[AudioStream] = []
var _hand_rub_sounds: Array[AudioStream] = []
var _wood_creak_audio_player: AudioStreamPlayer = null
var _hand_rub_audio_player: AudioStreamPlayer = null
## Sides ("left"/"right") whose player hand is currently hidden because that
## hand is holding the screwdriver on that side during a stress-test repair.
var _repair_hidden_hand_sides: Dictionary = {}


func _ready() -> void:
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
	if _animation_playing:
		_advance_animation(delta)
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

	_handle_hover_box_click(clicked_box)
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
	if box == null or _active_animation_box == box:
		return false
	_prime_layered_animation(box)
	return true


func play_head_animation() -> bool:
	var box := _find_animation_hover_box()
	if box == null:
		return false
	if _active_animation_box != box:
		_prime_layered_animation(box)
	if _animation_playing:
		return false
	_animation_elapsed = 0.0
	_animation_playing = true
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
	_active_animation_box = null
	_animation_phase = ANIMATION_PHASE_NONE
	_animation_playing = false
	_animation_elapsed = 0.0
	_leg_prestage_active = false
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
	if _active_animation_box != null and is_instance_valid(_active_animation_box):
		return false
	if _leg_prestage_active:
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
		if _active_animation_box != box:
			return "Raise Head"
		if _animation_phase == ANIMATION_PHASE_INTRO and not _animation_playing:
			return "Animate Head"
		return "Lower Head"
	if String(box.name) == "PelvisHoverBox":
		if _box_has_layered_animation(box):
			if _active_animation_box != box:
				return "Raise Legs"
			if _animation_phase == ANIMATION_PHASE_INTRO and not _animation_playing:
				return "Animate Legs"
			return "Lower Legs"
		return "Lower Legs" if _is_box_effect_active(box) else "Raise Legs"
	if String(box.name) == "BoobCoverHoverBox":
		return "Remove Chest Cover" if _is_boob_cover_visible() else "Equip Chest Cover"
	if _is_shoulder_hover_box(box):
		return "Equip Shoulder Pads" if _are_shoulder_pads_removed() else "Remove Shoulder Pads"
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


func _handle_hover_box_click(box: Control) -> void:
	var action := int(box.get("click_action"))
	if action == CLICK_ACTION_PRIME_THEN_PLAY_ANIMATION:
		_handle_layered_animation_click(box)
		return
	if _is_shoulder_hover_box(box):
		_toggle_shoulder_pads()
		return
	if _is_hand_hover_box(box):
		_cycle_hand_texture(box)
		return
	if _is_hair_hover_box(box):
		_cycle_hair_texture()
		return
	_toggle_box_effect(box)


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


## Either shoulder box drives a single shared toggle, so clicking one removes or
## restores both shoulder pads together and keeps the two boxes in sync.
func _toggle_shoulder_pads() -> void:
	var new_active := not _are_shoulder_pads_removed()
	for box_name in SHOULDER_HOVER_BOX_NAMES:
		var box := _find_hover_box_by_name(box_name)
		if box != null and box.has_method("set_runtime_active"):
			box.call("set_runtime_active", new_active)
	_apply_visibility_state()


func _is_shoulder_hover_box(box: Control) -> bool:
	return box != null and SHOULDER_HOVER_BOX_NAMES.has(String(box.name))


func _are_shoulder_pads_removed() -> bool:
	for box_name in SHOULDER_HOVER_BOX_NAMES:
		if _is_named_box_effect_active(box_name):
			return true
	return false


func _toggle_box_effect(box: Control) -> void:
	if box.has_method("toggle_runtime_active"):
		box.call("toggle_runtime_active")
	_apply_visibility_state()


func _handle_layered_animation_click(box: Control) -> void:
	if not _box_has_layered_animation(box):
		_toggle_box_effect(box)
		return

	if _leg_slight_out_prestage_enabled and _is_leg_prestage_box(box) \
			and _active_animation_box != box:
		if not _leg_prestage_active:
			_enter_leg_prestage()
			return
		# Second click: leave the slightly-out pose and lift the leg as usual.
		_leg_prestage_active = false

	if _active_animation_box != box:
		_finish_layered_animation(false)
		_prime_layered_animation(box)
		return

	if _animation_phase == ANIMATION_PHASE_LOOP and _animation_playing:
		_finish_layered_animation()
		return

	if _animation_playing:
		return

	if _animation_phase == ANIMATION_PHASE_NONE:
		_prime_layered_animation(box)
		return

	_animation_elapsed = 0.0
	_animation_playing = true
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
	_active_animation_box = box
	_animation_phase = ANIMATION_PHASE_INTRO
	_animation_playing = false
	_animation_elapsed = 0.0
	if box.has_method("set_runtime_active"):
		box.call("set_runtime_active", true)
	_set_animation_frame_for_box(box, _animation_phase, 0)
	_play_wood_creak_sound()
	_apply_visibility_state()


func _advance_animation(delta: float) -> void:
	if _active_animation_box == null or not is_instance_valid(_active_animation_box):
		_finish_layered_animation()
		return

	var fps := maxf(0.1, float(_active_animation_box.get("animation_fps")))
	_animation_elapsed += delta
	var frame := int(floor(_animation_elapsed * fps))
	var frame_count := _get_phase_frame_count(_active_animation_box, _animation_phase)

	if frame >= frame_count:
		if _animation_phase == ANIMATION_PHASE_INTRO \
				and bool(_active_animation_box.get("loop_after_intro")) \
				and not _get_animation_phase_paths(_active_animation_box, ANIMATION_PHASE_LOOP).is_empty():
			_animation_phase = ANIMATION_PHASE_LOOP
			_animation_elapsed = 0.0
			_set_animation_frame_for_box(_active_animation_box, _animation_phase, 0)
			_apply_visibility_state()
			return

		if _animation_phase == ANIMATION_PHASE_LOOP:
			_animation_elapsed = 0.0
			_set_animation_frame_for_box(_active_animation_box, _animation_phase, 0)
			_apply_visibility_state()
			return

		_finish_layered_animation()
		return

	_set_animation_frame_for_box(_active_animation_box, _animation_phase, frame)


func _finish_layered_animation(apply_state: bool = true) -> void:
	_leg_prestage_active = false
	if _active_animation_box != null and is_instance_valid(_active_animation_box) \
			and _active_animation_box.has_method("set_runtime_active"):
		_active_animation_box.call("set_runtime_active", false)
	_active_animation_box = null
	_animation_phase = ANIMATION_PHASE_NONE
	_animation_playing = false
	_animation_elapsed = 0.0
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
	_apply_hand_texture_selection(resolved)
	_apply_hair_texture_selection(resolved)
	_apply_head_texture_selection(resolved)
	_apply_squint_eyes_state(resolved)
	_apply_robot_part_availability_to_dictionary(resolved)
	_apply_repair_hidden_hands_to_dictionary(resolved)
	_apply_pelvis_torso_crunch_animation_slot(resolved)
	_apply_shoulder_pad_state(resolved)
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
	_apply_paths_available(resolved, TORSO_PART_PATHS, _robot_part_count("torso") >= 1)

	var arm_count := _robot_part_count("arm")
	_apply_paths_available(resolved, LEFT_ARM_PART_PATHS, arm_count >= 1)
	_apply_paths_available(resolved, RIGHT_ARM_PART_PATHS, arm_count >= 2)

	var hand_count := _robot_part_count("hand")
	_apply_paths_available(resolved, LEFT_HAND_PART_PATHS, hand_count >= 1)
	_apply_paths_available(resolved, RIGHT_HAND_PART_PATHS, hand_count >= 2)

	var leg_count := _robot_part_count("leg")
	_apply_paths_available(resolved, LEFT_LEG_PART_PATHS, leg_count >= 1)
	_apply_paths_available(resolved, RIGHT_LEG_PART_PATHS, leg_count >= 2)


func _apply_repair_hidden_hands_to_dictionary(resolved: Dictionary) -> void:
	if bool(_repair_hidden_hand_sides.get("left", false)):
		_apply_paths_available(resolved, LEFT_GRIP_HAND_PATHS, false)
	if bool(_repair_hidden_hand_sides.get("right", false)):
		_apply_paths_available(resolved, RIGHT_GRIP_HAND_PATHS, false)


## Resolves the shoulder-pad toggle. When the pads are removed they are hidden
## and the outlined chest is swapped for the outline-free chest wherever the
## chest would otherwise show; when the pads are on the outline-free chest stays
## hidden and the regular chest is left untouched. The head-animation strip
## mirrors this: its outline column shows with the pads on and its chest-details
## column shows with the pads off.
func _apply_shoulder_pad_state(resolved: Dictionary) -> void:
	if not _are_shoulder_pads_removed():
		resolved[CHEST_NO_OUTLINE_PATH] = false
		_hide_paths(resolved, ANIM_CHEST_DETAILS_PATHS)
		return
	resolved[LEFT_SHOULDER_PAD_PATH] = false
	resolved[RIGHT_SHOULDER_PAD_PATH] = false
	if bool(resolved.get(CHEST_PATH, false)):
		resolved[CHEST_PATH] = false
		resolved[CHEST_NO_OUTLINE_PATH] = true
	else:
		resolved[CHEST_NO_OUTLINE_PATH] = false
	_hide_paths(resolved, ANIM_OUTLINE_PATHS)


func _hide_paths(resolved: Dictionary, paths: Array[NodePath]) -> void:
	for path in paths:
		resolved[path] = false


func _apply_paths_available(resolved: Dictionary, paths: Array[NodePath], available: bool) -> void:
	if available:
		return
	for path in paths:
		resolved[path] = false


func _apply_pelvis_torso_crunch_animation_slot(resolved: Dictionary) -> void:
	_restore_animation_torso_slots()
	_restore_raised_legs_order()
	if _robot_part_count("torso") < 1:
		return
	if not _is_named_box_effect_active("PelvisHoverBox"):
		return

	var head_box := _find_hover_box_by_name("HeadHoverBox")
	if head_box == null or not _is_box_effect_active(head_box):
		return

	var phase := _get_visible_animation_phase_for_box(head_box)
	if phase == ANIMATION_PHASE_NONE:
		return

	var target_path := LOOP_ANIMATION_TORSO_PATH if phase == ANIMATION_PHASE_LOOP else INTRO_ANIMATION_TORSO_PATH
	var target := get_node_or_null(target_path) as Sprite2D
	var source := get_node_or_null(TORSO_CRUNCH_PATH) as TextureRect
	if target == null or source == null or source.texture == null:
		return

	_remember_animation_torso_slot(target_path, target)
	target.texture = source.texture
	target.region_enabled = false
	resolved[TORSO_CRUNCH_PATH] = false
	resolved[target_path] = true
	_move_raised_legs_above_animation_layers()


func _remember_animation_torso_slot(path: NodePath, node: Sprite2D) -> void:
	var key := String(path)
	if _animation_torso_restore_state.has(key):
		return
	_animation_torso_restore_state[key] = {
		"texture": node.texture,
		"region_enabled": node.region_enabled,
		"region_rect": node.region_rect,
	}


func _restore_animation_torso_slots() -> void:
	for key in _animation_torso_restore_state:
		var node := get_node_or_null(NodePath(key)) as Sprite2D
		if node == null:
			continue
		var state: Dictionary = _animation_torso_restore_state[key]
		node.texture = state.get("texture")
		node.region_enabled = bool(state.get("region_enabled", false))
		node.region_rect = state.get("region_rect", Rect2())
	_animation_torso_restore_state.clear()


func _move_raised_legs_above_animation_layers() -> void:
	var legs := get_node_or_null(LEGS_PATH)
	var layers := _get_animation_layers()
	if legs == null or layers == null:
		return
	var parent := legs.get_parent()
	if parent == null or parent != layers.get_parent():
		return
	if _raised_legs_restore_index < 0:
		_raised_legs_restore_index = legs.get_index()
	var target_index := layers.get_index()
	if legs.get_index() > layers.get_index():
		target_index += 1
	parent.move_child(legs, target_index)


func _restore_raised_legs_order() -> void:
	if _raised_legs_restore_index < 0:
		return
	var legs := get_node_or_null(LEGS_PATH)
	if legs == null:
		_raised_legs_restore_index = -1
		return
	var parent := legs.get_parent()
	if parent == null:
		_raised_legs_restore_index = -1
		return
	parent.move_child(legs, mini(_raised_legs_restore_index, parent.get_child_count() - 1))
	_raised_legs_restore_index = -1


func _add_robot_part_managed_paths() -> void:
	_add_managed_paths(TORSO_PART_PATHS)
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
	if box.name == "PelvisHoverBox" or box.name == "BoobCoverHoverBox" or _is_shoulder_hover_box(box):
		return _robot_part_count("torso") >= 1
	if box.name == LEFT_HAND_HOVER_BOX_NAME:
		return _robot_part_count("hand") >= 1
	if box.name == RIGHT_HAND_HOVER_BOX_NAME:
		return _robot_part_count("hand") >= 2
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


func _set_animation_frame_for_box(box: Control, phase: String, frame: int) -> void:
	var frame_size: Vector2i = box.get("animation_frame_size")
	if frame_size.x <= 0 or frame_size.y <= 0:
		frame_size = DEFAULT_FRAME_SIZE

	var paths := _get_animation_phase_paths(box, phase)
	for column in range(paths.size()):
		var node := get_node_or_null(NodePath(String(paths[column]))) as Sprite2D
		if node == null:
			continue
		node.region_rect = Rect2(
			Vector2(column * frame_size.x, frame * frame_size.y),
			frame_size
		)
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

	if box != _active_animation_box:
		return ANIMATION_PHASE_NONE
	return _animation_phase


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


func _is_boob_cover_visible() -> bool:
	var cover := get_node_or_null(^"BoobCover") as CanvasItem
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
