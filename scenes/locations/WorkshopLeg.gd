@tool
extends Control
class_name WorkshopLeg
## A container for all of a leg's WorkshopAssemblySlot children.
##
## This exists purely so you can reposition the entire assembled leg by
## moving ONE node in the editor. Slot positions become relative to this
## container, so they stay perfectly locked to each other while you slide
## the whole assembly around the assembly area.
##
## The minigame doesn't need to know about this — it walks descendants to
## find WorkshopAssemblySlots, so an extra Control layer in the tree
## doesn't change behavior. (If your minigame currently iterates
## assembly.get_children() directly instead of using a recursive walk,
## see the small patch in WorkshopMinigame_patch.gd.)

## Show a faint outline of the leg container's rect in the editor so you
## can see what you're grabbing. Off by default — turn on while tuning.
@export var debug_draw: bool = false:
	set(value):
		debug_draw = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if not debug_draw:
		return
	# Dashed-ish corner ticks so it's obvious in the editor without
	# obscuring the slots' own debug rects.
	var r := Rect2(Vector2.ZERO, size)
	var col := Color(1, 0.85, 0.2, 0.9)
	var tick: float = 12.0
	# Top-left
	draw_line(r.position, r.position + Vector2(tick, 0), col, 2.0)
	draw_line(r.position, r.position + Vector2(0, tick), col, 2.0)
	# Top-right
	draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x - tick, r.position.y), col, 2.0)
	draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y + tick), col, 2.0)
	# Bottom-left
	draw_line(Vector2(r.position.x, r.end.y), Vector2(r.position.x + tick, r.end.y), col, 2.0)
	draw_line(Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.end.y - tick), col, 2.0)
	# Bottom-right
	draw_line(r.end, r.end - Vector2(tick, 0), col, 2.0)
	draw_line(r.end, r.end - Vector2(0, tick), col, 2.0)
