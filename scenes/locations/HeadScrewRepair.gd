@tool
extends Control

signal screw_loosened(index: int)
signal screw_repaired(index: int)

@export var enabled: bool = true
@export var screw_interval_seconds: float = 10.0
@export var repair_animation_seconds: float = 1.35
@export var repair_animation_fps: float = 10.0
@export var click_radius: float = 16.0
@export var randomize_screws: bool = true
@export var blocked_hover_box_paths: Array[NodePath] = []
@export var flipped_screwdriver_indices: Array = []
@export var screw_nodes: Array[NodePath] = []
@export var screwdriver_position_paths: Array[NodePath] = []
@export var screwdriver_sprite_path: NodePath = ^"Screwdriver"
@export var screwdriver_frame_size: Vector2i = Vector2i(48, 24)
@export var screwdriver_frame_count: int = 2

@export_group("Editor Preview")
@export_range(-1, 16, 1) var editor_preview_screw_index: int = -1:
	set(value):
		editor_preview_screw_index = value
		_refresh_editor_preview()
@export var editor_preview_screwdriver: bool = false:
	set(value):
		editor_preview_screwdriver = value
		_refresh_editor_preview()

var _rng := RandomNumberGenerator.new()
var _time_until_next_loose: float = 0.0
var _loose_screw_indices: Array = []
var _last_screw_index: int = -1
var _repairing: bool = false
var _repairing_screw_index: int = -1
var _repair_elapsed: float = 0.0
var _repair_animation_duration_multiplier: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_configure_screwdriver()
	_hide_all_screws()

	if Engine.is_editor_hint():
		_refresh_editor_preview()
		set_process(false)
		set_process_input(false)
		return

	_rng.randomize()
	_time_until_next_loose = maxf(0.1, screw_interval_seconds)
	set_process(enabled)
	set_process_input(enabled)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not enabled:
		return

	if _repairing:
		_update_repair_animation(delta)

	if _any_blocked_hover_box_active():
		return
	if _all_screws_loose():
		return

	_time_until_next_loose -= delta
	if _time_until_next_loose <= 0.0:
		if _loosen_next_screw():
			_time_until_next_loose = maxf(0.1, screw_interval_seconds)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not enabled or _repairing or _loose_screw_indices.is_empty():
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	var clicked_screw_index := _find_clicked_loose_screw(mouse_event.global_position)
	if clicked_screw_index < 0:
		return

	_start_repair_animation(clicked_screw_index)
	get_viewport().set_input_as_handled()


func _loosen_next_screw() -> bool:
	var available_indices := _available_screw_indices()
	if available_indices.is_empty():
		return false
	if _any_blocked_hover_box_active():
		return false

	var next_index := int(available_indices[0])
	if randomize_screws:
		next_index = int(available_indices[_rng.randi_range(0, available_indices.size() - 1)])
		if available_indices.size() > 1 and next_index == _last_screw_index:
			var next_position := (available_indices.find(next_index) + 1) % available_indices.size()
			next_index = int(available_indices[next_position])
	else:
		for index in available_indices:
			if int(index) > _last_screw_index:
				next_index = int(index)
				break

	_last_screw_index = next_index
	_loose_screw_indices.append(next_index)
	_set_screw_visible(next_index, true)
	screw_loosened.emit(next_index)
	return true


func blocks_hover_box(box: Control) -> bool:
	if box == null or not is_instance_valid(box):
		return false
	if _loose_screw_indices.is_empty():
		return false
	return _blocked_hover_boxes().has(box)


func set_repair_animation_duration_multiplier(value: float) -> void:
	_repair_animation_duration_multiplier = maxf(0.1, value)


func _start_repair_animation(screw_index: int) -> void:
	_repairing = true
	_repairing_screw_index = screw_index
	_repair_elapsed = 0.0
	var screwdriver := _get_screwdriver()
	if screwdriver != null:
		screwdriver.position = _screwdriver_position_for_index(screw_index)
		_apply_screwdriver_orientation(screw_index)
		screwdriver.visible = true
		_set_screwdriver_frame(0)


func _update_repair_animation(delta: float) -> void:
	_repair_elapsed += delta
	var frame := int(floor(_repair_elapsed * maxf(0.1, repair_animation_fps))) % maxi(1, screwdriver_frame_count)
	_set_screwdriver_frame(frame)

	if _repair_elapsed < _current_repair_animation_seconds():
		return

	var repaired_index := _repairing_screw_index
	_set_screw_visible(repaired_index, false)
	_loose_screw_indices.erase(repaired_index)
	_repairing = false
	_repairing_screw_index = -1
	_repair_elapsed = 0.0
	var screwdriver := _get_screwdriver()
	if screwdriver != null:
		screwdriver.visible = false
	screw_repaired.emit(repaired_index)


func _find_clicked_loose_screw(global_position: Vector2) -> int:
	var local_position := get_global_transform_with_canvas().affine_inverse() * global_position
	var nearest_index := -1
	var nearest_distance := INF
	for index in _loose_screw_indices:
		var distance := local_position.distance_to(_screwdriver_position_for_index(int(index)))
		if distance <= click_radius and distance < nearest_distance:
			nearest_index = int(index)
			nearest_distance = distance
	return nearest_index


func _current_repair_animation_seconds() -> float:
	return repair_animation_seconds * _repair_animation_duration_multiplier


func _configure_screwdriver() -> void:
	var screwdriver := _get_screwdriver()
	if screwdriver == null:
		return
	screwdriver.centered = false
	screwdriver.region_enabled = true
	_set_screwdriver_frame(0)
	screwdriver.visible = false


func _set_screwdriver_frame(frame: int) -> void:
	var screwdriver := _get_screwdriver()
	if screwdriver == null:
		return
	var frame_size := Vector2(
		float(maxi(1, screwdriver_frame_size.x)),
		float(maxi(1, screwdriver_frame_size.y))
	)
	var frame_count := maxi(1, screwdriver_frame_count)
	var clamped_frame := posmod(frame, frame_count)
	screwdriver.region_rect = Rect2(Vector2(0.0, float(clamped_frame) * frame_size.y), frame_size)
	var pivot_x := -frame_size.x if screwdriver.flip_h else 0.0
	screwdriver.offset = Vector2(pivot_x, -frame_size.y * 0.5)


func _apply_screwdriver_orientation(index: int) -> void:
	var screwdriver := _get_screwdriver()
	if screwdriver == null:
		return
	screwdriver.flip_h = _is_screwdriver_flipped(index)


func _is_screwdriver_flipped(index: int) -> bool:
	for value in flipped_screwdriver_indices:
		if int(value) == index:
			return true
	return false


func _hide_all_screws() -> void:
	_loose_screw_indices.clear()
	_repairing = false
	_repairing_screw_index = -1
	for i in range(screw_nodes.size()):
		_set_screw_visible(i, false)
	var screwdriver := _get_screwdriver()
	if screwdriver != null:
		screwdriver.visible = false


func _set_screw_visible(index: int, value: bool) -> void:
	if index < 0 or index >= screw_nodes.size():
		return
	var screw := get_node_or_null(screw_nodes[index]) as CanvasItem
	if screw == null:
		return
	screw.visible = value


func _screwdriver_position_for_index(index: int) -> Vector2:
	if index >= 0 and index < screwdriver_position_paths.size():
		var marker := get_node_or_null(screwdriver_position_paths[index])
		if marker is Node2D:
			return (marker as Node2D).position
		if marker is Control:
			var control := marker as Control
			return control.position + control.size * 0.5
	return size * 0.5


func _available_screw_indices() -> Array:
	var indices: Array = []
	for i in range(screw_nodes.size()):
		if not _loose_screw_indices.has(i):
			indices.append(i)
	return indices


func _all_screws_loose() -> bool:
	return screw_nodes.size() > 0 and _loose_screw_indices.size() >= screw_nodes.size()


func _get_screwdriver() -> Sprite2D:
	return get_node_or_null(screwdriver_sprite_path) as Sprite2D


func _any_blocked_hover_box_active() -> bool:
	for box in _blocked_hover_boxes():
		if box.has_method("is_effect_active") and bool(box.call("is_effect_active")):
			return true
	return false


func _blocked_hover_boxes() -> Array[Control]:
	var boxes: Array[Control] = []
	for path in blocked_hover_box_paths:
		var box := get_node_or_null(path) as Control
		if box != null:
			boxes.append(box)
	return boxes


func _refresh_editor_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_configure_screwdriver()
	_hide_all_screws()
	if editor_preview_screw_index >= 0:
		_set_screw_visible(editor_preview_screw_index, true)
	var screwdriver := _get_screwdriver()
	if screwdriver != null:
		screwdriver.visible = editor_preview_screwdriver and editor_preview_screw_index >= 0
		if screwdriver.visible:
			screwdriver.position = _screwdriver_position_for_index(editor_preview_screw_index)
			_apply_screwdriver_orientation(editor_preview_screw_index)
			_set_screwdriver_frame(0)
