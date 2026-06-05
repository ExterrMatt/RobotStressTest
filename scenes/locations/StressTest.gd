extends LocationBase

const ZOOM_LEVEL_OUT: int = 0
const ZOOM_LEVEL_FIRST: int = 1
const ZOOM_LEVEL_SECOND: int = 2
const MAX_ZOOM_LEVEL: int = ZOOM_LEVEL_SECOND
const FIRST_ZOOM_GRID_SIZE: Vector2i = Vector2i(5, 4)
const SECOND_ZOOM_GRID_SIZE: Vector2i = Vector2i(4, 5)
const FIRST_ZOOM_SCALE: Vector2 = Vector2(2.0, 2.0)
const SECOND_ZOOM_SCALE: Vector2 = Vector2(3.0, 3.0)
const ZOOMED_OUT_SCALE: Vector2 = Vector2.ONE
const BASE_SCENE_SIZE: Vector2 = Vector2(800.0, 600.0)
const PAN_DURATION: float = 0.35
const PAN_TRANS: int = Tween.TRANS_SINE
const PAN_EASE: int = Tween.EASE_IN_OUT
const ZOOM_DURATION: float = 0.35
const MIDDLE_LEFT_COLUMN: int = 1
const MIDDLE_LEFT_COLUMN_SOURCE_OFFSET_X: float = -20.0
const TOP_VIEW_OVERSCAN_PX: float = 38.0
const BOTTOM_VIEW_OVERSCAN_PX: float = 37.0
@export var robot_lights_on_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var robot_lights_off_modulate: Color = Color(0.3, 0.3, 0.3, 1.0)

@onready var camera_window: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow
@onready var scene_canvas: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas
@onready var light_placeholder: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder
@onready var dark_placeholder: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/DarkPlaceholder
@onready var pull_cord: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/PullCord
@onready var stress_test_robot: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/StressTestRobot

var _grid_cell: Vector2i = Vector2i(2, 2)
var _zoom_level: int = ZOOM_LEVEL_FIRST
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
			_set_zoom_level(_zoom_level - 1)
			get_viewport().set_input_as_handled()
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom_level(_zoom_level + 1)
			get_viewport().set_input_as_handled()
			return

	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	var key_event := event as InputEventKey
	if key_event.keycode == KEY_Z:
		_set_zoom_level((_zoom_level + 1) % (MAX_ZOOM_LEVEL + 1))
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

	_move_grid_cell(direction)
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
	scene_canvas.scale = _current_zoom_scale() * _canvas_base_scale
	_apply_grid_cell(false)


func _move_grid_cell(direction: Vector2i) -> void:
	if not _is_zoomed_in():
		return

	var grid_size := _current_grid_size()
	var next_cell := Vector2i(
		clampi(_grid_cell.x + direction.x, 0, grid_size.x - 1),
		clampi(_grid_cell.y + direction.y, 0, grid_size.y - 1)
	)
	if next_cell == _grid_cell:
		return

	_grid_cell = next_cell
	_apply_grid_cell(true)


func _set_zoom_level(value: int) -> void:
	var next_zoom_level := clampi(value, ZOOM_LEVEL_OUT, MAX_ZOOM_LEVEL)
	if _zoom_level == next_zoom_level:
		return

	var old_grid_size := _current_grid_size()
	var old_grid_cell := _grid_cell
	_zoom_level = next_zoom_level
	if _is_zoomed_in():
		_grid_cell = _grid_cell_for_zoom_change(old_grid_cell, old_grid_size, _current_grid_size())

	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()

	var target_scale := _current_zoom_scale()
	var target_position := _grid_position_for_scale(target_scale) if _is_zoomed_in() else _default_canvas_position()

	_zoom_tween = create_tween()
	_zoom_tween.set_parallel(true)
	_zoom_tween.set_trans(PAN_TRANS)
	_zoom_tween.set_ease(PAN_EASE)
	_zoom_tween.tween_property(scene_canvas, "scale", target_scale * _canvas_base_scale, ZOOM_DURATION)
	_zoom_tween.tween_property(scene_canvas, "position", target_position, ZOOM_DURATION)


func _apply_grid_cell(animated: bool) -> void:
	var logical_scale := _current_zoom_scale()
	var target_position := _grid_position_for_scale(logical_scale) if _is_zoomed_in() else _default_canvas_position()

	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()

	if not animated:
		scene_canvas.position = target_position
		return

	_pan_tween = create_tween()
	_pan_tween.set_trans(PAN_TRANS)
	_pan_tween.set_ease(PAN_EASE)
	_pan_tween.tween_property(scene_canvas, "position", target_position, PAN_DURATION)


func _grid_position_for_scale(scale_value: Vector2) -> Vector2:
	var display_scale := scale_value * _canvas_base_scale
	var visible_size := Vector2(
		camera_window.size.x / maxf(display_scale.x, 0.001),
		camera_window.size.y / maxf(display_scale.y, 0.001)
	)
	var max_source_offset := Vector2(
		maxf(0.0, BASE_SCENE_SIZE.x - visible_size.x),
		maxf(0.0, BASE_SCENE_SIZE.y - visible_size.y)
	)

	var grid_size := _current_grid_size()
	if grid_size.x <= 1 or grid_size.y <= 1:
		return _default_canvas_position()

	var source_offset := Vector2(
		_grid_offset_x(max_source_offset.x, grid_size),
		_grid_offset_y(max_source_offset.y, grid_size)
	)
	return Vector2(
		-source_offset.x * display_scale.x,
		-source_offset.y * display_scale.y
	)


func _grid_offset_x(max_offset_x: float, grid_size: Vector2i) -> float:
	var offset := (float(_grid_cell.x) / float(grid_size.x - 1)) * max_offset_x
	if _grid_cell.x == MIDDLE_LEFT_COLUMN:
		offset += MIDDLE_LEFT_COLUMN_SOURCE_OFFSET_X
	return clampf(offset, 0.0, max_offset_x)


func _grid_offset_y(max_offset_y: float, grid_size: Vector2i) -> float:
	var fraction := float(_grid_cell.y) / float(grid_size.y - 1)
	var overscan_range := max_offset_y + TOP_VIEW_OVERSCAN_PX + BOTTOM_VIEW_OVERSCAN_PX
	return -TOP_VIEW_OVERSCAN_PX + fraction * overscan_range


func _on_camera_window_resized() -> void:
	_apply_default_canvas_transform()
	if _is_zoomed_in():
		scene_canvas.scale = _current_zoom_scale() * _canvas_base_scale
		_apply_grid_cell(false)
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
	match _zoom_level:
		ZOOM_LEVEL_SECOND:
			return SECOND_ZOOM_SCALE
		ZOOM_LEVEL_FIRST:
			return FIRST_ZOOM_SCALE
		_:
			return ZOOMED_OUT_SCALE


func _current_grid_size() -> Vector2i:
	match _zoom_level:
		ZOOM_LEVEL_SECOND:
			return SECOND_ZOOM_GRID_SIZE
		ZOOM_LEVEL_FIRST:
			return FIRST_ZOOM_GRID_SIZE
		_:
			return Vector2i.ONE


func _is_zoomed_in() -> bool:
	return _zoom_level > ZOOM_LEVEL_OUT


func _grid_cell_for_zoom_change(old_cell: Vector2i, old_grid_size: Vector2i, new_grid_size: Vector2i) -> Vector2i:
	if old_grid_size.x <= 1 or old_grid_size.y <= 1:
		return Vector2i(new_grid_size.x / 2, new_grid_size.y / 2)

	var x_fraction := float(old_cell.x) / float(old_grid_size.x - 1)
	var y_fraction := float(old_cell.y) / float(old_grid_size.y - 1)
	return Vector2i(
		clampi(roundi(x_fraction * float(new_grid_size.x - 1)), 0, new_grid_size.x - 1),
		clampi(roundi(y_fraction * float(new_grid_size.y - 1)), 0, new_grid_size.y - 1)
	)


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
