extends LocationBase

const ZOOM_LEVEL_OUT: int = 0
const ZOOM_LEVEL_FIRST: int = 1
const ZOOM_LEVEL_SECOND: int = 2
const MAX_ZOOM_LEVEL: int = ZOOM_LEVEL_SECOND
const FIRST_ZOOM_SCALE: Vector2 = Vector2(2.0, 2.0)
const SECOND_ZOOM_SCALE: Vector2 = Vector2(3.0, 3.0)
const ZOOMED_OUT_SCALE: Vector2 = Vector2.ONE
const BASE_SCENE_SIZE: Vector2 = Vector2(800.0, 600.0)
const PAN_DURATION: float = 0.35
const PAN_TRANS: int = Tween.TRANS_SINE
const PAN_EASE: int = Tween.EASE_IN_OUT
const ZOOM_DURATION: float = 0.35
@export var robot_lights_on_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var robot_lights_off_modulate: Color = Color(0.3, 0.3, 0.3, 1.0)

@onready var camera_window: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow
@onready var scene_canvas: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas
@onready var first_zoom_regions: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/ZoomRegions/ZoomLevel1
@onready var second_zoom_regions: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/ZoomRegions/ZoomLevel2
@onready var light_placeholder: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder
@onready var dark_placeholder: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/DarkPlaceholder
@onready var pull_cord: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/PullCord
@onready var stress_test_robot: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/StressTestRobot

var _zoom_level: int = ZOOM_LEVEL_FIRST
var _current_zoom_region: Control = null
var _pan_tween: Tween = null
var _zoom_tween: Tween = null
var _canvas_base_scale: float = 1.0
var _stress_test_dark: bool = false


func _ready() -> void:
	_initialize_pull_cord()
	call_deferred("_initialize_zoom")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom_level(_zoom_level - 1, _global_to_scene_source(mouse_event.global_position))
			get_viewport().set_input_as_handled()
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom_level(_zoom_level + 1, _global_to_scene_source(mouse_event.global_position))
			get_viewport().set_input_as_handled()
			return

	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	var key_event := event as InputEventKey
	if key_event.keycode == KEY_Z:
		_set_zoom_level((_zoom_level + 1) % (MAX_ZOOM_LEVEL + 1), _global_to_scene_source(get_viewport().get_mouse_position()))
		get_viewport().set_input_as_handled()
		return

	var direction := Vector2i.ZERO
	match key_event.keycode:
		KEY_W:
			direction.y = -1
		KEY_A:
			direction.x = -1
		KEY_S:
			direction.y = 1
		KEY_D:
			direction.x = 1
		_:
			return

	_move_zoom_region(direction)
	get_viewport().set_input_as_handled()


func _initialize_zoom() -> void:
	if camera_window == null or scene_canvas == null:
		return

	if camera_window.size == Vector2.ZERO:
		await get_tree().process_frame

	if not camera_window.resized.is_connected(_on_camera_window_resized):
		camera_window.resized.connect(_on_camera_window_resized)

	_apply_default_canvas_transform()
	scene_canvas.pivot_offset = Vector2.ZERO
	_current_zoom_region = _find_region_for_focus(_zoom_level, BASE_SCENE_SIZE * 0.5)
	scene_canvas.scale = _current_zoom_scale() * _canvas_base_scale
	_apply_zoom_region(false)


func _move_zoom_region(direction: Vector2i) -> void:
	if not _is_zoomed_in():
		return

	var next_region := _neighbor_region(_current_zoom_region, direction)
	if next_region == null or next_region == _current_zoom_region:
		return

	_current_zoom_region = next_region
	_apply_zoom_region(true)


func _set_zoom_level(value: int, focus_position: Vector2) -> void:
	var next_zoom_level := clampi(value, ZOOM_LEVEL_OUT, MAX_ZOOM_LEVEL)
	if _zoom_level == next_zoom_level:
		return

	var next_region: Control = null
	if next_zoom_level > ZOOM_LEVEL_OUT:
		next_region = _find_region_for_focus(next_zoom_level, focus_position)
		if next_region == null:
			return

	_zoom_level = next_zoom_level
	_current_zoom_region = next_region

	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()

	var target_scale := _current_zoom_scale()
	var target_position := _zoom_position_for_region(_current_zoom_region, target_scale) if _is_zoomed_in() else _default_canvas_position()

	_zoom_tween = create_tween()
	_zoom_tween.set_parallel(true)
	_zoom_tween.set_trans(PAN_TRANS)
	_zoom_tween.set_ease(PAN_EASE)
	_zoom_tween.tween_property(scene_canvas, "scale", target_scale * _canvas_base_scale, ZOOM_DURATION)
	_zoom_tween.tween_property(scene_canvas, "position", target_position, ZOOM_DURATION)


func _apply_zoom_region(animated: bool) -> void:
	var logical_scale := _current_zoom_scale()
	var target_position := _zoom_position_for_region(_current_zoom_region, logical_scale) if _is_zoomed_in() else _default_canvas_position()
	var target_scale := logical_scale * _canvas_base_scale

	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()

	if not animated:
		scene_canvas.scale = target_scale
		scene_canvas.position = target_position
		return

	_pan_tween = create_tween()
	_pan_tween.set_parallel(true)
	_pan_tween.set_trans(PAN_TRANS)
	_pan_tween.set_ease(PAN_EASE)
	_pan_tween.tween_property(scene_canvas, "scale", target_scale, PAN_DURATION)
	_pan_tween.tween_property(scene_canvas, "position", target_position, PAN_DURATION)


func _zoom_position_for_region(region: Control, scale_value: Vector2) -> Vector2:
	if region == null:
		return _default_canvas_position()

	var display_scale := scale_value * _canvas_base_scale
	var region_center := _region_center(region)
	return camera_window.size * 0.5 - region_center * display_scale


func _on_camera_window_resized() -> void:
	_apply_default_canvas_transform()
	if _is_zoomed_in():
		scene_canvas.scale = _current_zoom_scale() * _canvas_base_scale
		_apply_zoom_region(false)
	else:
		scene_canvas.scale = ZOOMED_OUT_SCALE * _canvas_base_scale
		scene_canvas.position = _default_canvas_position()


func _apply_default_canvas_transform() -> void:
	if camera_window == null or scene_canvas == null or camera_window.size == Vector2.ZERO:
		return
	_canvas_base_scale = minf(
		camera_window.size.x / BASE_SCENE_SIZE.x,
		camera_window.size.y / BASE_SCENE_SIZE.y
	)
	scene_canvas.size = BASE_SCENE_SIZE


func _default_canvas_position() -> Vector2:
	var display_size := BASE_SCENE_SIZE * _canvas_base_scale
	return (camera_window.size - display_size) * 0.5


func _current_zoom_scale() -> Vector2:
	if _is_zoomed_in() and _current_zoom_region != null:
		return _zoom_scale_for_region(_current_zoom_region)

	return _base_zoom_scale_for_level(_zoom_level)


func _base_zoom_scale_for_level(zoom_level: int) -> Vector2:
	match zoom_level:
		ZOOM_LEVEL_SECOND:
			return SECOND_ZOOM_SCALE
		ZOOM_LEVEL_FIRST:
			return FIRST_ZOOM_SCALE
		_:
			return ZOOMED_OUT_SCALE


func _zoom_scale_for_region(region: Control) -> Vector2:
	var region_size := _region_rect(region).size
	if region_size.x <= 0.001 or region_size.y <= 0.001:
		return _base_zoom_scale_for_level(_zoom_level)

	return Vector2(
		BASE_SCENE_SIZE.x / region_size.x,
		BASE_SCENE_SIZE.y / region_size.y
	)


func _is_zoomed_in() -> bool:
	return _zoom_level > ZOOM_LEVEL_OUT


func _find_region_for_focus(zoom_level: int, focus_position: Vector2) -> Control:
	var active_regions := _active_regions_for_level(zoom_level)
	if active_regions.is_empty():
		return null

	var nearest_region: Control = null
	var nearest_distance := INF
	for region in active_regions:
		if not _region_rect(region).has_point(focus_position):
			continue

		var distance := _region_center(region).distance_squared_to(focus_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_region = region
	if nearest_region != null:
		return nearest_region

	nearest_distance = INF
	for region in active_regions:
		var distance := _region_center(region).distance_squared_to(focus_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_region = region
	return nearest_region


func _neighbor_region(region: Control, direction: Vector2i) -> Control:
	if region == null:
		return _find_region_for_focus(_zoom_level, _visible_source_center())

	var current_cell := _cell_for_region(region)
	if current_cell.x < 0 or current_cell.y < 0:
		return _find_region_for_focus(_zoom_level, _visible_source_center())

	var regions_by_cell := _regions_by_cell_for_level(_zoom_level)
	if regions_by_cell.is_empty():
		return null

	var next_cell := current_cell + direction
	while regions_by_cell.has(next_cell):
		var candidate := regions_by_cell[next_cell] as Control
		if candidate != null and bool(candidate.get("active")):
			return candidate
		next_cell += direction
	return null


func _active_regions_for_level(zoom_level: int) -> Array[Control]:
	var container := _region_container_for_level(zoom_level)
	var regions: Array[Control] = []
	if container == null:
		return regions

	for child in container.get_children():
		var region := child as Control
		if region == null:
			continue
		if bool(region.get("active")):
			regions.append(region)
	return regions


func _regions_by_cell_for_level(zoom_level: int) -> Dictionary:
	var container := _region_container_for_level(zoom_level)
	var regions_by_cell := {}
	if container == null:
		return regions_by_cell

	for child in container.get_children():
		var region := child as Control
		if region == null:
			continue

		var cell := _cell_for_region(region)
		if cell.x >= 0 and cell.y >= 0:
			regions_by_cell[cell] = region
	return regions_by_cell


func _region_container_for_level(zoom_level: int) -> Control:
	match zoom_level:
		ZOOM_LEVEL_FIRST:
			return first_zoom_regions
		ZOOM_LEVEL_SECOND:
			return second_zoom_regions
		_:
			return null


func _region_rect(region: Control) -> Rect2:
	var region_transform := region.get_transform()
	var top_left := region_transform * Vector2.ZERO
	var top_right := region_transform * Vector2(region.size.x, 0.0)
	var bottom_left := region_transform * Vector2(0.0, region.size.y)
	var bottom_right := region_transform * region.size

	var min_position := Vector2(
		minf(minf(top_left.x, top_right.x), minf(bottom_left.x, bottom_right.x)),
		minf(minf(top_left.y, top_right.y), minf(bottom_left.y, bottom_right.y))
	)
	var max_position := Vector2(
		maxf(maxf(top_left.x, top_right.x), maxf(bottom_left.x, bottom_right.x)),
		maxf(maxf(top_left.y, top_right.y), maxf(bottom_left.y, bottom_right.y))
	)
	return Rect2(min_position, max_position - min_position)


func _region_center(region: Control) -> Vector2:
	return _region_rect(region).get_center()


func _cell_for_region(region: Control) -> Vector2i:
	var region_name := String(region.name)
	var regex := RegEx.new()
	if regex.compile("_R([0-9]+)_C([0-9]+)$") != OK:
		return Vector2i(-1, -1)

	var result := regex.search(region_name)
	if result == null:
		return Vector2i(-1, -1)
	return Vector2i(int(result.get_string(2)), int(result.get_string(1)))


func _visible_source_center() -> Vector2:
	if scene_canvas == null:
		return BASE_SCENE_SIZE * 0.5
	return _global_to_scene_source(camera_window.get_global_rect().get_center())


func _global_to_scene_source(global_position: Vector2) -> Vector2:
	if scene_canvas == null:
		return BASE_SCENE_SIZE * 0.5
	return scene_canvas.get_global_transform_with_canvas().affine_inverse() * global_position


func _initialize_pull_cord() -> void:
	if pull_cord == null:
		return
	if pull_cord.has_signal("pulled"):
		var pulled_callable := Callable(self, "_on_pull_cord_pulled")
		if not pull_cord.is_connected("pulled", pulled_callable):
			pull_cord.connect("pulled", pulled_callable)
	_set_stress_test_dark(false)


func _on_pull_cord_pulled() -> void:
	_set_stress_test_dark(not _stress_test_dark)


func _set_stress_test_dark(value: bool) -> void:
	_stress_test_dark = value
	if light_placeholder != null:
		light_placeholder.visible = not _stress_test_dark
	if dark_placeholder != null:
		dark_placeholder.visible = _stress_test_dark
	if stress_test_robot != null:
		stress_test_robot.modulate = robot_lights_off_modulate if _stress_test_dark else robot_lights_on_modulate


func _on_end_button_pressed() -> void:
	DayCycle.register_stress_test_completed()
	finish(0, 0, -10, {}, false)


func _on_wake_button_pressed() -> void:
	DayCycle.register_stress_test_wake()


func _on_give_up_button_pressed() -> void:
	finish(0, 0, 0, {}, false)
