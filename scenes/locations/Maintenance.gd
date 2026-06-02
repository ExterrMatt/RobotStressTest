extends LocationBase

const RobotHoverBox: GDScript = preload("res://scenes/locations/RobotHoverBox.gd")

const PAN_DURATION: float = 0.35
const PAN_TRANS: int = Tween.TRANS_SINE
const PAN_EASE: int = Tween.EASE_IN_OUT

@export var robot_border_buffer: int = 10
@export_range(0.0, 1.0, 0.01) var robot_alpha_threshold: float = 0.05
@export var force_show_hover_border: bool = false

@onready var camera_window: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow
@onready var scene_canvas: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas
@onready var robot: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/RobotLayer/PersonalityTestRobot

var _robot_bbox_local: Rect2 = Rect2()
var _hover_box: Control = null
var _zoomed: bool = false
var _zoom_tween: Tween = null


func _ready() -> void:
	_robot_bbox_local = _compute_robot_pixel_bbox()
	_spawn_hover_box()


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if _hover_box == null or not is_instance_valid(_hover_box):
		return
	if not _hover_box.visible or not _hover_box.is_visible_in_tree():
		return
	if not _hover_box.get_global_rect().has_point(mouse_event.global_position):
		return

	_zoom_to_robot_box()
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _hover_box == null or not is_instance_valid(_hover_box):
		return
	if force_show_hover_border:
		_hover_box.force_visible = true
		_hover_box.set_hovered(true)
		return
	_hover_box.force_visible = false
	_hover_box.set_hovered(_hover_box.get_global_rect().has_point(get_global_mouse_position()))


func _compute_robot_pixel_bbox() -> Rect2:
	var bounds: Rect2 = Rect2()
	var found_any: bool = false
	for tr in _collect_texture_rects(robot):
		if tr.name == "Shadow":
			continue
		var tex: Texture2D = tr.texture
		if tex == null:
			continue
		var img: Image = tex.get_image()
		if img == null:
			continue
		var used: Rect2i = _opaque_bounds(img, robot_alpha_threshold)
		if used.size == Vector2i.ZERO:
			continue
		var sx: float = robot.size.x / float(img.get_width())
		var sy: float = robot.size.y / float(img.get_height())
		var mapped := Rect2(
			Vector2(used.position.x * sx, used.position.y * sy),
			Vector2(used.size.x * sx, used.size.y * sy)
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
	var initial: Rect2i = img.get_used_rect()
	if initial.size == Vector2i.ZERO or threshold <= 0.0:
		return initial

	var min_x: int = initial.position.x + initial.size.x
	var min_y: int = initial.position.y + initial.size.y
	var max_x: int = initial.position.x - 1
	var max_y: int = initial.position.y - 1
	var x_end: int = initial.position.x + initial.size.x
	var y_end: int = initial.position.y + initial.size.y
	for y in range(initial.position.y, y_end):
		for x in range(initial.position.x, x_end):
			if img.get_pixel(x, y).a > threshold:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _spawn_hover_box() -> void:
	if _hover_box and is_instance_valid(_hover_box):
		_hover_box.queue_free()
		_hover_box = null
	if _robot_bbox_local.size == Vector2.ZERO:
		return

	var box: Control = RobotHoverBox.new()
	var buffer := float(robot_border_buffer)
	box.position = _robot_bbox_local.position - Vector2(buffer, buffer)
	box.size = _robot_bbox_local.size + Vector2(buffer * 2.0, buffer * 2.0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.force_visible = force_show_hover_border
	box.z_index = 100
	robot.add_child(box)
	_hover_box = box


func _zoom_to_robot_box() -> void:
	if _zoomed or camera_window == null or scene_canvas == null:
		return

	var buffer := float(robot_border_buffer)
	var rect_origin := robot.position + (_robot_bbox_local.position - Vector2(buffer, buffer)) * robot.scale
	var rect_size := (_robot_bbox_local.size + Vector2(buffer * 2.0, buffer * 2.0)) * robot.scale
	if rect_size.y <= 0.0 or camera_window.size.y <= 0.0:
		return

	var target_scale := camera_window.size.y / rect_size.y
	var target_position := Vector2(
		camera_window.size.x * 0.5 - (rect_origin.x + rect_size.x * 0.5) * target_scale,
		-rect_origin.y * target_scale
	)

	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.set_parallel(true)
	_zoom_tween.set_trans(PAN_TRANS)
	_zoom_tween.set_ease(PAN_EASE)
	_zoom_tween.tween_property(scene_canvas, "scale", Vector2(target_scale, target_scale), PAN_DURATION)
	_zoom_tween.tween_property(scene_canvas, "position", target_position, PAN_DURATION)
	_zoomed = true


func _on_end_button_pressed() -> void:
	finish()
