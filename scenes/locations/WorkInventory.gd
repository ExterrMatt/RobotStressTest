extends Control
class_name WorkInventory
## Inventory + drag-drop orchestrator for the Work minigame's "slot the
## shape" puzzle.
##
## Scene structure (built in WorkInventory.tscn):
##   WorkInventory (Control, full-rect anchored to SceneImage)
##     LeftColumn (VBoxContainer, anchored to left side of frame)
##       Slot0 (Control)  -- gear pocket
##         GearItem (TextureRect, DraggableItem script)
##       Slot1 (Control)  -- arc pocket
##         ArcItem
##     RightColumn (VBoxContainer, anchored to right side of frame)
##       Slot2 (Control)  -- tri pocket
##         TriItem
##       Slot3 (Control)  -- tess pocket
##         TessItem
##     DropTargets (Control, sits over the work panel)
##       GearDrop (DropSlot, accepts "gear")
##       ArcDrop  (DropSlot, accepts "arc")
##       TriDrop  (DropSlot, accepts "tri")
##       TessDrop (DropSlot, accepts "tess")
##
## Drag flow:
## - DraggableItem._gui_input catches the click and emits drag_started.
## - We hear it, raise that item to the top of the draw order, and remember it.
## - On left-release anywhere in the scene, _input fires end_drag on the
##   active item, which emits drag_released back to us.
## - We test against every DropSlot and either snap the item into a valid
##   slot or send it home.

## Emitted whenever the state of any slot changes (filled or cleared).
## Lets the Work scene know when all four are filled so it can give a
## reward / advance / play a sting.
signal slots_changed(filled_count: int)


@onready var draggables: Array = _collect_draggables()
@onready var drop_slots: Array[DropSlot] = _collect_drop_slots()

## The item currently being dragged, or null. There can only be one.
var _active_drag: DraggableItem = null


func _ready() -> void:
	# We want to receive _input notifications (for the left-release) but
	# not block clicks on UI behind us.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Wire up every draggable. Each item's home_slot is set to its current
	# parent (the inventory pocket it was authored under in the .tscn).
	for item in draggables:
		var parent_slot: Control = item.get_parent() as Control
		item.home_slot = parent_slot
		item.drag_started.connect(_on_drag_started)
		item.drag_released.connect(_on_drag_released)


func _input(event: InputEvent) -> void:
	# Catch the release globally so the player can drop anywhere — even off
	# the item's own rect — and we still get the event.
	if _active_drag == null:
		return
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_active_drag.end_drag(event.global_position)


func _on_drag_started(item: DraggableItem) -> void:
	# Only one drag at a time. If another somehow started, snap that one home.
	if _active_drag and _active_drag != item:
		_active_drag.snap_home()
	_active_drag = item
	# If the item was sitting in a DropSlot, free that slot so the player
	# can rearrange. (This is what lets them pull a misplaced piece out.)
	for slot in drop_slots:
		if slot.filled_by == item:
			slot.clear()
			slots_changed.emit(_filled_count())
			break
	# Reparent under self (the inventory root) so the dragged sprite renders
	# above all the slots and the panel.
	if item.get_parent() != self:
		var gp: Vector2 = item.global_position
		item.get_parent().remove_child(item)
		add_child(item)
		item.global_position = gp
	# Move to top of sibling order so it draws on top.
	move_child(item, get_child_count() - 1)


func _on_drag_released(item: DraggableItem, _release_pos: Vector2) -> void:
	_active_drag = null
	# Find the first drop slot that accepts this item and contains its center.
	for slot in drop_slots:
		if slot.is_valid_drop(item):
			slot.fill_with(item)
			slots_changed.emit(_filled_count())
			return
	# No valid drop — fly home.
	item.snap_home()


## Returns true if all four drop slots are filled.
func is_complete() -> bool:
	for slot in drop_slots:
		if slot.filled_by == null:
			return false
	return true


# --- Internals ------------------------------------------------------------

func _filled_count() -> int:
	var n: int = 0
	for slot in drop_slots:
		if slot.filled_by != null:
			n += 1
	return n


## Walk the subtree and collect every DraggableItem.
func _collect_draggables() -> Array:
	var out: Array = []
	_gather_recursive(self, out, "DraggableItem")
	return out


func _collect_drop_slots() -> Array[DropSlot]:
	var out: Array[DropSlot] = []
	_gather_recursive(self, out, "DropSlot")
	return out


func _gather_recursive(node: Node, out: Array, class_name_str: String) -> void:
	for child in node.get_children():
		# get_script() check is the cheap way to identify our class-named scripts.
		if child.get_script() and child.get_script().get_global_name() == class_name_str:
			out.append(child)
		_gather_recursive(child, out, class_name_str)
