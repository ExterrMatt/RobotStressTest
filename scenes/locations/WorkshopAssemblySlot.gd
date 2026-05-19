extends Control
class_name WorkshopAssemblySlot
## A single segment's home on the assembly side of the workshop.
##
## A segment may consist of one or more pieces (see LegSegmentData). The
## slot accepts a piece if `piece.segment_id == accepts_segment_id`. When
## ANY piece of that segment is dropped onto the slot, the minigame
## calls `place_segment()` and we lay every piece of the segment out at
## its authored offset.
##
## Unlike Work's DropSlot, which holds a single sprite and toggles a
## pre-authored "revealed" panel, this slot OWNS the placed pieces — we
## reparent them under us. That way they inherit the same coordinate
## space as the slot's anchor and any per-piece offsets we apply just
## work.

signal placed(slot: WorkshopAssemblySlot)


@export var accepts_segment_id: StringName = &""

## For debug — flips a colored rect so we can see hitbox bounds in dev.
@export var debug_draw: bool = false

## True once the segment has been placed. The minigame uses this to
## determine when the leg is complete (all assembly slots filled).
var filled: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if not debug_draw:
		return
	var color: Color = Color(0.2, 1.0, 0.4, 0.35) if not filled else Color(1.0, 0.6, 0.2, 0.35)
	draw_rect(Rect2(Vector2.ZERO, size), color, true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.7), false, 2.0)


## Does this piece belong to this slot's segment, AND did the drop
## actually land on us?
func is_valid_drop(piece: WorkshopPiece, release_global_pos: Vector2) -> bool:
	if filled:
		return false
	if piece.segment_id != accepts_segment_id:
		return false
	return get_global_rect().has_point(release_global_pos)


## Mark filled and lay out the pieces. `all_pieces` is the array of every
## WorkshopPiece in the bin that belongs to this segment — the minigame
## gathers them and hands them in so we don't need to know about the bin.
##
## Each piece's `piece_offset` is applied relative to OUR top-left.
func place_segment(all_pieces: Array) -> void:
	if filled:
		return
	filled = true

	for piece in all_pieces:
		if not (piece is WorkshopPiece):
			continue
		_attach_piece(piece)

	queue_redraw()
	placed.emit(self)


func _attach_piece(piece: WorkshopPiece) -> void:
	# Reparent under the slot, positioned at the piece's authored offset.
	# Locked pieces don't respond to clicks anymore — once a segment is
	# placed it stays placed.
	if piece.get_parent() != self:
		var current_parent: Node = piece.get_parent()
		if current_parent:
			current_parent.remove_child(piece)
		add_child(piece)
	piece.position = piece.piece_offset
	piece.locked = true
