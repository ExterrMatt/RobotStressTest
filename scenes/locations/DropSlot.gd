extends Control
class_name DropSlot
## A hitbox on the work panel where one specific item type can be dropped.
##
## Place four of these in WorkInventory.tscn (one per panel cutout: gear,
## arc, tri, tess). Their position and size define the hit rectangle.
##
## Tuning hitboxes in the editor:
## - In the editor's 2D view, drag the DropSlot's handles to size it to the
##   cutout shape. Anchors should be top-left preset so absolute positioning
##   is straightforward; use offset_left/top/right/bottom for placement.
## - Toggle Debug > Visible Collision Shapes ON, OR set the DropSlot's
##   `debug_draw` boolean below to see a tinted outline at runtime.
## - The accept rect is the Control's full rect — no separate shape node
##   needed because the slots are axis-aligned rectangles.

## Which item this slot accepts. Must match a DraggableItem.item_id.
## One of: "gear", "arc", "tri", "tess".
@export var accepts_item_id: StringName = &""

## When true, draws a tinted outline at runtime so you can see the hitbox
## without leaving the game. Toggle off for shipping.
@export var debug_draw: bool = false

## The item currently locked into this slot (null if empty).
var filled_by: DraggableItem = null


func _ready() -> void:
	# Slots themselves don't intercept clicks — items being dragged sit
	# above them and the drag system handles drop targeting via geometry,
	# not via mouse events on the slot.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if not debug_draw:
		return
	var color: Color = Color(0.2, 1.0, 0.4, 0.35) if filled_by == null else Color(1.0, 0.6, 0.2, 0.35)
	draw_rect(Rect2(Vector2.ZERO, size), color, true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.7), false, 2.0)


## Returns true if this slot accepts `item` AND the item's center lies
## inside our global rect.
func is_valid_drop(item: DraggableItem) -> bool:
	if filled_by != null:
		return false
	if item.item_id != accepts_item_id:
		return false
	var item_center: Vector2 = item.global_position + item.size * 0.5
	return get_global_rect().has_point(item_center)


## Lock `item` into this slot. Called by WorkInventory once a valid drop
## is confirmed.
func fill_with(item: DraggableItem) -> void:
	filled_by = item
	item.place_in(self)
	queue_redraw()


func clear() -> void:
	filled_by = null
	queue_redraw()
