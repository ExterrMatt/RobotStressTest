extends Control

signal pulled
signal max_pull_reached

const DEFAULT_LINK_SIZE: Vector2 = Vector2(13.0, 2.0)
const DEFAULT_BULB_SIZE: Vector2 = Vector2(13.0, 18.0)
const CORD_MODE_PULL_STRING: int = 0
const CORD_MODE_RIP_CORD: int = 1

@export var pull_texture: Texture2D
@export_enum("Pull String", "Rip Cord") var cord_mode: int = CORD_MODE_PULL_STRING
@export var link_size: Vector2 = DEFAULT_LINK_SIZE
@export var bulb_size: Vector2 = DEFAULT_BULB_SIZE
@export var visible_link_count: int = 41
@export var max_pull_radius: float = 0.0
@export var max_pull_rearm_distance: float = 8.0
@export var drag_soft_limit_radius: float = 36.0
@export_range(0.0, 1.0, 0.01) var drag_soft_limit_min_influence: float = 0.35
@export var rip_overpull_release_radius_scale: float = 1.25
@export var gravity: float = 9.8
@export var pixels_per_meter: float = 100.0
@export var damping: float = 0.98
@export var return_strength: float = 24.0
@export var rip_retract_strength: float = 900.0
@export var rip_retract_velocity_drag: float = 34.0
@export var release_spring_strength: float = 34.0
@export var release_velocity_drag: float = 1.2
@export var settle_horizontal_strength: float = 4.0
@export var settle_vertical_strength: float = 16.0
@export var bulb_pivot_gravity_strength: float = 22.0
@export var bulb_pivot_velocity_drag: float = 4.5
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
var _returning_rip_cord: bool = false
var _bulb_velocity: Vector2 = Vector2.ZERO
var _bulb_angle: float = 0.0
var _bulb_angular_velocity: float = 0.0
var _return_still_elapsed: float = 0.0
var _max_pull_reached_this_drag: bool = false
var _overpull_release_radius: float = 0.0


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
	if _returning_rip_cord:
		_simulate_rip_cord_return(clamped_delta)
		_update_visuals()
		if _is_rip_cord_return_ready_to_reset():
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
	_total_link_count = maxi(1, int(floor((texture_size.y - bulb_size.y) / link_size.y)))
	visible_link_count = clampi(visible_link_count, 1, _total_link_count)
	_active_link_count = visible_link_count

	for i in range(_total_link_count):
		var link := Sprite2D.new()
		link.name = "ChainLink%02d" % (i + 1)
		link.centered = true
		link.texture = _atlas_region(Rect2(0.0, i * link_size.y, link_size.x, link_size.y))
		link.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(link)
		_link_sprites.append(link)

	_bulb_sprite = Sprite2D.new()
	_bulb_sprite.name = "Bulb"
	_bulb_sprite.centered = not _bulb_uses_chain_pivot()
	if _bulb_uses_chain_pivot():
		_bulb_sprite.offset = Vector2(-bulb_size.x * 0.5, 0.0)
	_bulb_sprite.texture = _atlas_region(Rect2(0.0, texture_size.y - bulb_size.y, bulb_size.x, bulb_size.y))
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
	_active_link_count = _rest_link_count()

	var anchor := _anchor_position()
	for i in range(_total_link_count + 1):
		var point := anchor + Vector2(0.0, i * link_size.y)
		_points.append(point)
		_previous_points.append(point)

	_bulb_position = _rest_bulb_position()
	_previous_bulb_position = _bulb_position
	_points[_active_link_count] = _cord_end_position()
	_previous_points[_active_link_count] = _points[_active_link_count]

	_dragging = false
	_settling = false
	_returning_pendulum = false
	_returning_rip_cord = false
	_bulb_velocity = Vector2.ZERO
	_bulb_angle = 0.0
	_bulb_angular_velocity = 0.0
	_return_still_elapsed = 0.0
	_overpull_release_radius = 0.0
	_update_visuals()


func _start_drag(local_position: Vector2) -> void:
	_dragging = true
	_settling = true
	_returning_pendulum = false
	_returning_rip_cord = false
	_bulb_velocity = Vector2.ZERO
	_return_still_elapsed = 0.0
	_max_pull_reached_this_drag = false
	_overpull_release_radius = 0.0
	_set_drag_target(local_position)
	set_physics_process(true)


func _release_drag() -> void:
	_dragging = false
	_settling = true
	var should_toggle := _bulb_position.distance_to(_anchor_position()) > _pull_toggle_radius()
	if should_toggle:
		pulled.emit()
	if _is_rip_cord():
		_start_rip_cord_return()
		return
	if _bulb_position.distance_to(_anchor_position()) > _slack_release_radius():
		_start_pendulum_return()
	else:
		_bulb_velocity = Vector2.ZERO
		_previous_bulb_position = _bulb_position
	set_physics_process(true)


func _start_pendulum_return() -> void:
	_returning_pendulum = true
	_returning_rip_cord = false
	_bulb_velocity = Vector2.ZERO
	_return_still_elapsed = 0.0
	_previous_bulb_position = _bulb_position
	_update_release_chain(0.0)


func _start_rip_cord_return() -> void:
	_returning_rip_cord = true
	_returning_pendulum = false
	_bulb_velocity = (_bulb_position - _previous_bulb_position) * 30.0
	_return_still_elapsed = 0.0
	_sync_bulb_angle_to_current_cord_direction()
	_bulb_angular_velocity = clampf(_bulb_angular_velocity + (_bulb_position.x - _anchor_position().x) * 0.035, -10.0, 10.0)
	_update_rip_cord_retraction_chain()


func _set_drag_target(local_position: Vector2) -> void:
	var target_position := _bulb_pivot_position_for_center(local_position) if _bulb_uses_chain_pivot() else local_position
	_drag_target = _drag_limited_position(target_position)
	_emit_max_pull_reached_if_needed()
	if _bulb_uses_chain_pivot():
		_sync_bulb_angle_to_cord_direction(_drag_target)
	_update_active_link_count_for_bulb()
	if _should_release_from_overpull(target_position):
		_force_bulb_to_drag_target()
		_release_drag()


func _emit_max_pull_reached_if_needed() -> void:
	var distance_to_max := _max_stretch_radius() - _drag_target.distance_to(_anchor_position())
	if _max_pull_reached_this_drag and distance_to_max > max_pull_rearm_distance:
		_max_pull_reached_this_drag = false
		_overpull_release_radius = 0.0
	if _max_pull_reached_this_drag:
		return
	if distance_to_max > 0.25:
		return

	_max_pull_reached_this_drag = true
	_overpull_release_radius = _raw_drag_radius_for_max_pull() * maxf(1.0, rip_overpull_release_radius_scale)
	max_pull_reached.emit()


func _update_active_link_count_for_bulb() -> void:
	var next_count := _link_count_for_bulb_position(_bulb_position)
	if next_count == _active_link_count:
		return

	var old_count := _active_link_count
	_active_link_count = next_count

	if _active_link_count > old_count:
		var old_end := _points[old_count]
		var new_end := _cord_end_position()
		for i in range(old_count + 1, _active_link_count + 1):
			var t := float(i - old_count) / float(_active_link_count - old_count)
			_points[i] = old_end.lerp(new_end, t)
			_previous_points[i] = _points[i]
		return

	_points[_active_link_count] = _cord_end_position()
	_previous_points[_active_link_count] = _points[_active_link_count]


func _link_count_for_bulb_position(bulb_position: Vector2) -> int:
	var distance := _cord_distance_for_bulb_position(bulb_position)
	if distance <= _rest_radius():
		return _rest_link_count()
	var bulb_radius := 0.0 if _bulb_uses_chain_pivot() else bulb_size.y * 0.5
	var required := int(ceil(maxf(0.0, distance - bulb_radius) / link_size.y))
	return clampi(required, _rest_link_count(), _total_link_count)


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
		_previous_bulb_position = _bulb_position
		_bulb_position = _drag_target
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
	_points[_active_link_count] = _cord_end_position()
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


func _simulate_rip_cord_return(delta: float) -> void:
	var anchor := _anchor_position()
	var to_anchor := anchor - _bulb_position
	var acceleration := to_anchor * rip_retract_strength - _bulb_velocity * rip_retract_velocity_drag
	_bulb_velocity += acceleration * delta
	_previous_bulb_position = _bulb_position
	_bulb_position += _bulb_velocity * delta
	if _bulb_position.distance_to(anchor) <= return_reset_distance_threshold and _bulb_velocity.length() <= return_reset_velocity_threshold * 30.0:
		_bulb_position = anchor
		_bulb_velocity = Vector2.ZERO
		_previous_bulb_position = anchor

	_update_active_link_count_for_bulb()
	_update_rip_cord_retraction_chain()

	_simulate_bulb_pivot_rotation(delta)
	_update_return_still_time(delta)


func _simulate_bulb_pivot_rotation(delta: float) -> void:
	var angular_acceleration := -sin(_bulb_angle) * bulb_pivot_gravity_strength
	angular_acceleration -= _bulb_angular_velocity * bulb_pivot_velocity_drag
	_bulb_angular_velocity += angular_acceleration * delta
	_bulb_angle += _bulb_angular_velocity * delta


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
	if _active_link_count <= 0:
		_points[0] = _anchor_position()
		_previous_points[0] = _points[0]
		return

	for i in range(1, _active_link_count):
		var point := _points[i]
		var previous := _previous_points[i]
		var velocity := (point - previous) * damping
		var acceleration := Vector2(0.0, gravity * pixels_per_meter)
		_previous_points[i] = point
		_points[i] = point + velocity + acceleration * delta * delta
	_solve_chain_constraints()
	_apply_tautness_gradient()


func _update_rip_cord_retraction_chain() -> void:
	if _active_link_count <= 0:
		_points[0] = _anchor_position()
		_previous_points[0] = _points[0]
		return

	var anchor := _anchor_position()
	var cord_end := _cord_end_position()
	for i in range(_active_link_count + 1):
		var t := float(i) / float(maxi(1, _active_link_count))
		_points[i] = anchor.lerp(cord_end, t)
		_previous_points[i] = _points[i]


func _apply_tautness_gradient() -> void:
	if _active_link_count <= 0:
		return
	var tautness := _tautness_for_bulb_position(_bulb_position)
	if tautness <= 0.0:
		return

	var anchor := _anchor_position()
	var bulb_top := _cord_end_position()
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
	if _active_link_count <= 0:
		_points[0] = _anchor_position()
		_previous_points[0] = _points[0]
		return

	for _iteration in range(constraint_iterations):
		_points[0] = _anchor_position()
		_points[_active_link_count] = _cord_end_position()
		for i in range(_active_link_count):
			_solve_distance_constraint(i, i + 1, link_size.y)
	_points[0] = _anchor_position()
	_points[_active_link_count] = _cord_end_position()


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
		if _bulb_uses_chain_pivot():
			_bulb_sprite.rotation = _bulb_angle
		else:
			_bulb_sprite.rotation = (_anchor_position() - _bulb_position).angle() + PI * 0.5


func _drag_limited_position(local_position: Vector2) -> Vector2:
	var anchor := _anchor_position()
	var anchor_to_target := local_position - anchor
	var distance := anchor_to_target.length()
	var max_radius := _max_stretch_radius()
	if distance <= 0.001:
		return anchor
	if not _is_rip_cord():
		if distance <= max_radius:
			return local_position
		return anchor + anchor_to_target.normalized() * max_radius

	var soft_radius := minf(maxf(0.0, drag_soft_limit_radius), max_radius)
	var soft_start := max_radius - soft_radius
	if soft_radius <= 0.001:
		if distance <= max_radius:
			return local_position
		return anchor + anchor_to_target.normalized() * max_radius
	if distance <= soft_start:
		return local_position
	var extra_distance := distance - soft_start
	var min_influence := clampf(drag_soft_limit_min_influence, 0.0, 1.0)
	var t := minf(extra_distance / soft_radius, 1.0)
	var smooth_integral := t - (1.0 - min_influence) * ((t * t * t) - (0.5 * t * t * t * t))
	var eased_extra := soft_radius * smooth_integral
	if extra_distance > soft_radius:
		eased_extra += (extra_distance - soft_radius) * min_influence
	var eased_radius := minf(max_radius, soft_start + eased_extra)
	if max_radius - eased_radius <= 0.25:
		eased_radius = max_radius
	return anchor + anchor_to_target.normalized() * eased_radius


func _should_release_from_overpull(target_position: Vector2) -> bool:
	if not _dragging or not _is_rip_cord():
		return false
	if not _max_pull_reached_this_drag or _overpull_release_radius <= 0.0:
		return false

	var release_scale := maxf(0.0, rip_overpull_release_radius_scale)
	if release_scale <= 0.0:
		return false

	return target_position.distance_to(_anchor_position()) > _overpull_release_radius


func _raw_drag_radius_for_max_pull() -> float:
	var anchor := _anchor_position()
	var max_radius := _max_stretch_radius()
	var target_radius := maxf(0.0, max_radius - 0.25)
	var low := 0.0
	var high := maxf(1.0, max_radius)

	while _drag_limited_position(anchor + Vector2.DOWN * high).distance_to(anchor) < target_radius:
		low = high
		high *= 2.0
		if high >= max_radius * 16.0:
			return high

	for _i in range(20):
		var mid := (low + high) * 0.5
		if _drag_limited_position(anchor + Vector2.DOWN * mid).distance_to(anchor) >= target_radius:
			high = mid
		else:
			low = mid

	return high


func _force_bulb_to_drag_target() -> void:
	_previous_bulb_position = _bulb_position
	_bulb_position = _drag_target
	_update_active_link_count_for_bulb()
	_points[_active_link_count] = _cord_end_position()
	_previous_points[_active_link_count] = _points[_active_link_count]


func _sync_bulb_angle_to_current_cord_direction() -> void:
	_sync_bulb_angle_to_cord_direction(_bulb_position)


func _sync_bulb_angle_to_cord_direction(position: Vector2) -> void:
	var offset := position - _anchor_position()
	if offset.length() <= 0.001:
		return
	_bulb_angle = offset.angle() - PI * 0.5


func _bulb_pivot_position_for_center(center_position: Vector2) -> Vector2:
	var anchor := _anchor_position()
	var anchor_to_center := center_position - anchor
	var distance := anchor_to_center.length()
	if distance <= 0.001:
		return anchor

	var direction := anchor_to_center / distance
	return anchor + direction * maxf(0.0, distance - bulb_size.y * 0.5)


func _bulb_top_position() -> Vector2:
	var to_anchor := _anchor_position() - _bulb_position
	if to_anchor.length() <= 0.001:
		to_anchor = Vector2.UP
	return _bulb_position + to_anchor.normalized() * (bulb_size.y * 0.5)


func _cord_end_position() -> Vector2:
	if _bulb_uses_chain_pivot():
		return _bulb_position
	return _bulb_top_position()


func _rest_chain_position(index: int) -> Vector2:
	return _anchor_position() + Vector2(0.0, index * link_size.y)


func _rest_bulb_position() -> Vector2:
	return _anchor_position() + Vector2(0.0, _rest_radius())


func _rest_radius() -> float:
	var bulb_radius := 0.0 if _bulb_uses_chain_pivot() else bulb_size.y * 0.5
	return _rest_link_count() * link_size.y + bulb_radius


func _rest_link_count() -> int:
	return 0 if _is_rip_cord() else visible_link_count


func _pull_toggle_radius() -> float:
	return _rest_radius() * pull_toggle_radius_scale


func _slack_release_radius() -> float:
	return _rest_radius() * slack_release_radius_scale


func _max_stretch_radius() -> float:
	var texture_max_radius := _total_link_count * link_size.y + bulb_size.y * 0.5
	if max_pull_radius <= 0.0:
		return texture_max_radius
	return minf(max_pull_radius, texture_max_radius)


func _is_over_bulb(local_position: Vector2) -> bool:
	if _bulb_uses_chain_pivot():
		var bulb_center := _bulb_position + Vector2(0.0, bulb_size.y * 0.5).rotated(_bulb_angle)
		return local_position.distance_to(bulb_center) <= hitbox_radius
	return local_position.distance_to(_bulb_position) <= hitbox_radius


func _anchor_position() -> Vector2:
	return Vector2(size.x * 0.5, 0.0)


func _global_to_local(global_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * global_position


func _is_settled() -> bool:
	if _dragging:
		return false
	if _active_link_count != _rest_link_count():
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


func _is_rip_cord_return_ready_to_reset() -> bool:
	if _return_still_elapsed < return_reset_still_time:
		return false
	if _active_link_count != _rest_link_count():
		return false
	if _bulb_position.distance_to(_rest_bulb_position()) > return_reset_distance_threshold:
		return false
	if absf(_bulb_angle) > 0.04:
		return false
	if absf(_bulb_angular_velocity) > 0.12:
		return false
	return true


func _cord_distance_for_bulb_position(bulb_position: Vector2) -> float:
	if _bulb_uses_chain_pivot():
		return bulb_position.distance_to(_anchor_position())
	return bulb_position.distance_to(_anchor_position())


func _is_rip_cord() -> bool:
	return cord_mode == CORD_MODE_RIP_CORD


func _bulb_uses_chain_pivot() -> bool:
	return _is_rip_cord()
