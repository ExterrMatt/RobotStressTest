extends Control
class_name WorkshopBin
## The bottom-left craft bin where the player drops ingredients before
## pressing CRAFT, and where leg-segment pieces spawn after CRAFT fires.
##
## Unlike DropSlot (which holds exactly one item of one id), the bin
## accepts any draggable and just keeps a list of what's inside. The
## minigame queries this list when CRAFT is pressed.
##
## Layout:
##   - On the .tscn side, this is a fixed-size Control. The minigame
##     positions it (top-left at offset roughly (10, 220) inside the
##     500x400 picture, ~240 wide, ~170 tall).
##   - We don't reflow contents — items keep whatever position the
##     player left them in. That feels more "physical" than auto-grid
##     and matches Work's vibe of "wherever you drop it sticks".
##
## Hit-testing: get_global_rect().has_point(release_pos) — same approach
## as DropSlot.is_valid_drop. We expose `accepts_point()` so the minigame
## can ask "did the drop land in me?".

## Emitted when something is added or removed so the minigame can refresh
## the CRAFT button enabled state, etc.
signal contents_changed


## True while the bin is in "craft output" mode — i.e. after CRAFT fired
## and segment pieces are sitting inside. We toggle this so the bin can
## visually treat ingredients and craft outputs differently if needed
## later (right now it's just informational).
var output_mode: bool = false


func _ready() -> void:
	# Children handle their own input; we just need the rect for hit
	# testing and to host child Controls. IGNORE so we don't eat clicks.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Did this release_pos (in global coords) land inside the bin?
func accepts_point(global_pos: Vector2) -> bool:
	return get_global_rect().has_point(global_pos)


## Returns counts of each item_id currently in the bin. Used by the
## minigame at CRAFT time to check the recipe.
func count_items() -> Dictionary:
	var counts: Dictionary = {}
	for child in get_children():
		if child is WorkshopPiece:
			var id: String = String(child.item_id)
			counts[id] = int(counts.get(id, 0)) + 1
	return counts


## Returns a list of WorkshopPiece children whose item_id matches.
## Used to consume items on CRAFT (pop the first N of each id).
func pieces_with_id(id: StringName) -> Array:
	var out: Array = []
	for child in get_children():
		if child is WorkshopPiece and child.item_id == id:
			out.append(child)
	return out


## Returns ALL pieces in the bin. Order is sibling order.
func all_pieces() -> Array:
	var out: Array = []
	for child in get_children():
		if child is WorkshopPiece:
			out.append(child)
	return out


## Center of the bin in LOCAL coords. The minigame uses this when
## spawning segment pieces after CRAFT so they appear in the middle of
## the bin rather than wherever the player happened to drop ingredients.
func local_center() -> Vector2:
	return size * 0.5


## Remove and free every WorkshopPiece child. Called after CRAFT consumes
## inputs so the bin clears before the segment pieces spawn.
func clear_pieces() -> void:
	for child in all_pieces():
		child.queue_free()
	contents_changed.emit()
