@tool
extends Control

@export_group("Full Body Shadow")
@export var full_body_shadow_offset: Vector2 = Vector2.ZERO

@export_range(0.0, 0.6, 0.01) var full_body_edge_y_stretch: float = 0.2:
	set(value):
		full_body_edge_y_stretch = value
		_apply_shadow_profile()

@export_range(0.5, 5.0, 0.1) var full_body_curve_power: float = 2.0:
	set(value):
		full_body_curve_power = value
		_apply_shadow_profile()

@export var full_body_shadow_frame_size: Vector2 = Vector2(250.0, 350.0):
	set(value):
		full_body_shadow_frame_size = value
		_apply_shadow_profile()

@export_range(0.0, 100.0, 1.0) var full_body_top_erase_px: float = 35.0:
	set(value):
		full_body_top_erase_px = value
		_apply_shadow_profile()

@export_group("Head Only Shadow")
@export var head_only_shadow_offset: Vector2 = Vector2.ZERO

@export_range(0.0, 0.6, 0.01) var head_only_edge_y_stretch: float = 0.2:
	set(value):
		head_only_edge_y_stretch = value
		_apply_shadow_profile()

@export_range(0.5, 5.0, 0.1) var head_only_curve_power: float = 2.0:
	set(value):
		head_only_curve_power = value
		_apply_shadow_profile()

@export var head_only_shadow_frame_size: Vector2 = Vector2(250.0, 350.0):
	set(value):
		head_only_shadow_frame_size = value
		_apply_shadow_profile()

@export_range(0.0, 100.0, 1.0) var head_only_top_erase_px: float = 0.0:
	set(value):
		head_only_top_erase_px = value
		_apply_shadow_profile()

@export var preview_head_only_shadow: bool = false:
	set(value):
		preview_head_only_shadow = value
		if Engine.is_editor_hint():
			_head_only_shadow_enabled = value
			_apply_shadow_profile()

@export_group("Flattened Sprites")

@export_range(0.0, 1.0, 0.001) var flattened_shadow_alpha_threshold: float = 0.001:
	set(value):
		flattened_shadow_alpha_threshold = value
		_apply_shadow_profile()

@export_range(0.0, 1.0, 0.001) var flattened_shadow_edge_softness: float = 0.0:
	set(value):
		flattened_shadow_edge_softness = value
		_apply_shadow_profile()

@export_group("Final Shadow Tint")
@export var shadow_composite_path: NodePath = ^"ShadowComposite"

@export var flattened_shadow_color: Color = Color(0.0, 0.0, 0.0, 0.40784316):
	set(value):
		flattened_shadow_color = value
		_apply_shadow_composite_tint()

@export_group("Back Occlusion")
@export var hide_face_and_front_hair_when_back_present: bool = true

@export var back_present_source_paths: Array[NodePath] = [
	^"Torso/TorsoNeckBack",
	^"Torso/TorsoBase",
	^"Torso/TorsoSkin",
	^"Torso/TorsoCrunch",
	^"AnimationLayers/Torso",
	^"AnimationLayers/MouthBLoopMedium/Torso",
]

@export var face_and_front_hair_shadow_paths: Array[NodePath] = [
	^"Head/HeadBase",
	^"Head/SquintEyes",
	^"Head/HairFrontNormal",
	^"Head/HairFrontBangs",
	^"AnimationLayers/Head",
	^"AnimationLayers/SquintEyes",
	^"AnimationLayers/HairFrontNormal",
	^"AnimationLayers/MouthBLoopMedium/Head",
	^"AnimationLayers/MouthBLoopMedium/SquintEyes",
	^"AnimationLayers/MouthBLoopMedium/HairFrontNormal",
]

@export var source_robot_path: NodePath = ^"../StressTestRobot"
@export var shadow_robot_path: NodePath = ^"ShadowComposite/ShadowRobot"
@export var hidden_shadow_paths: Array[NodePath] = [
	^"HeadHoverBox",
	^"PelvisHoverBox",
	^"BoobCoverHoverBox",
]

var _shadow_material: ShaderMaterial
var _shadow_composite: CanvasGroup = null
var _source_robot: Node = null
var _shadow_robot: Node = null
var _head_only_shadow_enabled: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resolve_shadow_composite()
	_resolve_shadow_robot()
	_apply_shadow_materials()
	_resolve_source_robot()
	set_process(true)


func _process(_delta: float) -> void:
	_mirror_source_robot_visuals()


func set_head_only_shadow_enabled(value: bool) -> void:
	_head_only_shadow_enabled = value
	_apply_shadow_profile()
	_mirror_source_robot_visuals()


func get_shadow_position_offset() -> Vector2:
	if _head_only_shadow_enabled:
		return head_only_shadow_offset
	return full_body_shadow_offset


func _apply_shadow_materials() -> void:
	_shadow_material = ShaderMaterial.new()
	_shadow_material.shader = _create_shadow_shader()
	_apply_shadow_profile()
	if _shadow_robot != null:
		_apply_shadow_material_to(_shadow_robot)


func _apply_shadow_material_to(node: Node) -> void:
	for child in node.get_children():
		if child is TextureRect or child is Sprite2D:
			var canvas_item := child as CanvasItem
			canvas_item.material = _shadow_material
			canvas_item.z_index = 0
			if child is Control:
				(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_shadow_material_to(child)


func _mirror_source_robot_visuals() -> void:
	if _source_robot == null or not is_instance_valid(_source_robot):
		_resolve_source_robot()
	if _shadow_robot == null or not is_instance_valid(_shadow_robot):
		_resolve_shadow_robot()
	if _source_robot == null or _shadow_robot == null:
		return

	_mirror_source_node_children(_shadow_robot)
	_apply_hidden_shadow_paths()
	_apply_shadow_occlusion_rules()


func _resolve_shadow_composite() -> void:
	_shadow_composite = get_node_or_null(shadow_composite_path) as CanvasGroup
	_apply_shadow_composite_tint()


func _resolve_shadow_robot() -> void:
	_shadow_robot = get_node_or_null(shadow_robot_path)
	if _shadow_robot != null:
		_disable_shadow_robot_runtime(_shadow_robot)
		_apply_hidden_shadow_paths()


func _disable_shadow_robot_runtime(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	node.set_process_unhandled_key_input(false)
	for child in node.get_children():
		_disable_shadow_robot_runtime(child)


func _resolve_source_robot() -> void:
	_source_robot = get_node_or_null(source_robot_path)
	if _source_robot == null:
		return
	if _source_robot.has_signal("visual_state_changed"):
		var mirror_callable := Callable(self, "_mirror_source_robot_visuals")
		if not _source_robot.is_connected("visual_state_changed", mirror_callable):
			_source_robot.connect("visual_state_changed", mirror_callable)
	_mirror_source_robot_visuals()


func _mirror_source_node_children(shadow_node: Node) -> void:
	for shadow_child in shadow_node.get_children():
		var source_child := _source_robot.get_node_or_null(_shadow_robot.get_path_to(shadow_child))
		if source_child != null:
			_mirror_canvas_item_state(shadow_child, source_child)
		_mirror_source_node_children(shadow_child)


func _mirror_canvas_item_state(shadow_node: Node, source_node: Node) -> void:
	if shadow_node is CanvasItem and source_node is CanvasItem:
		(shadow_node as CanvasItem).visible = (source_node as CanvasItem).visible

	if shadow_node is TextureRect and source_node is TextureRect:
		(shadow_node as TextureRect).texture = (source_node as TextureRect).texture
		return

	if shadow_node is Sprite2D and source_node is Sprite2D:
		var shadow_sprite := shadow_node as Sprite2D
		var source_sprite := source_node as Sprite2D
		shadow_sprite.texture = source_sprite.texture
		shadow_sprite.region_enabled = source_sprite.region_enabled
		shadow_sprite.region_rect = source_sprite.region_rect


func _apply_hidden_shadow_paths() -> void:
	for path in hidden_shadow_paths:
		var shadow_node := _shadow_robot.get_node_or_null(path) as CanvasItem
		if shadow_node != null:
			shadow_node.visible = false


func _apply_shadow_occlusion_rules() -> void:
	if not _should_block_face_and_front_hair_shadows():
		return

	for path in face_and_front_hair_shadow_paths:
		var shadow_node := _shadow_robot.get_node_or_null(path) as CanvasItem
		if shadow_node != null:
			shadow_node.visible = false


func _should_block_face_and_front_hair_shadows() -> bool:
	if not hide_face_and_front_hair_when_back_present:
		return false
	for path in back_present_source_paths:
		var source_node := _source_robot.get_node_or_null(path) as CanvasItem
		if source_node != null and source_node.is_visible_in_tree():
			return true
	return false


func _apply_shadow_profile() -> void:
	if _shadow_material == null:
		return
	var frame_size := head_only_shadow_frame_size if _head_only_shadow_enabled else full_body_shadow_frame_size
	_shadow_material.set_shader_parameter("frame_height", frame_size.y)
	_shadow_material.set_shader_parameter("center_y", frame_size.y * 0.5)
	_shadow_material.set_shader_parameter(
		"edge_y_stretch",
		head_only_edge_y_stretch if _head_only_shadow_enabled else full_body_edge_y_stretch
	)
	_shadow_material.set_shader_parameter(
		"curve_power",
		head_only_curve_power if _head_only_shadow_enabled else full_body_curve_power
	)
	_shadow_material.set_shader_parameter(
		"top_erase_px",
		head_only_top_erase_px if _head_only_shadow_enabled else full_body_top_erase_px
	)
	_shadow_material.set_shader_parameter("alpha_threshold", flattened_shadow_alpha_threshold)
	_shadow_material.set_shader_parameter("edge_softness", flattened_shadow_edge_softness)


func _apply_shadow_composite_tint() -> void:
	if _shadow_composite == null or not is_instance_valid(_shadow_composite):
		return
	_shadow_composite.material = null
	_shadow_composite.modulate = flattened_shadow_color


func _create_shadow_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float frame_height = 350.0;
uniform float center_y = 175.0;
uniform float edge_y_stretch : hint_range(0.0, 0.6, 0.01) = 0.2;
uniform float curve_power : hint_range(0.5, 5.0, 0.1) = 2.0;
uniform float top_erase_px : hint_range(0.0, 100.0, 1.0) = 35.0;
uniform float alpha_threshold : hint_range(0.0, 1.0, 0.001) = 0.001;
uniform float edge_softness : hint_range(0.0, 1.0, 0.001) = 0.0;
varying float local_y;

void vertex() {
	local_y = VERTEX.y;
	float half_height = max(frame_height * 0.5, 0.001);
	float center_distance = VERTEX.y - center_y;
	float normalized_distance = clamp(center_distance / half_height, -1.0, 1.0);
	float edge_weight = pow(abs(normalized_distance), curve_power);
	VERTEX.y = center_y + center_distance * (1.0 + edge_y_stretch * edge_weight);
}

void fragment() {
	if (local_y <= top_erase_px) {
		COLOR = vec4(0.0);
	} else {
		float coverage = texture(TEXTURE, UV).a;
		float mask = step(alpha_threshold, coverage);
		if (edge_softness > 0.0001) {
			mask = smoothstep(alpha_threshold, alpha_threshold + edge_softness, coverage);
		}
		COLOR = vec4(1.0, 1.0, 1.0, mask);
	}
}
"""
	return shader
