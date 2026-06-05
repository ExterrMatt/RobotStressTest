extends Control

signal pulled

const LINK_SIZE: Vector2 = Vector2(13.0, 2.0)
const BULB_SIZE: Vector2 = Vector2(13.0, 18.0)

@export var pull_texture: Texture2D
@export var visible_link_count: int = 41
@export var max_pull_radius: float = 0.0
@export var gravity: float = 9.8
@export var pixels_per_meter: float = 100.0
@export var damping: float = 0.98
@export var return_strength: float = 24.0
@export var release_spring_strength: float = 34.0
@export var release_velocity_drag: float = 1.2
@export var settle_horizontal_strength: float = 4.0
@export var settle_vertical_strength: float = 16.0
@export var tautness_start_radius_scale: float = 0.8
@export var tautness_end_radius_scale: float = 1.2
@export var pull_toggle_radius_scale: float = 1.0
@export var slack_release_radius_scale: float = 1.0
@export var return_reset_velocity_threshold: float = 0.6
@export var return_reset_distance_threshold: float = 4.0
@export var return_reset_still_time: float = 0.35
@export var constraint_iterations: int = 28
@export var hitbox_radius: float = 24.0

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
var _returning_pendulum: bool = false
var _bulb_velocity: Vector2 = Vector2.ZERO
var _return_still_elapsed: float = 0.0


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
	if _returning_pendulum:
		_simulate_pendulum_return(clamped_delta)
		_update_visuals()
		if _is_return_ready_to_reset():
			_reset_physics()
			set_physics_process(false)
		return

	_simulate(clamped_delta)
	_solve_chain_constraints()
	_apply_tautness_gradient()
	_update_visuals()

	if not _dragging:
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
	_returning_pendulum = false
	_bulb_velocity = Vector2.ZERO
	_return_still_elapsed = 0.0
	_update_visuals()


func _start_drag(local_position: Vector2) -> void:
	_dragging = true
	_settling = true
	_returning_pendulum = false
	_bulb_velocity = Vector2.ZERO
	_return_still_elapsed = 0.0
	_set_drag_target(local_position)
	set_physics_process(true)


func _release_drag() -> void:
	_dragging = false
	_settling = true
	var should_toggle := _bulb_position.distance_to(_anchor_position()) > _pull_toggle_radius()
	if should_toggle:
		pulled.emit()
	if _bulb_position.distance_to(_anchor_position()) > _slack_release_radius():
		_start_pendulum_return()
	else:
		_bulb_velocity = Vector2.ZERO
		_previous_bulb_position = _bulb_position
	set_physics_process(true)


func _start_pendulum_return() -> void:
	_returning_pendulum = true
	_bulb_velocity = Vector2.ZERO
	_return_still_elapsed = 0.0
	_previous_bulb_position = _bulb_position
	_update_release_chain(0.0)


func _set_drag_target(local_position: Vector2) -> void:
	var anchor_to_target := local_position - _anchor_position()
	if anchor_to_target.length() > _max_stretch_radius():
		local_position = _anchor_position() + anchor_to_target.normalized() * _max_stretch_radius()

	_drag_target = local_position
	_update_active_link_count_for_bulb()


func _update_active_link_count_for_bulb() -> void:
	var next_count := _link_count_for_bulb_position(_bulb_position)
	if next_count == _active_link_count:
		return

	var old_count := _active_link_count
	_active_link_count = next_count

	if _active_link_count > old_count:
		var old_end := _points[old_count]
		var new_end := _bulb_top_position()
		for i in range(old_count + 1, _active_link_count + 1):
			var t := float(i - old_count) / float(_active_link_count - old_count)
			_points[i] = old_end.lerp(new_end, t)
			_previous_points[i] = _points[i]
		return

	_points[_active_link_count] = _bulb_top_position()
	_previous_points[_active_link_count] = _points[_active_link_count]


func _link_count_for_bulb_position(bulb_position: Vector2) -> int:
	var distance := bulb_position.distance_to(_anchor_position())
	if distance <= _rest_radius():
		return visible_link_count
	var required := int(ceil(maxf(0.0, distance - BULB_SIZE.y * 0.5) / LINK_SIZE.y))
	return clampi(required, visible_link_count, _total_link_count)


func _simulate(delta: float) -> void:
	for i in range(1, _active_link_count):
		var point := _points[i]
		var previous := _previous_points[i]
		var velocity := (point - previous) * damping
		var acceleration := Vector2.ZERO

		if _settling and not _dragging:
			acceleration += (_rest_chain_position(i) - point) * return_strength
		else:
			acceleration += Vector2(0.0, gravity * pixels_per_meter)

		_previous_points[i] = point
		_points[i] = point + velocity + acceleration * delta * delta

	if _dragging:
		_bulb_position = _drag_target
		_previous_bulb_position = _drag_target
	else:
		var bulb_velocity := (_bulb_position - _previous_bulb_position) * damping
		var bulb_acceleration := Vector2.ZERO
		if _settling:
			bulb_acceleration += (_rest_bulb_position() - _bulb_position) * return_strength
		else:
			bulb_acceleration += Vector2(0.0, gravity * pixels_per_meter)
		_previous_bulb_position = _bulb_position
		_bulb_position += bulb_velocity + bulb_acceleration * delta * delta

	_update_active_link_count_for_bulb()
	_points[_active_link_count] = _bulb_top_position()
	_previous_points[_active_link_count] = _points[_active_link_count]


func _simulate_pendulum_return(delta: float) -> void:
	var offset := _bulb_position - _anchor_position()
	var distance := offset.length()
	var direction := offset / distance if distance > 0.001 else Vector2.DOWN
	var stretch := distance - _rest_radius()
	var gravity_acceleration := Vector2(0.0, gravity * pixels_per_meter)
	var acceleration := gravity_acceleration - direction * gravity_acceleration.dot(direction)
	acceleration += direction * (-release_spring_strength * stretch)
	var rest_offset := _rest_bulb_position() - _bulb_position
	acceleration.x += rest_offset.x * settle_horizontal_strength
	acceleration.y += rest_offset.y * settle_vertical_strength
	acceleration -= _bulb_velocity * release_velocity_drag

	_bulb_velocity += acceleration * delta
	_previous_bulb_position = _bulb_position
	_bulb_position += _bulb_velocity * delta
	_constrain_bulb_to_maximum_radius()
	_update_release_chain(delta)
	_update_return_still_time(delta)


func _update_return_still_time(delta: float) -> void:
	if _bulb_velocity.length() <= return_reset_velocity_threshold:
		_return_still_elapsed += delta
	else:
		_return_still_elapsed = 0.0


func _constrain_bulb_to_maximum_radius() -> void:
	var offset := _bulb_position - _anchor_position()
	var distance := offset.length()
	var max_radius := _max_stretch_radius()
	if distance <= max_radius or distance <= 0.001:
		return

	var direction := offset / distance
	_bulb_position = _anchor_position() + direction * max_radius
	var outward_speed := _bulb_velocity.dot(direction)
	if outward_speed > 0.0:
		_bulb_velocity -= direction * outward_speed


func _update_release_chain(delta: float) -> void:
	_update_active_link_count_for_bulb()

	for i in range(1, _active_link_count):
		var point := _points[i]
		var previous := _previous_points[i]
		var velocity := (point - previous) * damping
		var acceleration := Vector2(0.0, gravity * pixels_per_meter)
		_previous_points[i] = point
		_points[i] = point + velocity + acceleration * delta * delta
	_solve_chain_constraints()
	_apply_tautness_gradient()


func _apply_tautness_gradient() -> void:
	var tautness := _tautness_for_bulb_position(_bulb_position)
	if tautness <= 0.0:
		return

	var anchor := _anchor_position()
	var bulb_top := _bulb_top_position()
	for i in range(_active_link_count + 1):
		var t := float(i) / float(maxi(1, _active_link_count))
		var taut_point := anchor.lerp(bulb_top, t)
		_points[i] = _points[i].lerp(taut_point, tautness)
		if i == 0 or i == _active_link_count:
			_previous_points[i] = _points[i]
		else:
			_previous_points[i] = _previous_points[i].lerp(taut_point, tautness)


func _tautness_for_bulb_position(bulb_position: Vector2) -> float:
	var rest_radius := _rest_radius()
	var start_radius := rest_radius * tautness_start_radius_scale
	var end_radius := rest_radius * tautness_end_radius_scale
	if end_radius <= start_radius:
		return 1.0

	var distance := bulb_position.distance_to(_anchor_position())
	var t := clampf((distance - start_radius) / (end_radius - start_radius), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


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


func _pull_toggle_radius() -> float:
	return _rest_radius() * pull_toggle_radius_scale


func _slack_release_radius() -> float:
	return _rest_radius() * slack_release_radius_scale


func _max_stretch_radius() -> float:
	var texture_max_radius := _total_link_count * LINK_SIZE.y + BULB_SIZE.y * 0.5
	if max_pull_radius <= 0.0:
		return texture_max_radius
	return minf(max_pull_radius, texture_max_radius)


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


func _is_return_ready_to_reset() -> bool:
	if _return_still_elapsed < return_reset_still_time:
		return false
	if _bulb_position.distance_to(_rest_bulb_position()) > return_reset_distance_threshold:
		return false
	return true
