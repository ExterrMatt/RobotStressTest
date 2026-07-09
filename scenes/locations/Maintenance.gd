extends LocationBase

const RobotHoverBox: GDScript = preload("res://scenes/locations/RobotHoverBox.gd")

const PAN_DURATION: float = 0.35
const PAN_TRANS: int = Tween.TRANS_SINE
const PAN_EASE: int = Tween.EASE_IN_OUT
const BASE_SCENE_SIZE: Vector2 = Vector2(500.0, 400.0)
const ZOOM_MULTIPLIER: float = 2.0
const SCROLL_STEP_VIEW_FRACTION: float = 0.5
const SCRUB_ITEM_ID: StringName = &"buff_shine"
const SCRUB_REQUIRED_DISTANCE: float = 3000.0
const MAINTENANCE_ITEM_IDS: Array[StringName] = [
	&"zap",
	&"quick_patch",
	&"user",
]

@export var robot_border_buffer: int = 10
@export_range(0.0, 1.0, 0.01) var robot_alpha_threshold: float = 0.05
@export var force_show_hover_border: bool = false

## Design values for the corner END button, kept in sync with Main's shared
## floating END/LEAVE button: the GoldHudButton look at 1.5x font + padding.
const END_BUTTON_FONT_SIZE: int = 48         # Main.LARGE_SCENE_HUD_FONT_SIZE (32) * 1.5
const END_BUTTON_PADDING_SCALE: float = 1.5  # Main.LARGE_SCENE_END_BUTTON_SIZE_SCALE

@onready var camera_window: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow
@onready var scene_canvas: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas
@onready var robot: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/RobotLayer/PersonalityTestRobot
@onready var end_button: Button = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/EndButton

var _robot_bbox_local: Rect2 = Rect2()
var _hover_box: Control = null
var _drop_slots: Array[DropSlot] = []
var _scrub_item: DraggableItem = null
var _scrub_bar: ProgressBar = null
var _scrub_progress: float = 0.0
var _last_scrub_global_pos: Vector2 = Vector2.ZERO
var _has_last_scrub_global_pos: bool = false
var _scrub_complete: bool = false
var _zoomed: bool = false
var _zoom_tween: Tween = null
var _canvas_base_scale: float = 1.0
var _zoom_scale: float = 1.0
var _view_left: float = 0.0
var _view_top: float = 0.0


func _ready() -> void:
	if camera_window != null and not camera_window.resized.is_connected(_on_camera_window_resized):
		camera_window.resized.connect(_on_camera_window_resized)
	_apply_default_canvas_transform()
	call_deferred("_apply_default_canvas_transform")
	_robot_bbox_local = _compute_robot_pixel_bbox()
	_spawn_hover_box()
	_spawn_drop_slots()
	_spawn_scrub_bar()
	_style_end_button_like_workshop()
	call_deferred("_cache_scrub_item")


## Restyle the in-scene END button to match Main's shared corner END/LEAVE button
## (the gold-bordered GoldHudButton look at 1.5x font + padding). Only the design
## changes: the button keeps its authored bottom-right anchor and offsets, and
## since it grows toward the top-left (grow direction BEGIN) its bottom-right
## corner stays exactly where it is while the larger design expands up and left.
func _style_end_button_like_workshop() -> void:
	if end_button == null:
		return
	end_button.theme_type_variation = &"GoldHudButton"
	end_button.focus_mode = Control.FOCUS_NONE
	end_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	end_button.add_theme_font_size_override("font_size", END_BUTTON_FONT_SIZE)
	# Scale each state's stylebox padding to match the enlarged font while leaving
	# the theme's border width untouched (so it stays crisp, like Main's button).
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var base := end_button.get_theme_stylebox(state)
		if base == null:
			continue
		var sb := base.duplicate() as StyleBox
		sb.content_margin_left = base.get_margin(SIDE_LEFT) * END_BUTTON_PADDING_SCALE
		sb.content_margin_top = base.get_margin(SIDE_TOP) * END_BUTTON_PADDING_SCALE
		sb.content_margin_right = base.get_margin(SIDE_RIGHT) * END_BUTTON_PADDING_SCALE
		sb.content_margin_bottom = base.get_margin(SIDE_BOTTOM) * END_BUTTON_PADDING_SCALE
		end_button.add_theme_stylebox_override(state, sb)


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return

	if _zoomed and mouse_event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_scroll_zoomed_view(mouse_event.button_index)
		get_viewport().set_input_as_handled()
		return

	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _hover_box == null or not is_instance_valid(_hover_box):
		return
	if not _hover_box.visible or not _hover_box.is_visible_in_tree():
		return
	if not _hover_box.get_global_rect().has_point(mouse_event.global_position):
		return

	_toggle_robot_box_zoom()
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
	_update_scrub_progress()


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


func _spawn_drop_slots() -> void:
	for slot in _drop_slots:
		if slot != null and is_instance_valid(slot):
			slot.queue_free()
	_drop_slots.clear()

	if _robot_bbox_local.size == Vector2.ZERO:
		return

	var buffer := float(robot_border_buffer)
	var slot_rect := Rect2(
		_robot_bbox_local.position - Vector2(buffer, buffer),
		_robot_bbox_local.size + Vector2(buffer * 2.0, buffer * 2.0)
	)
	for item_id in MAINTENANCE_ITEM_IDS:
		var slot := DropSlot.new()
		slot.name = "MaintenanceDropSlot%d" % _drop_slots.size()
		slot.accepts_item_id = item_id
		slot.position = slot_rect.position
		slot.size = slot_rect.size
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.z_index = 99
		robot.add_child(slot)
		_drop_slots.append(slot)


func _spawn_scrub_bar() -> void:
	if camera_window == null:
		return
	_scrub_bar = ProgressBar.new()
	_scrub_bar.name = "ScrubProgressBar"
	_scrub_bar.anchor_left = 1.0
	_scrub_bar.anchor_right = 1.0
	_scrub_bar.offset_left = -172.0
	_scrub_bar.offset_top = 16.0
	_scrub_bar.offset_right = -20.0
	_scrub_bar.offset_bottom = 34.0
	_scrub_bar.max_value = 1.0
	_scrub_bar.value = 0.0
	_scrub_bar.show_percentage = false
	_scrub_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrub_bar.z_index = 120
	camera_window.add_child(_scrub_bar)


func _cache_scrub_item() -> void:
	_scrub_item = _find_draggable_item_by_id(self, SCRUB_ITEM_ID)


func _update_scrub_progress() -> void:
	if _scrub_complete:
		return
	if _scrub_item == null or not is_instance_valid(_scrub_item):
		_cache_scrub_item()
	if _scrub_item == null or not is_instance_valid(_scrub_item):
		return
	if not _scrub_item.visible or not _scrub_item.is_dragging():
		_has_last_scrub_global_pos = false
		return

	var item_center := _scrub_item.global_position + _scrub_item.size * 0.5
	if _hover_box == null or not _hover_box.get_global_rect().has_point(item_center):
		_last_scrub_global_pos = item_center
		_has_last_scrub_global_pos = true
		return

	if _has_last_scrub_global_pos:
		_scrub_progress = minf(
			SCRUB_REQUIRED_DISTANCE,
			_scrub_progress + item_center.distance_to(_last_scrub_global_pos)
		)
		_update_scrub_bar()
		if _scrub_progress >= SCRUB_REQUIRED_DISTANCE:
			_complete_scrub()

	_last_scrub_global_pos = item_center
	_has_last_scrub_global_pos = true


func _update_scrub_bar() -> void:
	if _scrub_bar != null and is_instance_valid(_scrub_bar):
		_scrub_bar.value = _scrub_progress / SCRUB_REQUIRED_DISTANCE


func _complete_scrub() -> void:
	_scrub_complete = true
	_scrub_progress = SCRUB_REQUIRED_DISTANCE
	_update_scrub_bar()
	if _scrub_item == null or not is_instance_valid(_scrub_item):
		return
	if _scrub_item.is_dragging():
		_scrub_item.end_drag(_scrub_item.global_position + _scrub_item.size * 0.5)
	_scrub_item.visible = false
	_scrub_item.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _find_draggable_item_by_id(node: Node, item_id: StringName) -> DraggableItem:
	for child in node.get_children():
		if child is DraggableItem and child.item_id == item_id:
			return child
		var found := _find_draggable_item_by_id(child, item_id)
		if found != null:
			return found
	return null


func _toggle_robot_box_zoom() -> void:
	if _zoomed:
		_reset_zoom()
	else:
		_zoom_to_robot_box()


func _zoom_to_robot_box() -> void:
	if camera_window == null or scene_canvas == null:
		return

	var robot_rect := _robot_bbox_in_scene_canvas()
	var view_top := clampf(robot_rect.position.y, 0.0, BASE_SCENE_SIZE.y)
	var full_robot_view_height := BASE_SCENE_SIZE.y - view_top
	if full_robot_view_height <= 0.0 or camera_window.size.y <= 0.0:
		return

	_zoom_scale = maxf(1.0, BASE_SCENE_SIZE.y / full_robot_view_height) * ZOOM_MULTIPLIER
	_center_zoomed_view_horizontally()
	_view_top = _max_view_top()
	_animate_to_view(_view_left, _view_top)
	_zoomed = true


func _reset_zoom() -> void:
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoomed = false
	_zoom_scale = 1.0
	_view_left = 0.0
	_view_top = 0.0
	_apply_default_canvas_transform()


func _scroll_zoomed_view(button_index: int) -> void:
	var step := _current_view_size().y * SCROLL_STEP_VIEW_FRACTION
	if button_index == MOUSE_BUTTON_WHEEL_UP:
		_view_top -= step
	else:
		_view_top += step
	_view_top = clampf(_view_top, 0.0, _max_view_top())
	_animate_to_view(_view_left, _view_top)


func _apply_default_canvas_transform() -> void:
	if camera_window == null or scene_canvas == null:
		return
	if camera_window.size == Vector2.ZERO:
		return

	_canvas_base_scale = minf(
		camera_window.size.x / BASE_SCENE_SIZE.x,
		camera_window.size.y / BASE_SCENE_SIZE.y
	)
	var display_size := BASE_SCENE_SIZE * _canvas_base_scale
	scene_canvas.size = BASE_SCENE_SIZE
	scene_canvas.pivot_offset = Vector2.ZERO
	scene_canvas.scale = Vector2(_canvas_base_scale, _canvas_base_scale)
	scene_canvas.position = (camera_window.size - display_size) * 0.5


func _animate_to_view(view_left: float, view_top: float) -> void:
	var target_scale := _canvas_base_scale * _zoom_scale
	var target_position := Vector2(
		-view_left * target_scale,
		-view_top * target_scale
	)

	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.set_parallel(true)
	_zoom_tween.set_trans(PAN_TRANS)
	_zoom_tween.set_ease(PAN_EASE)
	_zoom_tween.tween_property(scene_canvas, "scale", Vector2(target_scale, target_scale), PAN_DURATION)
	_zoom_tween.tween_property(scene_canvas, "position", target_position, PAN_DURATION)


func _center_zoomed_view_horizontally() -> void:
	var view_size := _current_view_size()
	var max_view_left := maxf(0.0, BASE_SCENE_SIZE.x - view_size.x)
	_view_left = clampf(BASE_SCENE_SIZE.x * 0.5 - view_size.x * 0.5, 0.0, max_view_left)


func _current_view_size() -> Vector2:
	var target_scale := _canvas_base_scale * _zoom_scale
	if target_scale <= 0.0:
		return BASE_SCENE_SIZE
	return camera_window.size / target_scale


func _max_view_top() -> float:
	return maxf(0.0, BASE_SCENE_SIZE.y - _current_view_size().y)


func _robot_bbox_in_scene_canvas() -> Rect2:
	var to_scene := scene_canvas.get_global_transform_with_canvas().affine_inverse() \
		* robot.get_global_transform_with_canvas()
	var points := [
		to_scene * _robot_bbox_local.position,
		to_scene * (_robot_bbox_local.position + Vector2(_robot_bbox_local.size.x, 0.0)),
		to_scene * (_robot_bbox_local.position + Vector2(0.0, _robot_bbox_local.size.y)),
		to_scene * (_robot_bbox_local.position + _robot_bbox_local.size),
	]
	var min_point: Vector2 = points[0]
	var max_point: Vector2 = points[0]
	for point in points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)


func _on_camera_window_resized() -> void:
	if _zoomed:
		return
	_apply_default_canvas_transform()


func _on_end_button_pressed() -> void:
	finish()
