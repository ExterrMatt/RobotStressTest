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


@onready var draggables: Array = _collect_draggables_from_root()
@onready var drop_slots: Array = _collect_drop_slots_from_root()

## The item currently being dragged, or null. There can only be one.
var _active_drag: DraggableItem = null


func _ready() -> void:
	# We want to receive _input notifications (for the left-release) but
	# not block clicks on UI behind us.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Shuffle which shape starts in which pocket so the puzzle isn't the same
	# every shift. The drop targets stay fixed (each accepts its own shape) —
	# only the starting pocket changes. Done before home_slot is recorded below
	# so each item remembers the pocket it was randomly dealt into.
	_randomize_item_slots()

	# Wire up every draggable. Each item's home_slot is set to its current
	# parent (the inventory pocket it was authored under in the .tscn).
	for item in draggables:
		var parent_slot: Control = item.get_parent() as Control
		item.home_slot = parent_slot
		item.drag_started.connect(_on_drag_started)
		item.drag_released.connect(_on_drag_released)


## Randomly deal the four shape items into the four inventory pockets. The
## pockets (GearSlot/ArcSlot in LeftColumn, TriSlot/TessSlot in RightColumn) are
## fixed; we just shuffle which item sits in which. Items keep their item_id and
## texture, so the fixed drop targets still only accept their matching shape.
func _randomize_item_slots() -> void:
	var slots: Array = []
	for column_name in ["LeftColumn", "RightColumn"]:
		var column: Node = get_node_or_null(column_name)
		if column == null:
			continue
		for child in column.get_children():
			if child is Panel:
				slots.append(child)

	var items: Array = []
	for slot in slots:
		for child in slot.get_children():
			if child is DraggableItem:
				items.append(child)

	if items.is_empty() or items.size() != slots.size():
		return

	# Fisher-Yates with a freshly-seeded RNG so we don't perturb the global one.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp

	for i in slots.size():
		var slot: Control = slots[i]
		var item: DraggableItem = items[i]
		if item.get_parent() != slot:
			item.get_parent().remove_child(item)
			slot.add_child(item)
		# Re-center inside the pocket, matching the authored anchoring.
		item.anchor_left = 0.5
		item.anchor_top = 0.5
		item.anchor_right = 0.5
		item.anchor_bottom = 0.5
		item.offset_left = -32.0
		item.offset_top = -32.0
		item.offset_right = 32.0
		item.offset_bottom = 32.0


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
	drop_slots = _collect_drop_slots_from_root()
	# Find the first drop slot that accepts this item and contains its center.
	for slot in drop_slots:
		if slot.is_valid_drop(item):
			slot.fill_with(item)
			slots_changed.emit(_filled_count())
			return
	# No valid drop — fly home.
	item.snap_home()


## Debug speedrun helper: drop every draggable straight into its matching slot
## so a held Enter completes the puzzle without any manual dragging. Emits
## slots_changed as each slot fills, driving the same completion path a normal
## drag would.
func auto_solve() -> void:
	drop_slots = _collect_drop_slots_from_root()
	for slot in drop_slots:
		if slot.filled_by != null:
			continue
		for item in draggables:
			if item == null or not is_instance_valid(item):
				continue
			if item.item_id != slot.accepts_item_id:
				continue
			if _item_placed_in_slot(item):
				continue
			slot.fill_with(item)
			slots_changed.emit(_filled_count())
			break


func _item_placed_in_slot(item: DraggableItem) -> bool:
	for slot in drop_slots:
		if slot.filled_by == item:
			return true
	return false


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


## Walk from the scene root to collect every DraggableItem.
func _collect_draggables_from_root() -> Array:
	var out: Array = []
	_gather_recursive(get_tree().current_scene, out, "DraggableItem")
	return out


func _collect_drop_slots_from_root() -> Array:
	var out: Array = []
	_gather_recursive(get_tree().current_scene, out, "DropSlot")
	return out

func _gather_recursive(node: Node, out: Array, class_name_str: String) -> void:
	for child in node.get_children():
		# get_script() check is the cheap way to identify our class-named scripts.
		if child.get_script() and child.get_script().get_global_name() == class_name_str:
			out.append(child)
		_gather_recursive(child, out, class_name_str)
