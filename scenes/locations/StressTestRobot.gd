extends Control

const RobotHoverBox: GDScript = preload("res://scenes/locations/RobotHoverBox.gd")

const FRAME_SIZE: Vector2i = Vector2i(250, 350)
const DEFAULT_FPS: float = 12.0
const STATIC_PATHS := {
	"right_arm": "Arms",
	"left_arm": "Arms",
	"torso": "Torso",
	"hair_front_normal": "Head/HairFrontNormal",
	"squint_eyes": "Head/SquintEyes",
	"neck": "Head/Neck",
	"head": "Head/HeadBase",
	"hair_back": "HairBack",
	"nipples": "Torso/Nipples",
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
@export var sync_animation_layer_scale: bool = true

@onready var head: Control = $Head
@onready var animation_layers: Control = $AnimationLayers

var _head_hover_box: Control = null
var _head_interaction_enabled: bool = true
var _animation_primed: bool = false
var _animation_playing: bool = false
var _animation_elapsed: float = 0.0
var _active_animation: Dictionary = {}
var _active_animation_nodes: Dictionary = {}
var _hidden_static_nodes: Array[CanvasItem] = []


func _ready() -> void:
	_sync_animation_layers_to_robot_size()
	animation_layers.visible = false
	_spawn_head_hover_box()
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)


func _process(delta: float) -> void:
	_update_head_hover()
	if _animation_playing:
		_advance_animation(delta)


func _on_resized() -> void:
	_sync_animation_layers_to_robot_size()
	_spawn_head_hover_box()


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


func _start_layered_animation(animation: Dictionary, play_immediately: bool, hide_static: bool = true) -> void:
	_active_animation = animation
	_animation_elapsed = 0.0
	_animation_playing = play_immediately
	if hide_static:
		_hide_static_nodes(animation.get("static_paths", {}))
	_collect_animation_nodes(animation)
	_set_animation_frame(0)
	animation_layers.visible = true


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

	for node in _hidden_static_nodes:
		if node and is_instance_valid(node):
			node.visible = true
	_hidden_static_nodes.clear()
	_active_animation = {}


func _hide_static_nodes(static_paths: Dictionary) -> void:
	_hidden_static_nodes.clear()
	for key in static_paths:
		var node := get_node_or_null(static_paths[key]) as CanvasItem
		if node == null:
			continue
		if node.visible:
			node.visible = false
			_hidden_static_nodes.append(node)


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
		node.visible = true
		_active_animation_nodes[layer_name] = node


func _hide_active_animation_nodes() -> void:
	for layer_name in _active_animation_nodes:
		var animation_node := _active_animation_nodes[layer_name] as CanvasItem
		if animation_node and is_instance_valid(animation_node):
			animation_node.visible = false


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
	if _head_hover_box and is_instance_valid(_head_hover_box):
		_head_hover_box.queue_free()

	var head_bounds := _compute_texture_bounds(head)
	if head_bounds.size == Vector2.ZERO:
		return

	var box: Control = RobotHoverBox.new()
	var buffer := float(head_border_buffer)
	box.position = head_bounds.position - Vector2(buffer, buffer)
	box.size = head_bounds.size + Vector2(buffer * 2.0, buffer * 2.0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.force_visible = force_show_head_hover_border
	box.z_index = 200
	head.add_child(box)
	_head_hover_box = box


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
