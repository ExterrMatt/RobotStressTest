@tool
extends Control
class_name WorkshopPiece
## Visual layer + draggable for ingredient tiles. Post-CRAFT, pieces get
## wrapped inside a WorkshopSegment which handles its own drag — see
## WorkshopMinigame._pick_up_segment / _pick_up_piece for the split.

const SHADOW_MODULATE: Color = Color(1, 1, 1, 0.5)
const CENTER_ON_GRAB_DURATION: float = 0.05

@export var item_id: StringName = &""
@export var segment_id: StringName = &""

@export var texture: Texture2D:
	set(value):
		texture = value
		if texture and size == Vector2.ZERO:
			size = texture.get_size()
		queue_redraw()

@export var shadow_texture: Texture2D:
	set(value):
		shadow_texture = value
		queue_redraw()

@export var outline_texture: Texture2D:
	set(value):
		outline_texture = value
		queue_redraw()

@export_group("Offsets & Drawing")
@export var visual_offset: Vector2 = Vector2.ZERO:
	set(value):
		visual_offset = value if typeof(value) == TYPE_VECTOR2 else Vector2.ZERO
		queue_redraw()

@export var shadow_offset: Vector2 = Vector2.ZERO:
	set(value):
		shadow_offset = value if typeof(value) == TYPE_VECTOR2 else Vector2.ZERO
		queue_redraw()

@export var visual_scale: float = 1.0:
	set(value):
		visual_scale = max(0.001, value)
		queue_redraw()

@export var auto_center: bool = false:
	set(value):
		auto_center = value
		queue_redraw()

@export var auto_top_center: bool = false:
	set(value):
		auto_top_center = value
		queue_redraw()


var piece_offset: Vector2 = Vector2.ZERO
var home_parent: Control = null
var locked: bool = false

var _dragging: bool = false
var _grab_offset: Vector2 = Vector2.ZERO
var _last_drag_global_pos: Vector2 = Vector2.ZERO
var _grab_offset_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if _dragging:
		_apply_drag_position()


func _draw() -> void:
	var s_off: Vector2 = shadow_offset if typeof(shadow_offset) == TYPE_VECTOR2 else Vector2.ZERO

	# Only draw the local shadow in the editor so authoring still looks right.
	# At runtime, WorkshopMinigame renders all shadows in a unified CanvasGroup.
	if shadow_texture and Engine.is_editor_hint():
		draw_texture_rect(
			shadow_texture,
			Rect2(texture_draw_position(shadow_texture) + s_off, texture_draw_size(shadow_texture)),
			false,
			SHADOW_MODULATE
		)

	if outline_texture and _should_draw_outline():
		draw_texture_rect(
			outline_texture,
			Rect2(texture_draw_position(outline_texture), texture_draw_size(outline_texture)),
			false
		)

	if texture:
		draw_texture_rect(texture, Rect2(texture_draw_position(texture), texture_draw_size(texture)), false)


func texture_draw_size(draw_texture: Texture2D = null) -> Vector2:
	var tex: Texture2D = draw_texture if draw_texture != null else texture
	if tex == null:
		return Vector2.ZERO
	return tex.get_size() * visual_scale


func texture_draw_position(draw_texture: Texture2D = null) -> Vector2:
	var tex: Texture2D = draw_texture if draw_texture != null else texture
	if tex == null:
		return Vector2.ZERO
	var v_off: Vector2 = visual_offset if typeof(visual_offset) == TYPE_VECTOR2 else Vector2.ZERO
	var draw_size: Vector2 = texture_draw_size(tex)
	if auto_top_center:
		return Vector2((size.x - draw_size.x) * 0.5, 0.0) + v_off
	if auto_center:
		return (size - draw_size) / 2.0 + v_off
	return v_off


func hit_test(global_pos: Vector2) -> bool:
	if locked or not visible or not is_visible_in_tree():
		return false
	return _global_texture_hit_rect().has_point(global_pos)


func _global_texture_hit_rect() -> Rect2:
	var local_rect := _local_texture_hit_rect()
	var transform := get_global_transform()
	var points := [
		transform * local_rect.position,
		transform * Vector2(local_rect.end.x, local_rect.position.y),
		transform * local_rect.end,
		transform * Vector2(local_rect.position.x, local_rect.end.y),
	]
	var hit_rect := Rect2(points[0], Vector2.ZERO)
	for i in range(1, points.size()):
		hit_rect = hit_rect.expand(points[i])
	return hit_rect


func _local_texture_hit_rect() -> Rect2:
	if texture == null:
		return Rect2(Vector2.ZERO, size)

	var draw_position := texture_draw_position(texture)
	var image := texture.get_image()
	if image == null or image.is_empty():
		return Rect2(draw_position, texture_draw_size(texture))

	var used_rect := image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return Rect2(draw_position, texture_draw_size(texture))

	return Rect2(
		draw_position + Vector2(used_rect.position) * visual_scale,
		Vector2(used_rect.size) * visual_scale
	)


func start_drag(global_pos: Vector2) -> void:
	_dragging = true
	_last_drag_global_pos = global_pos
	_grab_offset = global_pos - global_position
	_slide_grab_offset_to_center()


func update_drag(global_pos: Vector2) -> void:
	if not _dragging:
		return
	_last_drag_global_pos = global_pos
	_apply_drag_position()


func end_drag() -> void:
	_dragging = false
	_kill_grab_offset_tween()


func is_dragging() -> bool:
	return _dragging


func _should_draw_outline() -> bool:
	if locked:
		return false
	var n: Node = get_parent()
	while n != null:
		if n is WorkshopSegment:
			return not n.locked
		n = n.get_parent()
	return true


func place_in(slot: Control, at_position: Vector2) -> void:
	_dragging = false
	_kill_grab_offset_tween()
	if get_parent() != slot:
		_reparent_keeping_global(slot)
	position = at_position


func snap_home() -> void:
	if home_parent == null:
		return
	_dragging = false
	_kill_grab_offset_tween()
	if get_parent() != home_parent:
		_reparent_keeping_global(home_parent)
	var target: Vector2 = (home_parent.size - size) * 0.5
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", target, 0.18)


func _reparent_keeping_global(new_parent: Control) -> void:
	var global_pos: Vector2 = global_position
	var current_parent: Node = get_parent()
	if current_parent:
		current_parent.remove_child(self)
	new_parent.add_child(self)
	global_position = global_pos


func _apply_drag_position() -> void:
	global_position = _last_drag_global_pos - _grab_offset


func _slide_grab_offset_to_center() -> void:
	_kill_grab_offset_tween()
	_grab_offset_tween = create_tween()
	_grab_offset_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_grab_offset_tween.tween_property(self, "_grab_offset", _global_center_offset(), CENTER_ON_GRAB_DURATION)


func _global_center_offset() -> Vector2:
	return get_global_transform() * (size * 0.5) - global_position


func _kill_grab_offset_tween() -> void:
	if _grab_offset_tween and _grab_offset_tween.is_valid():
		_grab_offset_tween.kill()
	_grab_offset_tween = null
