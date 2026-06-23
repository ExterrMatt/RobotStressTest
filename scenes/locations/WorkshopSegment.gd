@tool
extends Control
class_name WorkshopSegment
## A draggable group of WorkshopPieces that move as one unit.
##
## After CRAFT, the minigame wraps each segment's pieces in one of these
## and scatters it in the bin. The player grabs the segment by clicking
## anywhere inside its `grab_hitbox_rect` (the BLUE debug rect) and drags
## the whole group. Pieces stay laid out exactly as they were authored
## under the slot — no offsets to fight.
##
## Pairs with WorkshopAssemblySlot (the GOAL, green debug rect) by
## matching segment_id <-> accepts_segment_id. They are positionally
## independent: moving one does not move the other.


const CENTER_ON_GRAB_DURATION: float = 0.05

@export var segment_id: StringName = &""

## True once placed on its goal. Locked segments ignore clicks.
var locked: bool = false:
	set(value):
		locked = value
		_queue_piece_redraws()

## Other segments that must be dragged and dropped together with this one.
## Populated by WorkshopMinigame from the paired_with property on the
## owning slot. Always symmetric — if A.pair_partners contains B then
## B.pair_partners contains A.
var pair_partners: Array = []

## Local offset restored when the compact spawned segment is placed into
## its authored assembly slot.
var placement_offset: Vector2 = Vector2.ZERO


@export_group("Hitbox")
## Tight clickable rect in LOCAL coords. The player can grab the segment
## anywhere inside this rect.
##
## Default Rect2() (size 0,0) falls back to the full Control rect.
##
## Workflow:
##  1. Parent every WorkshopPiece of this segment under this node, laid
##     out so the art lines up correctly.
##  2. Tick `auto_fit_grab_hitbox` — it unions every child piece's
##     non-transparent pixel bounds into one tight rect.
##  3. Turn on `debug_draw_hitbox` to see the BLUE rect.
##  4. Hand-tune the four values if you want tighter.
@export var grab_hitbox_rect: Rect2 = Rect2():
	set(value):
		grab_hitbox_rect = value if typeof(value) == TYPE_RECT2 else Rect2()
		queue_redraw()

## Show the grab hitbox in BLUE.
@export var debug_draw_hitbox: bool = false:
	set(value):
		debug_draw_hitbox = value
		queue_redraw()

## Editor-only one-shot: unions every child WorkshopPiece's non-transparent
## bounds into a single tight grab hitbox. Resets to false after firing.
@export var auto_fit_grab_hitbox: bool = false:
	set(value):
		if value:
			_auto_fit_grab_hitbox()
		auto_fit_grab_hitbox = false


# --- Drag state ---
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
	if not debug_draw_hitbox:
		return
	var r: Rect2 = _effective_local_hitbox()
	draw_rect(r, Color(0.2, 0.6, 1.0, 0.22), true)
	draw_rect(r, Color(0.1, 0.5, 1.0, 0.95), false, 2.0)


func _effective_local_hitbox() -> Rect2:
	if grab_hitbox_rect.size.x > 0.0 and grab_hitbox_rect.size.y > 0.0:
		return grab_hitbox_rect
	return Rect2(Vector2.ZERO, size)


func get_global_hitbox() -> Rect2:
	var local: Rect2 = _effective_local_hitbox()
	var xform: Transform2D = get_global_transform()
	var top_left: Vector2 = xform * local.position
	var bottom_right: Vector2 = xform * (local.position + local.size)
	return Rect2(top_left, bottom_right - top_left).abs()


func hit_test(global_pos: Vector2) -> bool:
	if locked or not visible or not is_visible_in_tree():
		return false
	return get_global_hitbox().has_point(global_pos)


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


func _apply_drag_position() -> void:
	global_position = _last_drag_global_pos - _grab_offset


func _slide_grab_offset_to_center() -> void:
	_kill_grab_offset_tween()
	_grab_offset_tween = create_tween()
	_grab_offset_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_grab_offset_tween.tween_property(self, "_grab_offset", _global_center_offset(), CENTER_ON_GRAB_DURATION)


func _global_center_offset() -> Vector2:
	return get_global_transform() * _effective_local_hitbox().get_center() - global_position


func _kill_grab_offset_tween() -> void:
	if _grab_offset_tween and _grab_offset_tween.is_valid():
		_grab_offset_tween.kill()
	_grab_offset_tween = null


func _queue_piece_redraws() -> void:
	for child in get_children():
		if child is WorkshopPiece:
			child.queue_redraw()


# -----------------------------------------------------------------------------
# Auto-fit grab hitbox to the union of every child piece's visible art.
# -----------------------------------------------------------------------------
func _auto_fit_grab_hitbox() -> void:
	var union_rect: Rect2 = Rect2()
	var found_any: bool = false

	for child in get_children():
		if not (child is WorkshopPiece):
			continue
		var piece: WorkshopPiece = child
		if piece.texture == null:
			continue

		var img: Image = piece.texture.get_image()
		if img == null:
			push_warning("WorkshopSegment '%s': piece '%s' has no CPU image data. Check texture import (keep Lossless, or enable Keep Image On Import)." % [name, piece.name])
			continue

		var used: Rect2i = img.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			continue

		var tex_pos_in_piece: Vector2 = piece.visual_offset
		if piece.auto_center:
			tex_pos_in_piece = (piece.size - piece.texture.get_size()) / 2.0

		var piece_rect_in_segment: Rect2 = Rect2(
			piece.position + tex_pos_in_piece + Vector2(used.position),
			Vector2(used.size)
		)

		if not found_any:
			union_rect = piece_rect_in_segment
			found_any = true
		else:
			union_rect = union_rect.merge(piece_rect_in_segment)

	if not found_any:
		push_warning("WorkshopSegment '%s': no usable child piece textures to auto-fit from." % name)
		return

	grab_hitbox_rect = union_rect
	queue_redraw()
