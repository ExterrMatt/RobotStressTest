@tool
extends Control
class_name WorkshopAssemblySlot
## The GOAL/target zone where a segment is supposed to be dropped.
##
## In the editor you author this slot with its segment's pieces parented
## underneath, exactly as before. At runtime the minigame pulls those
## pieces out and bundles them into a WorkshopSegment for dragging — the
## slot stays empty as a pure goal target.
##
## The GREEN debug rect is the goal hitbox. It's positionally independent
## from the WorkshopSegment (which draws BLUE). Moving the goal does not
## move the segment, and vice versa.

signal placed(slot: WorkshopAssemblySlot)


@export var accepts_segment_id: StringName = &""


@export_group("Hitbox")
## Tight drop-zone rect in LOCAL coords. A drop counts as landing on this
## goal if the release point is inside this rect.
##
## Default Rect2() falls back to the full Control rect.
@export var hitbox_rect: Rect2 = Rect2():
	set(value):
		hitbox_rect = value if typeof(value) == TYPE_RECT2 else Rect2()
		queue_redraw()

## Show the goal hitbox in GREEN (orange once filled).
@export var debug_draw: bool = false:
	set(value):
		debug_draw = value
		queue_redraw()

## Editor-only one-shot: snap hitbox_rect to the union of every child
## piece's non-transparent bounds. Useful right after authoring pieces
## under the slot, before the minigame strips them at runtime.
@export var auto_fit_goal_hitbox: bool = false:
	set(value):
		if value:
			_auto_fit_from_child_pieces()
		auto_fit_goal_hitbox = false


## True once a segment has been placed on this goal.
var filled: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if not debug_draw:
		return
	var r: Rect2 = _effective_local_hitbox()
	var color: Color = Color(0.2, 1.0, 0.4, 0.30) if not filled else Color(1.0, 0.6, 0.2, 0.30)
	draw_rect(r, color, true)
	draw_rect(r, Color(0, 0, 0, 0.7), false, 2.0)


func _effective_local_hitbox() -> Rect2:
	if hitbox_rect.size.x > 0.0 and hitbox_rect.size.y > 0.0:
		return hitbox_rect
	return Rect2(Vector2.ZERO, size)


func get_global_hitbox() -> Rect2:
	var local: Rect2 = _effective_local_hitbox()
	var xform: Transform2D = get_global_transform()
	var top_left: Vector2 = xform * local.position
	var bottom_right: Vector2 = xform * (local.position + local.size)
	return Rect2(top_left, bottom_right - top_left).abs()


## Does this segment match what we accept AND did the drop land in our hitbox?
func is_valid_drop_for_segment(segment, release_global_pos: Vector2) -> bool:
	if filled:
		return false
	if segment.segment_id != accepts_segment_id:
		return false
	return get_global_hitbox().has_point(release_global_pos)


## Legacy compatibility — old code may still call this with a piece.
func is_valid_drop(piece: WorkshopPiece, release_global_pos: Vector2) -> bool:
	if filled:
		return false
	if piece.segment_id != accepts_segment_id:
		return false
	return get_global_hitbox().has_point(release_global_pos)


## Called by the minigame when a matching segment is dropped on us.
func accept_segment(segment) -> void:
	if filled:
		return
	filled = true
	segment.locked = true

	if segment.get_parent() != self:
		var gp: Vector2 = segment.global_position
		var current_parent: Node = segment.get_parent()
		if current_parent:
			current_parent.remove_child(segment)
		add_child(segment)
		segment.global_position = gp

	segment.position = Vector2.ZERO

	queue_redraw()
	placed.emit(self)


## Legacy — lays each provided piece out at its own position under us.
func place_segment(all_pieces: Array) -> void:
	if filled:
		return
	filled = true

	for piece in all_pieces:
		if not (piece is WorkshopPiece):
			continue
		if piece.get_parent() != self:
			var current_parent: Node = piece.get_parent()
			if current_parent:
				current_parent.remove_child(piece)
			add_child(piece)
		piece.position = piece.piece_offset
		piece.locked = true

	queue_redraw()
	placed.emit(self)


# -----------------------------------------------------------------------------
# Auto-fit goal hitbox from the slot's currently parented pieces.
# -----------------------------------------------------------------------------
func _auto_fit_from_child_pieces() -> void:
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
			push_warning("WorkshopAssemblySlot '%s': piece '%s' has no CPU image data." % [name, piece.name])
			continue

		var used: Rect2i = img.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			continue

		var v_off: Vector2 = piece.visual_offset if typeof(piece.visual_offset) == TYPE_VECTOR2 else Vector2.ZERO
		var tex_pos_in_piece: Vector2 = v_off
		if piece.auto_center:
			tex_pos_in_piece = (piece.size - piece.texture.get_size()) / 2.0

		var piece_rect_in_slot: Rect2 = Rect2(
			piece.position + tex_pos_in_piece + Vector2(used.position),
			Vector2(used.size)
		)

		if not found_any:
			union_rect = piece_rect_in_slot
			found_any = true
		else:
			union_rect = union_rect.merge(piece_rect_in_slot)

	if not found_any:
		push_warning("WorkshopAssemblySlot '%s': no usable child piece textures to auto-fit from. (Slot has no WorkshopPiece children with a texture set.)" % name)
		return

	hitbox_rect = union_rect
	queue_redraw()
