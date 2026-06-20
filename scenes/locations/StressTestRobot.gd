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

const TORSO_PART_PATHS: Array[NodePath] = [
	^"Torso/TorsoNeckBack",
	^"Torso/TorsoBase",
	^"Torso/TorsoSkin",
	^"Torso/Nipples",
	^"Torso/TorsoCrunch",
	^"BoobCover",
	^"AnimationLayers/Torso",
	^"AnimationLayers/Nipples",
	^"AnimationLayers/Torso/Nipples",
	^"AnimationLayers/MouthBLoopMedium/Torso",
	^"AnimationLayers/MouthBLoopMedium/Nipples",
]
const LEFT_ARM_PART_PATHS: Array[NodePath] = [
	^"Arms/LeftArm",
	^"AnimationArmLayers/LeftArm",
	^"AnimationArmLayers/MouthBLoopMedium/LeftArm",
]
const RIGHT_ARM_PART_PATHS: Array[NodePath] = [
	^"Arms/RightArm",
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

@export var hover_box_paths: Array[NodePath] = [^"HeadHoverBox", ^"PelvisHoverBox", ^"BoobCoverHoverBox"]:
	set(value):
		hover_box_paths = value
		_request_configuration_refresh()

@export var animation_layers_path: NodePath = ^"AnimationLayers":
	set(value):
		animation_layers_path = value
		_request_configuration_refresh()

@export var sync_animation_layer_scale: bool = true

## Nodes that must stay hidden in-game and in hover previews until removed here.
@export var always_hidden_image_paths: Array[NodePath] = [^"Head/HairFrontBangs"]:
	set(value):
		always_hidden_image_paths = value
		_request_configuration_refresh()

var _hover_boxes: Array[Control] = []
var _managed_paths: Array[NodePath] = []
var _base_visibility: Dictionary = {}
var _interaction_enabled: bool = true
var _editor_preview_was_active: bool = false

var _active_animation_box: Control = null
var _animation_phase: String = ANIMATION_PHASE_NONE
var _animation_playing: bool = false
var _animation_elapsed: float = 0.0
var _animation_torso_restore_state: Dictionary = {}
var _raised_legs_restore_index: int = -1
var _rng := RandomNumberGenerator.new()
var _wood_creak_sounds: Array[AudioStream] = []
var _hand_rub_sounds: Array[AudioStream] = []
var _wood_creak_audio_player: AudioStreamPlayer = null
var _hand_rub_audio_player: AudioStreamPlayer = null


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
	_toggle_box_effect(box)


func _toggle_box_effect(box: Control) -> void:
	if box.has_method("toggle_runtime_active"):
		box.call("toggle_runtime_active")
	_apply_visibility_state()


func _handle_layered_animation_click(box: Control) -> void:
	if not _box_has_layered_animation(box):
		_toggle_box_effect(box)
		return

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


func _prime_layered_animation(box: Control) -> void:
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

	_apply_animation_parent_visibility(resolved)
	_apply_always_hidden_to_dictionary(resolved)
	_apply_robot_part_availability_to_dictionary(resolved)
	_apply_pelvis_torso_crunch_animation_slot(resolved)
	_apply_resolved_visibility(resolved)


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
	if box.name == "PelvisHoverBox" or box.name == "BoobCoverHoverBox":
		return _robot_part_count("torso") >= 1
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
