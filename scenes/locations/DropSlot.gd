extends Control
class_name DropSlot

@export var accepts_item_id: StringName = &""
@export var debug_draw: bool = false

## Optional. A node (typically a TextureRect showing filled-state art)
## that becomes visible when this slot is filled, and is hidden again when
## it's cleared. Drag the matching panel sprite (e.g. GearPanel) here in
## the editor.
@export var revealed_sprite: CanvasItem

var filled_by: DraggableItem = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if revealed_sprite:
		revealed_sprite.visible = false


func _draw() -> void:
	if not debug_draw:
		return
	var color: Color = Color(0.2, 1.0, 0.4, 0.35) if filled_by == null else Color(1.0, 0.6, 0.2, 0.35)
	draw_rect(Rect2(Vector2.ZERO, size), color, true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.7), false, 2.0)


func is_valid_drop(item: DraggableItem) -> bool:
	if filled_by != null:
		return false
	if item.item_id != accepts_item_id:
		return false
	var item_center: Vector2 = item.global_position + item.size * 0.5
	return get_global_rect().has_point(item_center)


func fill_with(item: DraggableItem) -> void:
	filled_by = item
	item.place_in(self)
	item.visible = false
	if revealed_sprite:
		revealed_sprite.visible = true
	queue_redraw()


func clear() -> void:
	if filled_by:
		filled_by.visible = true
	if revealed_sprite:
		revealed_sprite.visible = false
	filled_by = null
	queue_redraw()
