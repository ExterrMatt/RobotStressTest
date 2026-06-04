extends Control

signal pulled

const LINK_SIZE: Vector2 = Vector2(13.0, 2.0)
const BULB_SIZE: Vector2 = Vector2(13.0, 18.0)

@export var pull_texture: Texture2D
@export var visible_link_count: int = 41
@export var gravity: float = 9.8
@export var pixels_per_meter: float = 100.0
@export var damping: float = 0.94
@export var return_strength: float = 80.0
@export var constraint_iterations: int = 28
@export var hitbox_radius: float = 18.0
@export var drag_slack_links: int = 4

var _total_link_count: int = 41
var _active_link_count: int = 41
var _points: Array[Vector2] = []
var _previous_points: Array[Vector2] = []
var _link_sprites: Array[Sprite2D] = []
var _bulb_sprite: Sprite2D = null
var _bulb_position: Vector2 = Vector2.ZERO
var _previous_bulb_position: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _settling: bool = false
var _drag_target: Vector2 = Vector2.ZERO
var _pulled_past_rest_radius: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_visuals()
	_reset_physics()
	set_process_input(true)
	set_physics_process(false)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return

		var local_position := _global_to_local(mouse_event.global_position)
		if mouse_event.pressed:
			if _is_over_bulb(local_position):
				_start_drag(local_position)
				get_viewport().set_input_as_handled()
		elif _dragging:
			_release_drag()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _dragging:
		_set_drag_target(_global_to_local((event as InputEventMouseMotion).global_position))
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	var clamped_delta := minf(delta, 1.0 / 30.0)
	_simulate(clamped_delta)
	_solve_chain_constraints()
	_update_visuals()

	if not _dragging:
		if _pulled_past_rest_radius:
			_pulled_past_rest_radius = false
			pulled.emit()
		if _active_link_count > visible_link_count \
				and _bulb_position.distance_to(_rest_bulb_position()) <= 1.0:
			_collapse_to_visible_links()
		if _is_settled():
			_reset_physics()
			set_physics_process(false)


func _build_visuals() -> void:
	for child in get_children():
		child.queue_free()

	_link_sprites.clear()
	_bulb_sprite = null
	if pull_texture == null:
		return

	var texture_size := pull_texture.get_size()
	_total_link_count = maxi(1, int(floor((texture_size.y - BULB_SIZE.y) / LINK_SIZE.y)))
	visible_link_count = clampi(visible_link_count, 1, _total_link_count)
	_active_link_count = visible_link_count

	for i in range(_total_link_count):
		var link := Sprite2D.new()
		link.name = "ChainLink%02d" % (i + 1)
		link.centered = true
		link.texture = _atlas_region(Rect2(0.0, i * LINK_SIZE.y, LINK_SIZE.x, LINK_SIZE.y))
		link.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(link)
		_link_sprites.append(link)

	_bulb_sprite = Sprite2D.new()
	_bulb_sprite.name = "Bulb"
	_bulb_sprite.centered = true
	_bulb_sprite.texture = _atlas_region(Rect2(0.0, texture_size.y - BULB_SIZE.y, BULB_SIZE.x, BULB_SIZE.y))
	_bulb_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_bulb_sprite)


func _atlas_region(region: Rect2) -> AtlasTexture:
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = pull_texture
	atlas_texture.region = region
	return atlas_texture


func _reset_physics() -> void:
	_points.clear()
	_previous_points.clear()
	_active_link_count = visible_link_count

	var anchor := _anchor_position()
	for i in range(_total_link_count + 1):
		var point := anchor + Vector2(0.0, i * LINK_SIZE.y)
		_points.append(point)
		_previous_points.append(point)

	_bulb_position = _rest_bulb_position()
	_previous_bulb_position = _bulb_position
	_points[_active_link_count] = _bulb_top_position()
	_previous_points[_active_link_count] = _points[_active_link_count]

	_dragging = false
	_settling = false
	_pulled_past_rest_radius = false
	_update_visuals()


func _start_drag(local_position: Vector2) -> void:
	_dragging = true
	_settling = true
	_set_drag_target(local_position)
	set_physics_process(true)


func _release_drag() -> void:
	_dragging = false
	_settling = true
	set_physics_process(true)


func _set_drag_target(local_position: Vector2) -> void:
	var anchor_to_target := local_position - _anchor_position()
	if anchor_to_target.length() > _max_stretch_radius():
		local_position = _anchor_position() + anchor_to_target.normalized() * _max_stretch_radius()

	_drag_target = local_position
	_set_active_link_count(_link_count_for_bulb_position(_drag_target))


func _set_active_link_count(value: int) -> void:
	var next_count := clampi(value, visible_link_count, _total_link_count)
	if next_count <= _active_link_count:
		return

	var old_count := _active_link_count
	_active_link_count = next_count
	var old_end := _points[old_count]
	var new_end := _bulb_top_position()
	for i in range(old_count + 1, _active_link_count + 1):
		var t := float(i - old_count) / float(_active_link_count - old_count + 1)
		_points[i] = old_end.lerp(new_end, t)
		_previous_points[i] = _points[i]


func _collapse_to_visible_links() -> void:
	_active_link_count = visible_link_count
	for i in range(_active_link_count + 1):
		_points[i] = _rest_chain_position(i)
		_previous_points[i] = _points[i]
	_bulb_position = _rest_bulb_position()
	_previous_bulb_position = _bulb_position


func _link_count_for_bulb_position(bulb_position: Vector2) -> int:
	var required := int(ceil(maxf(0.0, bulb_position.distance_to(_anchor_position()) - BULB_SIZE.y * 0.5) / LINK_SIZE.y))
	if bulb_position.distance_to(_anchor_position()) > _rest_radius():
		required += drag_slack_links
	return required


func _simulate(delta: float) -> void:
	for i in range(1, _active_link_count):
		var point := _points[i]
		var previous := _previous_points[i]
		var velocity := (point - previous) * damping
		var acceleration := Vector2(0.0, gravity * pixels_per_meter)

		if _settling and not _dragging:
			acceleration += (_rest_chain_position(i) - point) * return_strength

		_previous_points[i] = point
		_points[i] = point + velocity + acceleration * delta * delta

	if _dragging:
		_bulb_position = _drag_target
		_previous_bulb_position = _drag_target
		if _bulb_position.distance_to(_anchor_position()) > _rest_radius():
			_pulled_past_rest_radius = true
	else:
		var bulb_velocity := (_bulb_position - _previous_bulb_position) * damping
		var bulb_acceleration := Vector2(0.0, gravity * pixels_per_meter)
		if _settling:
			bulb_acceleration += (_rest_bulb_position() - _bulb_position) * return_strength
		_previous_bulb_position = _bulb_position
		_bulb_position += bulb_velocity + bulb_acceleration * delta * delta

	_points[_active_link_count] = _bulb_top_position()
	_previous_points[_active_link_count] = _points[_active_link_count]


func _solve_chain_constraints() -> void:
	if _points.is_empty():
		return

	for _iteration in range(constraint_iterations):
		_points[0] = _anchor_position()
		_points[_active_link_count] = _bulb_top_position()
		for i in range(_active_link_count):
			_solve_distance_constraint(i, i + 1, LINK_SIZE.y)
	_points[0] = _anchor_position()
	_points[_active_link_count] = _bulb_top_position()


func _solve_distance_constraint(a_index: int, b_index: int, target_length: float) -> void:
	var a := _points[a_index]
	var b := _points[b_index]
	var delta := b - a
	var distance := delta.length()
	if distance <= 0.001:
		return

	var correction := delta * ((distance - target_length) / distance)
	if a_index == 0:
		_points[b_index] -= correction
		return
	if b_index == _active_link_count:
		_points[a_index] += correction
		return

	_points[a_index] += correction * 0.5
	_points[b_index] -= correction * 0.5


func _update_visuals() -> void:
	if _points.is_empty():
		return

	for i in range(_link_sprites.size()):
		var link := _link_sprites[i]
		link.visible = i < _active_link_count
		if not link.visible:
			continue
		var start := _points[i]
		var end := _points[i + 1]
		link.position = (start + end) * 0.5
		link.rotation = (end - start).angle() - PI * 0.5

	if _bulb_sprite != null:
		_bulb_sprite.position = _bulb_position
		_bulb_sprite.rotation = (_anchor_position() - _bulb_position).angle() + PI * 0.5


func _bulb_top_position() -> Vector2:
	var to_anchor := _anchor_position() - _bulb_position
	if to_anchor.length() <= 0.001:
		to_anchor = Vector2.UP
	return _bulb_position + to_anchor.normalized() * (BULB_SIZE.y * 0.5)


func _rest_chain_position(index: int) -> Vector2:
	return _anchor_position() + Vector2(0.0, index * LINK_SIZE.y)


func _rest_bulb_position() -> Vector2:
	return _anchor_position() + Vector2(0.0, _rest_radius())


func _rest_radius() -> float:
	return visible_link_count * LINK_SIZE.y + BULB_SIZE.y * 0.5


func _max_stretch_radius() -> float:
	return _total_link_count * LINK_SIZE.y + BULB_SIZE.y * 0.5


func _is_over_bulb(local_position: Vector2) -> bool:
	return local_position.distance_to(_bulb_position) <= hitbox_radius


func _anchor_position() -> Vector2:
	return Vector2(size.x * 0.5, 0.0)


func _global_to_local(global_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * global_position


func _is_settled() -> bool:
	if _dragging:
		return false
	if _active_link_count != visible_link_count:
		return false
	for i in range(_active_link_count + 1):
		if _points[i].distance_to(_rest_chain_position(i)) > 0.15:
			return false
		if _points[i].distance_to(_previous_points[i]) > 0.15:
			return false
	if _bulb_position.distance_to(_rest_bulb_position()) > 0.15:
		return false
	if _bulb_position.distance_to(_previous_bulb_position) > 0.15:
		return false
	return true
