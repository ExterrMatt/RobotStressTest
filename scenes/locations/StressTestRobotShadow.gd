@tool
extends Control

@export_range(0.0, 0.6, 0.01) var edge_y_stretch: float = 0.2:
	set(value):
		edge_y_stretch = value
		_update_shader_parameters()

@export_range(0.5, 5.0, 0.1) var curve_power: float = 2.0:
	set(value):
		curve_power = value
		_update_shader_parameters()

@export var shadow_frame_size: Vector2 = Vector2(250.0, 350.0):
	set(value):
		shadow_frame_size = value
		_update_shader_parameters()

@export_range(0.0, 100.0, 1.0) var top_erase_px: float = 35.0:
	set(value):
		top_erase_px = value
		_update_shader_parameters()

@export var source_robot_path: NodePath = ^"../StressTestRobot"

var _shadow_material: ShaderMaterial
var _source_robot: Node = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_shadow_materials()
	_resolve_source_robot()
	set_process(true)


func _process(_delta: float) -> void:
	_mirror_source_robot_visuals()


func _apply_shadow_materials() -> void:
	_shadow_material = ShaderMaterial.new()
	_shadow_material.shader = _create_shadow_shader()
	_update_shader_parameters()
	_apply_shadow_material_to(self)


func _apply_shadow_material_to(node: Node) -> void:
	for child in node.get_children():
		if child is TextureRect or child is Sprite2D:
			var canvas_item := child as CanvasItem
			canvas_item.material = _shadow_material
			if child is Control:
				(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_shadow_material_to(child)


func _mirror_source_robot_visuals() -> void:
	if _source_robot == null or not is_instance_valid(_source_robot):
		_resolve_source_robot()
	if _source_robot == null:
		return

	_mirror_source_node_children(self)


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
		var source_child := _source_robot.get_node_or_null(get_path_to(shadow_child))
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


func _update_shader_parameters() -> void:
	if _shadow_material == null:
		return
	_shadow_material.set_shader_parameter("frame_height", shadow_frame_size.y)
	_shadow_material.set_shader_parameter("center_y", shadow_frame_size.y * 0.5)
	_shadow_material.set_shader_parameter("edge_y_stretch", edge_y_stretch)
	_shadow_material.set_shader_parameter("curve_power", curve_power)
	_shadow_material.set_shader_parameter("top_erase_px", top_erase_px)


func _create_shadow_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float frame_height = 350.0;
uniform float center_y = 175.0;
uniform float edge_y_stretch : hint_range(0.0, 0.6, 0.01) = 0.2;
uniform float curve_power : hint_range(0.5, 5.0, 0.1) = 2.0;
uniform float top_erase_px : hint_range(0.0, 100.0, 1.0) = 35.0;
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
	}
}
"""
	return shader
