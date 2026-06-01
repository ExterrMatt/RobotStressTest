extends Control

const RobotHoverBox: GDScript = preload("res://scenes/locations/RobotHoverBox.gd")

const FRAME_SIZE: Vector2i = Vector2i(250, 350)
const DEFAULT_FPS: float = 12.0
const STATIC_PATHS := {
	"right_arm": "Arms/RightArm",
	"left_arm": "Arms/LeftArm",
	"torso": "Torso/TorsoBase",
	"hair_front_normal": "Head/HairFrontNormal",
	"squint_eyes": "Head/SquintEyes",
	"neck": "Head/Neck",
	"head": "Head/HeadBase",
	"hair_back": "HairBack",
	"nipples": "Torso/Nipples",
}
const BODY_PART_VARIANT_PATHS := {
	"torso": ["Torso/TorsoBase", "Torso/TorsoCrunch", "Torso/TorsoSkin"],
	"nipples": ["Torso/Nipples"],
	"right_arm": ["Arms/RightArm"],
	"left_arm": ["Arms/LeftArm"],
	"right_hand": ["Hands/RightPalmUp", "Hands/RightOpenFingers", "Hands/RightFlexedFingers"],
	"left_hand": ["Hands/LeftPalmUp", "Hands/LeftOpenFingers", "Hands/LeftFlexedFingers"],
	"right_leg": ["Legs/RightLeg", "Legs/RightLegSlightlyOut", "Legs/RightLegUpThigh", "Legs/RightLegUpShin"],
	"left_leg": ["Legs/LeftLeg", "Legs/LeftLegSlightlyOut", "Legs/LeftLegUpThigh", "Legs/LeftLegUpShin"],
	"head": ["Head/HeadBase"],
	"neck": ["Head/Neck"],
	"eyes": ["Head/SquintEyes"],
	"hair_front": ["Head/HairFrontNormal", "Head/HairFrontBangs"],
	"hair_back": ["HairBack"],
}
const DEFAULT_BODY_PART_PATHS := {
	"torso": ["Torso/TorsoBase"],
	"nipples": ["Torso/Nipples"],
	"right_arm": ["Arms/RightArm"],
	"left_arm": ["Arms/LeftArm"],
	"right_hand": ["Hands/RightPalmUp"],
	"left_hand": ["Hands/LeftPalmUp"],
	"right_leg": ["Legs/RightLeg"],
	"left_leg": ["Legs/LeftLeg"],
	"head": ["Head/HeadBase"],
	"neck": ["Head/Neck"],
	"eyes": ["Head/SquintEyes"],
	"hair_front": ["Head/HairFrontNormal"],
	"hair_back": ["HairBack"],
}
const PELVIS_BODY_PART_PATHS := {
	"torso": ["Torso/TorsoCrunch"],
	"nipples": ["Torso/Nipples"],
	"right_leg": ["Legs/RightLegUpThigh", "Legs/RightLegUpShin"],
	"left_leg": ["Legs/LeftLegUpThigh", "Legs/LeftLegUpShin"],
}
const ALL_RENDER_BODY_PARTS := [
	"torso",
	"nipples",
	"right_arm",
	"left_arm",
	"right_hand",
	"left_hand",
	"right_leg",
	"left_leg",
	"head",
	"neck",
	"eyes",
	"hair_front",
	"hair_back",
	"banana",
]
const PELVIS_RENDER_BODY_PARTS := [
	"torso",
	"nipples",
	"right_leg",
	"left_leg",
]
const HEAD_ANIMATION_BODY_PARTS := [
	"torso",
	"nipples",
	"right_arm",
	"left_arm",
	"head",
	"neck",
	"eyes",
	"hair_front",
	"hair_back",
]
const ANIMATION_LAYER_BODY_PARTS := {
	"banana": "banana",
	"right_arm": "right_arm",
	"left_arm": "left_arm",
	"torso": "torso",
	"hair_front_normal": "hair_front",
	"squint_eyes": "eyes",
	"neck": "neck",
	"head": "head",
	"hair_back": "hair_back",
	"nipples": "nipples",
}
const ANIMATION_BODY_PART_VARIANT_PATHS := {
	"torso": ["AnimationLayers/Torso", "AnimationLayers/MouthBLoopMedium/Torso"],
	"nipples": ["AnimationLayers/Nipples", "AnimationLayers/MouthBLoopMedium/Nipples"],
	"right_arm": ["AnimationLayers/RightArm", "AnimationLayers/MouthBLoopMedium/RightArm"],
	"left_arm": ["AnimationLayers/LeftArm", "AnimationLayers/MouthBLoopMedium/LeftArm"],
	"head": ["AnimationLayers/Head", "AnimationLayers/MouthBLoopMedium/Head"],
	"neck": ["AnimationLayers/Neck", "AnimationLayers/MouthBLoopMedium/Neck"],
	"eyes": ["AnimationLayers/SquintEyes", "AnimationLayers/MouthBLoopMedium/SquintEyes"],
	"hair_front": ["AnimationLayers/HairFrontNormal", "AnimationLayers/MouthBLoopMedium/HairFrontNormal"],
	"hair_back": ["AnimationLayers/HairBack", "AnimationLayers/MouthBLoopMedium/HairBack"],
	"banana": ["AnimationLayers/Banana", "AnimationLayers/MouthBLoopMedium/Banana"],
}
const INTRO_NODE_PATHS := {
	"banana": "Banana",
	"right_arm": "RightArm",
	"left_arm": "LeftArm",
	"torso": "Torso",
	"hair_front_normal": "HairFrontNormal",
	"squint_eyes": "SquintEyes",
	"neck": "Neck",
	"head": "Head",
	"hair_back": "HairBack",
	"nipples": "Nipples",
}
const LOOP_MEDIUM_NODE_PATHS := {
	"banana": "MouthBLoopMedium/Banana",
	"right_arm": "MouthBLoopMedium/RightArm",
	"left_arm": "MouthBLoopMedium/LeftArm",
	"torso": "MouthBLoopMedium/Torso",
	"hair_front_normal": "MouthBLoopMedium/HairFrontNormal",
	"squint_eyes": "MouthBLoopMedium/SquintEyes",
	"neck": "MouthBLoopMedium/Neck",
	"head": "MouthBLoopMedium/Head",
	"hair_back": "MouthBLoopMedium/HairBack",
	"nipples": "MouthBLoopMedium/Nipples",
}

const HEAD_ANIMATION := {
	"name": "mouth_b_intro",
	"texture": preload("res://assets/textures/characters/robot/stresstest/animations/head/Mouth-B-Intro/mouth_b_intro.png"),
	"frame_count": 16,
	"loop": false,
	"next": "mouth_b_loop_medium",
	"layers": {
		"banana": 8,
		"right_arm": 7,
		"left_arm": 6,
		"torso": 5,
		"hair_front_normal": 4,
		"squint_eyes": 3,
		"neck": 2,
		"head": 1,
		"hair_back": 0,
	},
	"static_paths": STATIC_PATHS,
	"node_paths": INTRO_NODE_PATHS,
}

const HEAD_LOOP_MEDIUM_ANIMATION := {
	"name": "mouth_b_loop_medium",
	"texture": preload("res://assets/textures/characters/robot/stresstest/animations/head/Mouth-B-Loop-Medium/mouth_b_loop_medium.png"),
	"frame_count": 8,
	"loop": true,
	"layers": {
		"banana": 9,
		"hair_front_normal": 8,
		"nipples": 7,
		"torso": 6,
		"right_arm": 5,
		"left_arm": 4,
		"squint_eyes": 3,
		"head": 2,
		"neck": 1,
		"hair_back": 0,
	},
	"static_paths": STATIC_PATHS,
	"node_paths": LOOP_MEDIUM_NODE_PATHS,
}

const HEAD_ANIMATION_DRAW_ORDER: Array[String] = [
	"hair_back",
	"head",
	"neck",
	"squint_eyes",
	"hair_front_normal",
	"torso",
	"nipples",
	"left_arm",
	"right_arm",
	"banana",
]

const HEAD_ANIMATIONS := {
	"mouth_b_intro": HEAD_ANIMATION,
	"mouth_b_loop_medium": HEAD_LOOP_MEDIUM_ANIMATION,
}

@export var head_border_buffer: int = 4
@export_range(0.0, 1.0, 0.01) var head_alpha_threshold: float = 0.05
@export var force_show_head_hover_border: bool = false
@export var head_hover_box_path: NodePath = ^"Head/HeadHoverBox"
@export var use_custom_head_hover_rect: bool = false
@export var custom_head_hover_rect: Rect2 = Rect2()
@export var pelvis_border_buffer: int = 4
@export var force_show_pelvis_hover_border: bool = false
@export var pelvis_hover_box_path: NodePath = ^"PelvisHoverBox"
@export var use_custom_pelvis_hover_rect: bool = false
@export var custom_pelvis_hover_rect: Rect2 = Rect2()
@export var sync_animation_layer_scale: bool = true
@export var body_part_inventory: Dictionary = {
	"torso": true,
	"nipples": true,
	"right_arm": true,
	"left_arm": true,
	"right_hand": true,
	"left_hand": true,
	"right_leg": true,
	"left_leg": true,
	"head": true,
	"neck": true,
	"eyes": true,
	"hair_front": true,
	"hair_back": true,
	"banana": true,
}

@onready var head: Control = $Head
@onready var torso_base: TextureRect = $Torso/TorsoBase
@onready var animation_layers: Control = $AnimationLayers

var _head_hover_box: Control = null
var _pelvis_hover_box: Control = null
var _head_interaction_enabled: bool = true
var _pelvis_pose_active: bool = false
var _animation_primed: bool = false
var _animation_playing: bool = false
var _animation_elapsed: float = 0.0
var _active_animation: Dictionary = {}
var _active_animation_nodes: Dictionary = {}


func _ready() -> void:
	_sync_animation_layers_to_robot_size()
	animation_layers.visible = false
	_spawn_head_hover_box()
	_spawn_pelvis_hover_box()
	_pelvis_pose_active = false
	_apply_robot_render_state()
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)


func _process(delta: float) -> void:
	_update_head_hover()
	_update_pelvis_hover()
	if _animation_playing:
		_advance_animation(delta)


func _on_resized() -> void:
	_sync_animation_layers_to_robot_size()
	_spawn_head_hover_box()
	_spawn_pelvis_hover_box()


func _sync_animation_layers_to_robot_size() -> void:
	if not sync_animation_layer_scale or animation_layers == null:
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return
	animation_layers.scale = Vector2(
		size.x / float(FRAME_SIZE.x),
		size.y / float(FRAME_SIZE.y)
	)


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if not _head_interaction_enabled:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	if _pelvis_hover_box and is_instance_valid(_pelvis_hover_box):
		if _pelvis_hover_box.get_global_rect().has_point(mouse_event.global_position):
			toggle_pelvis_pose()
			get_viewport().set_input_as_handled()
			return

	if _head_hover_box == null or not is_instance_valid(_head_hover_box):
		return
	if not _head_hover_box.get_global_rect().has_point(mouse_event.global_position):
		return

	if _animation_playing and _active_animation.get("loop", false):
		_finish_layered_animation()
		get_viewport().set_input_as_handled()
		return
	if _animation_playing:
		return

	if _animation_primed:
		play_head_animation()
	else:
		prime_head_animation()
	get_viewport().set_input_as_handled()


func prime_head_animation() -> bool:
	if _animation_playing or _animation_primed:
		return false
	_start_layered_animation(HEAD_ANIMATION, false)
	_animation_primed = true
	return true


func play_head_animation() -> bool:
	if _animation_playing:
		return false
	if _animation_primed:
		_animation_elapsed = 0.0
		_animation_playing = true
		return true
	_start_layered_animation(HEAD_ANIMATION, true)
	return true


func set_head_interaction_enabled(value: bool) -> void:
	_head_interaction_enabled = value
	if _head_hover_box and is_instance_valid(_head_hover_box):
		_head_hover_box.visible = value
	if _pelvis_hover_box and is_instance_valid(_pelvis_hover_box):
		_pelvis_hover_box.visible = value


func toggle_pelvis_pose() -> void:
	_set_pelvis_pose_active(not _pelvis_pose_active)


func _set_pelvis_pose_active(value: bool) -> void:
	_pelvis_pose_active = value
	_apply_pelvis_pose()


func has_body_part(part_name: String) -> bool:
	return bool(body_part_inventory.get(part_name, true))


func set_body_part_available(part_name: String, value: bool) -> void:
	body_part_inventory[part_name] = value
	if PELVIS_RENDER_BODY_PARTS.has(part_name):
		_apply_pelvis_pose()
	else:
		_apply_robot_render_state([part_name])


func _apply_pelvis_pose() -> void:
	_set_canvas_item_visible(^"Legs/RightLeg", has_body_part("right_leg") and not _pelvis_pose_active)
	_set_canvas_item_visible(^"Legs/LeftLeg", has_body_part("left_leg") and not _pelvis_pose_active)
	_set_canvas_item_visible(^"Legs/RightLegUpThigh", has_body_part("right_leg") and _pelvis_pose_active)
	_set_canvas_item_visible(^"Legs/RightLegUpShin", has_body_part("right_leg") and _pelvis_pose_active)
	_set_canvas_item_visible(^"Legs/LeftLegUpThigh", has_body_part("left_leg") and _pelvis_pose_active)
	_set_canvas_item_visible(^"Legs/LeftLegUpShin", has_body_part("left_leg") and _pelvis_pose_active)
	if _head_animation_active():
		return
	_set_canvas_item_visible(^"Torso/TorsoBase", has_body_part("torso") and not _pelvis_pose_active)
	_set_canvas_item_visible(^"Torso/TorsoCrunch", has_body_part("torso") and _pelvis_pose_active)
	_set_canvas_item_visible(^"Torso/Nipples", has_body_part("nipples"))


func _start_layered_animation(animation: Dictionary, play_immediately: bool, _hide_static: bool = true) -> void:
	_active_animation = animation
	_animation_elapsed = 0.0
	_animation_playing = play_immediately
	_collect_animation_nodes(animation)
	_set_animation_frame(0)
	_apply_robot_render_state(HEAD_ANIMATION_BODY_PARTS)


func _advance_animation(delta: float) -> void:
	_animation_elapsed += delta
	var frame := int(floor(_animation_elapsed * DEFAULT_FPS))
	var frame_count: int = int(_active_animation.get("frame_count", 1))
	if frame >= frame_count:
		if _active_animation.get("loop", false):
			_animation_elapsed = 0.0
			_set_animation_frame(0)
			return
		var next_animation_name := String(_active_animation.get("next", ""))
		if next_animation_name != "" and HEAD_ANIMATIONS.has(next_animation_name):
			_start_layered_animation(HEAD_ANIMATIONS[next_animation_name], true, false)
			return
		_finish_layered_animation()
		return
	_set_animation_frame(frame)


func _finish_layered_animation() -> void:
	_animation_playing = false
	_animation_primed = false
	animation_layers.visible = false
	for layer_name in _active_animation_nodes:
		var animation_node := _active_animation_nodes[layer_name] as CanvasItem
		if animation_node and is_instance_valid(animation_node):
			animation_node.visible = false
	_active_animation_nodes = {}
	_active_animation = {}
	_apply_robot_render_state(HEAD_ANIMATION_BODY_PARTS)


func _collect_animation_nodes(animation: Dictionary) -> void:
	_hide_active_animation_nodes()
	_active_animation_nodes = {}
	var node_paths: Dictionary = animation.get("node_paths", {})
	var layers: Dictionary = animation.get("layers", {})
	for layer_name in node_paths:
		if not layers.has(layer_name):
			continue
		var node := animation_layers.get_node_or_null(node_paths[layer_name]) as Sprite2D
		if node == null:
			push_warning("Animation layer node not found: %s" % node_paths[layer_name])
			continue
		_active_animation_nodes[layer_name] = node


func _hide_active_animation_nodes() -> void:
	for layer_name in _active_animation_nodes:
		var animation_node := _active_animation_nodes[layer_name] as CanvasItem
		if animation_node and is_instance_valid(animation_node):
			animation_node.visible = false


func _apply_robot_render_state(parts: Array = []) -> void:
	var render_parts := parts if not parts.is_empty() else ALL_RENDER_BODY_PARTS
	for part_name in render_parts:
		_apply_body_part_render_state(String(part_name))
	_refresh_animation_layer_visibility()


func _apply_body_part_render_state(part_name: String) -> void:
	_hide_body_part_variants(part_name)
	match part_name:
		"torso", "nipples":
			if _head_animation_overrides_part(part_name):
				return
			elif _pelvis_pose_active:
				_show_body_part_pose(part_name, PELVIS_BODY_PART_PATHS)
			else:
				_show_body_part_pose(part_name, DEFAULT_BODY_PART_PATHS)
		"right_leg", "left_leg":
			_show_body_part_pose(part_name, PELVIS_BODY_PART_PATHS if _pelvis_pose_active else DEFAULT_BODY_PART_PATHS)
		_:
			_show_default_body_part_unless_head_animated(part_name)


func _hide_body_part_variants(part_name: String) -> void:
	if BODY_PART_VARIANT_PATHS.has(part_name):
		for path in BODY_PART_VARIANT_PATHS[part_name]:
			_set_canvas_item_visible(NodePath(String(path)), false)
	if ANIMATION_BODY_PART_VARIANT_PATHS.has(part_name):
		for path in ANIMATION_BODY_PART_VARIANT_PATHS[part_name]:
			_set_canvas_item_visible(NodePath(String(path)), false)


func _show_default_body_part_unless_head_animated(part_name: String) -> void:
	if _head_animation_overrides_part(part_name):
		return
	_show_body_part_pose(part_name, DEFAULT_BODY_PART_PATHS)


func _show_body_part_pose(part_name: String, pose_paths: Dictionary) -> void:
	if not has_body_part(part_name) or not pose_paths.has(part_name):
		return
	for path in pose_paths[part_name]:
		_set_canvas_item_visible(NodePath(String(path)), true)


func _head_animation_overrides_part(part_name: String) -> bool:
	if not _head_animation_active():
		return false
	if not HEAD_ANIMATION_BODY_PARTS.has(part_name):
		return false
	return _active_animation_has_part(part_name)


func _head_animation_active() -> bool:
	return not _active_animation.is_empty() and not _active_animation_nodes.is_empty()


func _active_animation_has_part(part_name: String) -> bool:
	for layer_name in _active_animation_nodes:
		if String(ANIMATION_LAYER_BODY_PARTS.get(String(layer_name), "")) == part_name:
			return true
	return false


func _refresh_animation_layer_visibility() -> void:
	var has_visible_layer := false
	for layer_name in _active_animation_nodes:
		var node := _active_animation_nodes[layer_name] as CanvasItem
		if node == null or not is_instance_valid(node):
			continue
		var visible := _should_show_animation_layer(String(layer_name))
		node.visible = visible
		has_visible_layer = has_visible_layer or visible
	animation_layers.visible = has_visible_layer


func _should_show_animation_layer(layer_name: String) -> bool:
	if not _head_animation_active():
		return false
	var part_name := String(ANIMATION_LAYER_BODY_PARTS.get(layer_name, ""))
	if part_name == "":
		return true
	if not has_body_part(part_name):
		return false
	return true


func _set_canvas_item_visible(path: NodePath, value: bool) -> void:
	var node := get_node_or_null(path) as CanvasItem
	if node == null:
		return
	node.visible = value


func _set_animation_frame(frame: int) -> void:
	var layers: Dictionary = _active_animation.get("layers", {})
	for layer_name in _active_animation_nodes:
		if not layers.has(layer_name):
			continue
		var node := _active_animation_nodes[layer_name] as Sprite2D
		var column: int = layers[layer_name]
		node.region_rect = Rect2(
			Vector2(column * FRAME_SIZE.x, frame * FRAME_SIZE.y),
			FRAME_SIZE
		)

func _spawn_head_hover_box() -> void:
	var existing_box := get_node_or_null(head_hover_box_path) as Control
	if existing_box != null:
		_head_hover_box = existing_box
	elif _head_hover_box != null and is_instance_valid(_head_hover_box):
		_head_hover_box.queue_free()

	var box: Control = _head_hover_box
	if box == null:
		box = RobotHoverBox.new()
	if not use_custom_head_hover_rect:
		var head_bounds := _compute_texture_bounds(head)
		if head_bounds.size == Vector2.ZERO:
			return
		_apply_hover_box_rect(box, head_bounds, head_border_buffer)
	elif custom_head_hover_rect.size != Vector2.ZERO:
		_apply_hover_box_rect(box, custom_head_hover_rect, head_border_buffer)

	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.force_visible = force_show_head_hover_border
	box.z_index = 200
	if box.get_parent() == null:
		head.add_child(box)
	_head_hover_box = box


func _spawn_pelvis_hover_box() -> void:
	var existing_box := get_node_or_null(pelvis_hover_box_path) as Control
	if existing_box != null:
		_pelvis_hover_box = existing_box
	elif _pelvis_hover_box != null and is_instance_valid(_pelvis_hover_box):
		_pelvis_hover_box.queue_free()

	var box: Control = _pelvis_hover_box
	if box == null:
		box = RobotHoverBox.new()
	if not use_custom_pelvis_hover_rect:
		var pelvis_bounds := _compute_auto_pelvis_hover_rect()
		if pelvis_bounds.size == Vector2.ZERO:
			return
		_apply_hover_box_rect(box, pelvis_bounds, pelvis_border_buffer)
	elif custom_pelvis_hover_rect.size != Vector2.ZERO:
		_apply_hover_box_rect(box, custom_pelvis_hover_rect, pelvis_border_buffer)

	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.force_visible = force_show_pelvis_hover_border
	box.z_index = 201
	if box.get_parent() == null:
		add_child(box)
	_pelvis_hover_box = box


func _apply_hover_box_rect(box: Control, bounds: Rect2, buffer: int) -> void:
	var pad := float(buffer)
	box.position = bounds.position - Vector2(pad, pad)
	box.size = bounds.size + Vector2(pad * 2.0, pad * 2.0)


func _compute_auto_pelvis_hover_rect() -> Rect2:
	var torso_bounds := _compute_single_texture_bounds(torso_base)
	if torso_bounds.size == Vector2.ZERO:
		return Rect2()
	var pelvis_height := torso_bounds.size.y / 3.0
	return Rect2(
		Vector2(torso_bounds.position.x, torso_bounds.position.y + torso_bounds.size.y - pelvis_height),
		Vector2(torso_bounds.size.x, pelvis_height)
	)


func _update_head_hover() -> void:
	if _head_hover_box == null or not is_instance_valid(_head_hover_box):
		return
	if not _head_interaction_enabled:
		_head_hover_box.visible = false
		return
	_head_hover_box.visible = true
	if force_show_head_hover_border:
		_head_hover_box.force_visible = true
		_head_hover_box.set_hovered(true)
		return
	_head_hover_box.force_visible = false
	_head_hover_box.set_hovered(_head_hover_box.get_global_rect().has_point(get_global_mouse_position()))


func _update_pelvis_hover() -> void:
	if _pelvis_hover_box == null or not is_instance_valid(_pelvis_hover_box):
		return
	if not _head_interaction_enabled:
		_pelvis_hover_box.visible = false
		return
	_pelvis_hover_box.visible = true
	if force_show_pelvis_hover_border:
		_pelvis_hover_box.force_visible = true
		_pelvis_hover_box.set_hovered(true)
		return
	_pelvis_hover_box.force_visible = false
	_pelvis_hover_box.set_hovered(_pelvis_hover_box.get_global_rect().has_point(get_global_mouse_position()))


func _compute_texture_bounds(root: Node) -> Rect2:
	var bounds := Rect2()
	var found_any := false
	for tr in _collect_texture_rects(root):
		var tex: Texture2D = tr.texture
		if tex == null:
			continue
		var img := tex.get_image()
		if img == null:
			continue
		var used := _opaque_bounds(img, head_alpha_threshold)
		if used.size == Vector2i.ZERO:
			continue
		var sx := size.x / float(img.get_width())
		var sy := size.y / float(img.get_height())
		var mapped := Rect2(
			used.position.x * sx,
			used.position.y * sy,
			used.size.x * sx,
			used.size.y * sy
		)
		if not found_any:
			bounds = mapped
			found_any = true
		else:
			bounds = bounds.merge(mapped)
	return bounds


func _compute_single_texture_bounds(tr: TextureRect) -> Rect2:
	var tex: Texture2D = tr.texture
	if tex == null:
		return Rect2()
	var img := tex.get_image()
	if img == null:
		return Rect2()
	var used := _opaque_bounds(img, head_alpha_threshold)
	if used.size == Vector2i.ZERO:
		return Rect2()
	var sx := size.x / float(img.get_width())
	var sy := size.y / float(img.get_height())
	return Rect2(
		used.position.x * sx,
		used.position.y * sy,
		used.size.x * sx,
		used.size.y * sy
	)


func _collect_texture_rects(node: Node) -> Array[TextureRect]:
	var out: Array[TextureRect] = []
	if node is TextureRect:
		out.append(node)
	for child in node.get_children():
		out.append_array(_collect_texture_rects(child))
	return out


func _opaque_bounds(img: Image, threshold: float) -> Rect2i:
	var initial := img.get_used_rect()
	if initial.size == Vector2i.ZERO or threshold <= 0.0:
		return initial

	var min_x := initial.position.x + initial.size.x
	var min_y := initial.position.y + initial.size.y
	var max_x := initial.position.x - 1
	var max_y := initial.position.y - 1
	for y in range(initial.position.y, initial.position.y + initial.size.y):
		for x in range(initial.position.x, initial.position.x + initial.size.x):
			if img.get_pixel(x, y).a > threshold:
				if x < min_x: min_x = x
				if y < min_y: min_y = y
				if x > max_x: max_x = x
				if y > max_y: max_y = y
	if max_x < min_x:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
