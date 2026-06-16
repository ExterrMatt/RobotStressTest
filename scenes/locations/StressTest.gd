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

@export_group("Night Timer")
@export var night_duration_seconds: float = 60.0
@export var timer_label_text: String = "Time"

@export_group("Electricity Meter")
@export var electricity_label_text: String = "Electricity"
@export var electricity_start_percent: float = 0.0
@export var electricity_ripcord_gain_percent: float = 20.0
@export var electricity_decay_percent_per_second: float = 6.0
@export var electricity_lights_off_decay_multiplier: float = 2.0
@export var electricity_wake_threshold_percent: float = 130.0

@export_group("Darkness Effects")
@export var screw_repair_lights_off_duration_multiplier: float = 2.0

@export_group("Gas Meter")
@export var gas_label_text: String = "Gas"
@export var gas_start_percent: float = 50.0
@export var gas_optimal_start_percent: float = 50.0
@export var gas_optimal_min_percent: float = 25.0
@export var gas_optimal_max_percent: float = 75.0
@export_range(0, 20, 1) var gas_optimal_event_count_min: int = 5
@export_range(0, 20, 1) var gas_optimal_event_count_max: int = 10
@export_range(0, 40, 1) var gas_drift_event_count_min: int = 10
@export_range(0, 40, 1) var gas_drift_event_count_max: int = 20
@export var gas_drift_change_percent: float = 5.0
@export var gas_valve_wheel_step_percent: float = 5.0
@export var gas_valve_drag_percent_per_pixel: float = 0.15
@export var gas_low_failure_percent: float = 0.0
@export var gas_high_failure_percent: float = 100.0

@export_group("Emergency Power Shutoff")
@export var emergency_power_gas_target_percent: float = 50.0
@export var emergency_power_gas_equalize_units_per_second: float = 2.0
@export var emergency_power_electricity_decay_per_second: float = 50.0

@export_group("Window Alert")
@export_range(0, 3, 1) var window_alert_event_count_min: int = 0
@export_range(0, 3, 1) var window_alert_event_count_max: int = 3
@export var window_alert_light_seconds_min: float = 5.0
@export var window_alert_light_seconds_max: float = 10.0
@export var window_alert_indicator_lead_seconds: float = 3.0
@export var window_alert_spotted_light_remaining_seconds: float = 3.0
@export var window_alert_safe_silhouette_seconds: float = 3.0
@export var window_alert_late_safe_silhouette_seconds: float = 6.0
@export var window_alert_seen_failure_seconds: float = 3.0
@export var window_alert_indicator_flash_seconds: float = 0.35

@export_group("Failure Messages")
@export var gas_high_failure_text: String = "She woke up because you let the gas pressure rise too high."
@export var gas_low_failure_text: String = "She woke up because you let the gas pressure fall too low."
@export var electricity_failure_text: String = "She woke up because you over supplied her with electricity."
@export var uncle_failure_text: String = "Your uncle caught you."
@export var timeout_failure_text: String = "You ran out of time."
@export var wake_button_failure_text: String = "She woke up."

@export_group("Robot Position")
@export var head_only_drop_px: float = 57.0

@onready var camera_window: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow
@onready var scene_canvas: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas
@onready var first_zoom_regions: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/ZoomRegions/ZoomLevel1
@onready var second_zoom_regions: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/ZoomRegions/ZoomLevel2
@onready var light_placeholder: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder
@onready var dark_placeholder: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/DarkPlaceholder
@onready var window_light_on: CanvasItem = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/WindowLightOn
@onready var uncle_window: CanvasItem = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/UncleWindow
@onready var shed_light: CanvasItem = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/Light
@onready var shed_bulb: CanvasItem = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/LightPlaceholder/Bulb
@onready var pull_cord: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/PullCord
@onready var electrical_cord: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/ElectricalCord
@onready var stress_test_robot_shadow: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/StressTestRobotShadow
@onready var stress_test_robot: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/StressTestRobot
@onready var gas_valve: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/GasValve
@onready var emergency_power_button: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/EmergencyPowerButton
@onready var window_alert_rect: ColorRect = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/WindowAlertRect
@onready var window_alert_indicator: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/WindowAlertIndicator
@onready var timer_value_label: Label = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/StressHud/TimerLabel
@onready var electricity_value_label: Label = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/StressHud/ElectricityLabel
@onready var gas_value_label: Label = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/StressHud/GasLabel
@onready var uncle_value_label: Label = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/StressHud/UncleLabel
@onready var electricity_meter_groups: VBoxContainer = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/ElectricityMeter/ElectricityMeterGroups
@onready var failure_overlay: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/FailureOverlay
@onready var failure_reason_label: Label = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/FailureOverlay/FailurePanel/FailureVBox/FailureReasonLabel

var _zoom_level: int = ZOOM_LEVEL_FIRST
var _current_zoom_region: Control = null
var _pan_tween: Tween = null
var _zoom_tween: Tween = null
var _canvas_base_scale: float = 1.0
var _stress_test_dark: bool = false
var _night_elapsed: float = 0.0
var _night_finished: bool = false
var _electricity_percent: float = 0.0
var _gas_flow_percent: float = 50.0
var _gas_optimal_percent: float = 50.0
var _gas_last_change_percent: float = 0.0
var _emergency_power_shutoff_pressed: bool = false
var _gas_optimal_event_times: Array[float] = []
var _gas_drift_event_times: Array[float] = []
var _window_alert_event_times: Array[float] = []
var _gas_optimal_event_index: int = 0
var _gas_drift_event_index: int = 0
var _window_alert_event_index: int = 0
var _window_alert_state: int = WINDOW_ALERT_NONE
var _window_alert_elapsed: float = 0.0
var _window_alert_total_elapsed: float = 0.0
var _window_alert_light_duration: float = 5.0
var _window_alert_silhouette_leave_seconds: float = 3.0
var _window_alert_safe_elapsed: float = 0.0
var _window_alert_seen_elapsed: float = 0.0
var _dragging_gas_valve: bool = false
var _pending_failure_registers_wake: bool = false
var _failure_result_emitted: bool = false
var _rng := RandomNumberGenerator.new()
var _robot_base_position: Vector2
var _robot_shadow_base_position: Vector2

const WINDOW_ALERT_NONE: int = 0
const WINDOW_ALERT_YELLOW: int = 1
const WINDOW_ALERT_RED: int = 2


func _ready() -> void:
	_initialize_robot_position_state()
	_initialize_pull_cord()
	_initialize_stress_systems()
	_initialize_emergency_power_button()
	call_deferred("_initialize_zoom")


func _process(delta: float) -> void:
	if _night_finished:
		return

	_night_elapsed += delta
	_electricity_percent = maxf(0.0, _electricity_percent - _current_electricity_decay_per_second() * delta)
	if _electricity_percent <= 0.0 and _emergency_power_shutoff_pressed:
		_set_emergency_power_shutoff_pressed(false)
	_apply_scheduled_meter_events()
	_update_emergency_power_gas_equalization(delta)
	_update_window_alert(delta)
	_refresh_stress_hud()

	if _gas_flow_percent >= gas_high_failure_percent:
		_fail_stress_test(gas_high_failure_text, true)
		return
	if _gas_flow_percent <= gas_low_failure_percent:
		_fail_stress_test(gas_low_failure_text, true)
		return
	if _electricity_percent > electricity_wake_threshold_percent:
		_fail_stress_test(electricity_failure_text, true)
		return
	if _night_elapsed >= night_duration_seconds:
		_fail_stress_test(timeout_failure_text, false)


func _unhandled_input(event: InputEvent) -> void:
	if _handle_gas_valve_input(event):
		get_viewport().set_input_as_handled()
		return

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
	if pull_cord.has_signal("max_pull_reached"):
		var max_pull_callable := Callable(self, "_on_pull_cord_max_pull_reached")
		if not pull_cord.is_connected("max_pull_reached", max_pull_callable):
			pull_cord.connect("max_pull_reached", max_pull_callable)
	if electrical_cord != null and electrical_cord.has_signal("max_pull_reached"):
		var max_pull_callable := Callable(self, "_on_electrical_cord_max_pull_reached")
		if not electrical_cord.is_connected("max_pull_reached", max_pull_callable):
			electrical_cord.connect("max_pull_reached", max_pull_callable)
	_set_stress_test_dark(false)


func _on_pull_cord_max_pull_reached() -> void:
	_set_stress_test_dark(not _stress_test_dark)


func _set_stress_test_dark(value: bool) -> void:
	var was_dark := _stress_test_dark
	_stress_test_dark = value
	_apply_background_light_state()
	if stress_test_robot != null:
		stress_test_robot.modulate = robot_lights_off_modulate if _stress_test_dark else robot_lights_on_modulate
		if _stress_test_dark and not was_dark and stress_test_robot.has_method("reset_interactions_to_default"):
			stress_test_robot.call("reset_interactions_to_default")
	_apply_screw_repair_light_state()


func _apply_background_light_state() -> void:
	if light_placeholder != null:
		light_placeholder.visible = true
	if dark_placeholder != null:
		dark_placeholder.visible = _stress_test_dark
	if shed_light != null:
		shed_light.visible = not _stress_test_dark
	if shed_bulb != null:
		shed_bulb.visible = not _stress_test_dark


func _initialize_robot_position_state() -> void:
	if stress_test_robot != null:
		_robot_base_position = stress_test_robot.position
	if stress_test_robot_shadow != null:
		_robot_shadow_base_position = stress_test_robot_shadow.position

	var state := get_node_or_null("/root/GameState")
	if state != null and state.has_signal("robot_parts_changed"):
		var changed_callable := Callable(self, "_on_robot_parts_changed")
		if not state.is_connected("robot_parts_changed", changed_callable):
			state.connect("robot_parts_changed", changed_callable)

	_apply_robot_head_only_position()


func _on_robot_parts_changed(_parts: Dictionary) -> void:
	_apply_robot_head_only_position()


func _apply_robot_head_only_position() -> void:
	var head_only := _is_head_only_robot()
	var offset := Vector2(0.0, head_only_drop_px if head_only else 0.0)
	if stress_test_robot != null:
		stress_test_robot.position = _robot_base_position + offset
	if stress_test_robot_shadow != null:
		if stress_test_robot_shadow.has_method("set_head_only_shadow_enabled"):
			stress_test_robot_shadow.call("set_head_only_shadow_enabled", head_only)
		var shadow_profile_offset := Vector2.ZERO
		if stress_test_robot_shadow.has_method("get_shadow_position_offset"):
			shadow_profile_offset = stress_test_robot_shadow.call("get_shadow_position_offset")
		stress_test_robot_shadow.position = _robot_shadow_base_position + offset + shadow_profile_offset


func _is_head_only_robot() -> bool:
	return _robot_part_count("torso") <= 0 \
			and _robot_part_count("arm") <= 0 \
			and _robot_part_count("hand") <= 0 \
			and _robot_part_count("leg") <= 0


func _robot_part_count(id: String) -> int:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return 0
	if state.has_method("get_robot_part_count"):
		return int(state.call("get_robot_part_count", id))
	if id == "leg":
		return int(state.get("equipped_limbs"))
	return 0


func _initialize_stress_systems() -> void:
	_rng.randomize()
	_night_elapsed = 0.0
	_night_finished = false
	_electricity_percent = electricity_start_percent
	_gas_flow_percent = gas_start_percent
	_gas_optimal_percent = gas_optimal_start_percent
	_gas_last_change_percent = 0.0
	_set_emergency_power_shutoff_pressed(false)
	_gas_optimal_event_index = 0
	_gas_drift_event_index = 0
	_window_alert_event_index = 0
	_window_alert_state = WINDOW_ALERT_NONE
	_window_alert_elapsed = 0.0
	_window_alert_total_elapsed = 0.0
	_window_alert_light_duration = window_alert_light_seconds_min
	_window_alert_silhouette_leave_seconds = window_alert_safe_silhouette_seconds
	_window_alert_safe_elapsed = 0.0
	_window_alert_seen_elapsed = 0.0
	_dragging_gas_valve = false
	_pending_failure_registers_wake = false
	_failure_result_emitted = false

	var optimal_count := _random_event_count(gas_optimal_event_count_min, gas_optimal_event_count_max)
	var drift_count := _random_event_count(gas_drift_event_count_min, gas_drift_event_count_max)
	var alert_count := _random_event_count(window_alert_event_count_min, window_alert_event_count_max)
	_gas_optimal_event_times = _evenly_spaced_times(optimal_count, night_duration_seconds)
	_gas_drift_event_times = _evenly_spaced_times(drift_count, night_duration_seconds)
	_window_alert_event_times = _random_window_alert_times(alert_count)

	if window_alert_rect != null:
		window_alert_rect.visible = false
	if window_alert_indicator != null:
		window_alert_indicator.visible = false
	_apply_window_alert_visual_state()
	if failure_overlay != null:
		failure_overlay.visible = false
		failure_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	_set_robot_interaction_enabled(true)
	set_process(true)
	_refresh_stress_hud()


func _random_event_count(min_count: int, max_count: int) -> int:
	var low := maxi(0, mini(min_count, max_count))
	var high := maxi(0, max_count)
	if high < low:
		high = low
	return _rng.randi_range(low, high)


func _evenly_spaced_times(count: int, duration: float) -> Array[float]:
	var times: Array[float] = []
	if count <= 0 or duration <= 0.0:
		return times
	for i in range(count):
		times.append((float(i) + 1.0) * duration / (float(count) + 1.0))
	return times


func _random_window_alert_times(count: int) -> Array[float]:
	var times: Array[float] = []
	if count <= 0:
		return times
	var alert_duration := _window_alert_schedule_duration()
	var latest_start := maxf(0.0, night_duration_seconds - alert_duration - 0.5)
	if latest_start <= 0.0:
		return times
	for _i in range(count):
		times.append(_rng.randf_range(1.0, latest_start))
	times.sort()
	return times


func _apply_scheduled_meter_events() -> void:
	while _gas_optimal_event_index < _gas_optimal_event_times.size() and _night_elapsed >= _gas_optimal_event_times[_gas_optimal_event_index]:
		_gas_optimal_event_index += 1
		_gas_optimal_percent = _rng.randf_range(gas_optimal_min_percent, gas_optimal_max_percent)

	while _gas_drift_event_index < _gas_drift_event_times.size() and _night_elapsed >= _gas_drift_event_times[_gas_drift_event_index]:
		_gas_drift_event_index += 1
		var direction := _rng.randi_range(-1, 1)
		var amount := _rng.randf_range(0.0, gas_drift_change_percent)
		_apply_gas_flow_change(float(direction) * amount)


func _update_window_alert(delta: float) -> void:
	if _window_alert_state == WINDOW_ALERT_NONE:
		if _window_alert_event_index < _window_alert_event_times.size() and _night_elapsed >= _window_alert_event_times[_window_alert_event_index]:
			_window_alert_event_index += 1
			_start_window_alert()
		return

	_window_alert_elapsed += delta
	_window_alert_total_elapsed += delta
	if _window_alert_state == WINDOW_ALERT_YELLOW:
		_shorten_window_alert_light_if_spotted()
	if _window_alert_state == WINDOW_ALERT_YELLOW and _window_alert_elapsed >= _window_alert_light_duration:
		_window_alert_state = WINDOW_ALERT_RED
		_window_alert_elapsed = 0.0
		_window_alert_safe_elapsed = 0.0
		_window_alert_seen_elapsed = 0.0
		_window_alert_silhouette_leave_seconds = window_alert_late_safe_silhouette_seconds
		if not _is_uncle_exposure_active():
			_window_alert_silhouette_leave_seconds = window_alert_safe_silhouette_seconds
		_apply_window_alert_visual_state()
	if _window_alert_state == WINDOW_ALERT_RED:
		if _is_uncle_exposure_active():
			_window_alert_silhouette_leave_seconds = window_alert_late_safe_silhouette_seconds
			_window_alert_seen_elapsed += delta
			_window_alert_safe_elapsed = 0.0
			if _window_alert_seen_elapsed >= window_alert_seen_failure_seconds:
				_fail_stress_test(uncle_failure_text, false)
				if window_alert_indicator != null:
					window_alert_indicator.visible = false
				return
		else:
			_window_alert_safe_elapsed += delta
			if _window_alert_safe_elapsed >= _window_alert_silhouette_leave_seconds:
				_clear_window_alert()
				return
	_update_window_alert_indicator()


func _start_window_alert() -> void:
	_window_alert_state = WINDOW_ALERT_YELLOW
	_window_alert_elapsed = 0.0
	_window_alert_total_elapsed = 0.0
	_window_alert_safe_elapsed = 0.0
	_window_alert_seen_elapsed = 0.0
	_window_alert_light_duration = _random_window_alert_light_duration()
	_window_alert_silhouette_leave_seconds = window_alert_safe_silhouette_seconds
	if window_alert_rect != null:
		window_alert_rect.visible = false
	_apply_window_alert_visual_state()
	_update_window_alert_indicator()


func _clear_window_alert() -> void:
	_window_alert_state = WINDOW_ALERT_NONE
	_window_alert_elapsed = 0.0
	_window_alert_total_elapsed = 0.0
	_window_alert_safe_elapsed = 0.0
	_window_alert_seen_elapsed = 0.0
	_skip_elapsed_window_alert_events()
	if window_alert_rect != null:
		window_alert_rect.visible = false
	if window_alert_indicator != null:
		window_alert_indicator.visible = false
	_apply_window_alert_visual_state()


func _apply_window_alert_visual_state() -> void:
	if window_light_on != null:
		window_light_on.visible = _window_alert_state != WINDOW_ALERT_NONE
	if uncle_window != null:
		uncle_window.visible = _window_alert_state == WINDOW_ALERT_RED


func _skip_elapsed_window_alert_events() -> void:
	while _window_alert_event_index < _window_alert_event_times.size() \
			and _night_elapsed >= _window_alert_event_times[_window_alert_event_index]:
		_window_alert_event_index += 1


func _update_window_alert_indicator() -> void:
	if window_alert_indicator == null:
		return
	var should_show := _window_alert_state != WINDOW_ALERT_NONE \
			and _window_alert_total_elapsed >= _window_alert_indicator_start_time() \
			and not _is_window_alert_in_camera_view()
	var flash_duration := maxf(0.05, window_alert_indicator_flash_seconds)
	var flash_on := fmod(_window_alert_total_elapsed, flash_duration * 2.0) < flash_duration
	window_alert_indicator.visible = should_show and flash_on
	window_alert_indicator.modulate.a = 1.0


func _window_alert_indicator_start_time() -> float:
	return maxf(0.0, _window_alert_light_duration - window_alert_indicator_lead_seconds)


func _shorten_window_alert_light_if_spotted() -> void:
	if not _is_window_alert_in_camera_view():
		return
	var spotted_remaining := maxf(0.0, window_alert_spotted_light_remaining_seconds)
	var remaining := _window_alert_light_duration - _window_alert_elapsed
	if remaining > spotted_remaining:
		_window_alert_light_duration = _window_alert_elapsed + spotted_remaining


func _is_window_alert_in_camera_view() -> bool:
	if camera_window == null or window_alert_rect == null:
		return false
	return camera_window.get_global_rect().intersects(window_alert_rect.get_global_rect())


func _is_uncle_exposure_active() -> bool:
	return not _stress_test_dark or (_electricity_percent > 0.0 and not _emergency_power_shutoff_pressed)


func _random_window_alert_light_duration() -> float:
	var low := maxf(0.0, minf(window_alert_light_seconds_min, window_alert_light_seconds_max))
	var high := maxf(low, window_alert_light_seconds_max)
	return _rng.randf_range(low, high)


func _window_alert_schedule_duration() -> float:
	return maxf(0.0, window_alert_light_seconds_max) \
			+ maxf(0.0, window_alert_late_safe_silhouette_seconds) \
			+ maxf(0.0, window_alert_seen_failure_seconds)


func _on_electrical_cord_max_pull_reached() -> void:
	if _night_finished:
		return
	_electricity_percent += electricity_ripcord_gain_percent
	_refresh_stress_hud()


func _handle_gas_valve_input(event: InputEvent) -> bool:
	if gas_valve == null:
		return false

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed and _is_over_gas_valve(mouse_event.global_position):
				_dragging_gas_valve = true
				return true
			if not mouse_event.pressed and _dragging_gas_valve:
				_dragging_gas_valve = false
				return true

		if mouse_event.pressed and _is_over_gas_valve(mouse_event.global_position):
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_apply_gas_flow_change(gas_valve_wheel_step_percent)
				return true
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_apply_gas_flow_change(-gas_valve_wheel_step_percent)
				return true

	if event is InputEventMouseMotion and _dragging_gas_valve:
		var motion_event := event as InputEventMouseMotion
		_apply_gas_flow_change(-motion_event.relative.y * gas_valve_drag_percent_per_pixel)
		return true

	return false


func _is_over_gas_valve(global_position: Vector2) -> bool:
	return gas_valve != null and gas_valve.get_global_rect().has_point(global_position)


func _apply_gas_flow_change(delta_percent: float) -> void:
	_gas_last_change_percent = delta_percent
	_gas_flow_percent = clampf(_gas_flow_percent + delta_percent, gas_low_failure_percent, gas_high_failure_percent)
	_refresh_stress_hud()


func _initialize_emergency_power_button() -> void:
	if emergency_power_button == null or not emergency_power_button.has_signal("pressed"):
		return
	var pressed_callable := Callable(self, "_on_emergency_power_button_pressed")
	if not emergency_power_button.is_connected("pressed", pressed_callable):
		emergency_power_button.connect("pressed", pressed_callable)


func _on_emergency_power_button_pressed() -> void:
	if _night_finished:
		return
	_set_emergency_power_shutoff_pressed(true)
	_refresh_stress_hud()


func _set_emergency_power_shutoff_pressed(value: bool) -> void:
	_emergency_power_shutoff_pressed = value
	if emergency_power_button != null:
		emergency_power_button.set("is_pressed", value)


func _update_emergency_power_gas_equalization(delta: float) -> void:
	if not _emergency_power_shutoff_pressed:
		return
	var target := clampf(emergency_power_gas_target_percent, gas_low_failure_percent, gas_high_failure_percent)
	var previous := _gas_flow_percent
	_gas_flow_percent = move_toward(
		_gas_flow_percent,
		target,
		maxf(0.0, emergency_power_gas_equalize_units_per_second) * delta
	)
	_gas_last_change_percent = _gas_flow_percent - previous


func _refresh_stress_hud() -> void:
	if timer_value_label != null:
		timer_value_label.text = "%s: %s" % [timer_label_text, _format_remaining_time()]
	if electricity_value_label != null:
		electricity_value_label.text = "%s: %.0f%% (%+.1f%%/s)" % [
			electricity_label_text,
			_electricity_percent,
			-_current_electricity_decay_per_second(),
		]
	if gas_value_label != null:
		gas_value_label.text = "%s: %.0f%% / %.0f%% (%+.1f%%)" % [
			gas_label_text,
			_gas_flow_percent,
			_gas_optimal_percent,
			_gas_last_change_percent,
		]
	if uncle_value_label != null:
		uncle_value_label.text = _format_uncle_meter_text()
	_refresh_electricity_meter()


func _format_uncle_meter_text() -> String:
	var seen_limit := maxf(0.0, window_alert_seen_failure_seconds)
	var light_text := "--"
	if _window_alert_state == WINDOW_ALERT_YELLOW:
		var light_remaining := maxf(0.0, _window_alert_light_duration - _window_alert_elapsed)
		light_text = "%.1fs" % light_remaining
	var leave_text := "--"
	if _window_alert_state == WINDOW_ALERT_RED and not _is_uncle_exposure_active():
		var leave_remaining := maxf(0.0, _window_alert_silhouette_leave_seconds - _window_alert_safe_elapsed)
		leave_text = "%.1fs" % leave_remaining
	return "Light: %s | Seen: %.1f/%.1fs | Leaves: %s" % [
		light_text,
		_window_alert_seen_elapsed,
		seen_limit,
		leave_text,
	]


func _refresh_electricity_meter() -> void:
	var segments := _electricity_meter_segments()
	var visible_segment_count := clampi(int(ceil(_electricity_percent / 5.0)), 0, segments.size())
	var color := Color(0.1, 0.95, 0.18, 1.0)
	var completed_bar_count := int(floor(_electricity_percent / 20.0))
	if completed_bar_count >= 6:
		color = Color(1.0, 0.08, 0.04, 1.0)
	elif completed_bar_count >= 5:
		color = Color(1.0, 0.88, 0.08, 1.0)

	for i in range(segments.size()):
		var segment := segments[i]
		segment.visible = true
		segment.color = color if i < visible_segment_count else Color(0.0, 0.0, 0.0, 0.0)


func _electricity_meter_segments() -> Array[ColorRect]:
	var segments: Array[ColorRect] = []
	if electricity_meter_groups == null:
		return segments
	var groups := electricity_meter_groups.get_children()
	for group_index in range(groups.size() - 1, -1, -1):
		var group := groups[group_index]
		var group_segments := group.get_children()
		for segment_index in range(group_segments.size() - 1, -1, -1):
			var segment := group_segments[segment_index] as ColorRect
			if segment != null:
				segments.append(segment)
	return segments


func _format_remaining_time() -> String:
	var remaining := maxf(0.0, night_duration_seconds - _night_elapsed)
	var total_seconds := int(floor(remaining))
	var minutes := int(total_seconds / 60)
	var seconds := int(total_seconds % 60)
	var centiseconds := int(floor((remaining - float(total_seconds)) * 100.0))
	return "%02d:%02d.%02d" % [minutes, seconds, centiseconds]


func _current_electricity_decay_per_second() -> float:
	if _emergency_power_shutoff_pressed:
		return emergency_power_electricity_decay_per_second
	var multiplier := electricity_lights_off_decay_multiplier if _stress_test_dark else 1.0
	return electricity_decay_percent_per_second * multiplier


func _apply_screw_repair_light_state() -> void:
	var multiplier := screw_repair_lights_off_duration_multiplier if _stress_test_dark else 1.0
	for repair in _screw_repair_controllers():
		if repair.has_method("set_repair_animation_duration_multiplier"):
			repair.call("set_repair_animation_duration_multiplier", multiplier)


func _screw_repair_controllers() -> Array[Node]:
	var controllers: Array[Node] = []
	if stress_test_robot != null:
		_collect_screw_repair_controllers(stress_test_robot, controllers)
	return controllers


func _collect_screw_repair_controllers(node: Node, out: Array[Node]) -> void:
	for child in node.get_children():
		if child.has_method("set_repair_animation_duration_multiplier"):
			out.append(child)
		_collect_screw_repair_controllers(child, out)


func _complete_stress_test_success() -> void:
	if _night_finished:
		return
	_night_finished = true
	_set_robot_interaction_enabled(false)
	DayCycle.register_stress_test_completed()
	finish(0, 0, -10, {}, false)


func _fail_robot_wake() -> void:
	_fail_stress_test(wake_button_failure_text, true)


func _fail_stress_test(reason: String, registers_wake: bool) -> void:
	if _night_finished:
		return
	_night_finished = true
	_set_robot_interaction_enabled(false)
	_pending_failure_registers_wake = registers_wake
	_dragging_gas_valve = false
	_clear_window_alert()
	if failure_reason_label != null:
		failure_reason_label.text = reason
	if failure_overlay != null:
		failure_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		failure_overlay.visible = true
		get_tree().paused = true
	else:
		_finish_failed_stress_test()


func _finish_failed_stress_test() -> void:
	if _failure_result_emitted:
		return
	_failure_result_emitted = true
	get_tree().paused = false
	if _pending_failure_registers_wake:
		DayCycle.register_stress_test_wake()
		_pending_failure_registers_wake = false
	finish(0, 0, 0, {}, false)


func _on_end_button_pressed() -> void:
	_complete_stress_test_success()


func _on_wake_button_pressed() -> void:
	_fail_robot_wake()


func _on_give_up_button_pressed() -> void:
	if _night_finished:
		return
	_night_finished = true
	_set_robot_interaction_enabled(false)
	finish(0, 0, 0, {}, false)


func _on_failure_continue_button_pressed() -> void:
	_finish_failed_stress_test()


func _set_robot_interaction_enabled(value: bool) -> void:
	if stress_test_robot != null and stress_test_robot.has_method("set_interaction_enabled"):
		stress_test_robot.call("set_interaction_enabled", value)
