extends TextureRect
class_name DraggableItem
## A single draggable shape (gear / arc / tri / tess) that lives in an
## InventorySlot and can be dragged into the work panel.
##
## Lifecycle:
## - At rest in its home slot, anchored to that slot's center.
## - On left-click press, we reparent it under the inventory root so it can
##   render above the slots (z-order is sibling order in a Control tree).
## - While dragging, _process keeps the sprite pinned to the mouse.
## - On release, the WorkInventory parent calls try_drop() which checks
##   for an overlap with a DropSlot. If it matches, snap into the slot.
##   Otherwise tween back to the home slot.
##
## Design notes:
## - We use _gui_input rather than _input so the click only triggers when the
##   item itself is moused over — no separate hitbox math needed for picking up.
## - mouse_filter = MOUSE_FILTER_PASS so children below us can still get
##   their own clicks (e.g. the back button under the panel). The item itself
##   only registers clicks on its non-transparent pixels because we set
##   ignore_texture_size and use TEXTURE_BUTTON-style hit testing.

## Identifier matched against DropSlot.accepts_item_id. Set to one of:
## "gear", "arc", "tri", "tess".
@export var item_id: StringName = &""

## Emitted when the player clicks-and-holds this item. The WorkInventory
## listens so it knows which item is currently being dragged.
signal drag_started(item: DraggableItem)

## Emitted when the player releases the mouse. WorkInventory does the
## overlap test and decides what happens next.
signal drag_released(item: DraggableItem, release_pos: Vector2)


## Where to return to if the drop is invalid. Set by WorkInventory after
## the item is placed in its slot.
var home_slot: Control = null

## True while the left mouse button is held after a press on this item.
var _dragging: bool = false

## Offset from the item's top-left to the mouse position at the moment of
## click. We preserve this while dragging so the sprite doesn't "jump" to
## center itself under the cursor.
var _grab_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Stop the texture stretching to the Control's rect — we want pixel-exact
	# rendering so the hit-test below corresponds to the visible shape.
	stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	# Allow clicks; PASS lets clicks fall through transparent pixels of the
	# Control's rect to whatever's underneath, but we still get clicks on
	# our visible area because _gui_input fires on press anywhere in the rect.
	# (If you want strictly pixel-perfect picking, set this on the parent.)
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Snap our Control rect to the texture's natural size so positioning math
	# below is straightforward.
	if texture:
		custom_minimum_size = texture.get_size()
		size = texture.get_size()


func _gui_input(event: InputEvent) -> void:
	# Pick up on left-click press.
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not _dragging:
			_dragging = true
			# Remember where on the sprite the player grabbed.
			_grab_offset = get_local_mouse_position()
			drag_started.emit(self)
			# Eat the event so it doesn't bubble.
			accept_event()


func _process(_delta: float) -> void:
	if not _dragging:
		return
	# Track the mouse. We work in the parent's local coords because that's
	# what `position` is relative to.
	var parent_ctrl: Control = get_parent() as Control
	if parent_ctrl == null:
		return
	var mouse_in_parent: Vector2 = parent_ctrl.get_local_mouse_position()
	position = mouse_in_parent - _grab_offset


## Called from WorkInventory's global _input on left-release. Handled there
## (not here) so the release fires even when the cursor has wandered off the
## item's rect.
func end_drag(release_global_pos: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	drag_released.emit(self, release_global_pos)


func is_dragging() -> bool:
	return _dragging


## Tween back to the home slot's center. Used when the drop is invalid.
func snap_home() -> void:
	if home_slot == null:
		return
	var target: Vector2 = _target_position_in(home_slot)
	# Reparent under the home slot if we got moved during the drag.
	if get_parent() != home_slot:
		_reparent_keeping_global(home_slot)
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", target, 0.18)


## Lock the item into a slot (drop target or home). Cancels any drag,
## reparents to `slot`, and positions us centered inside it.
func place_in(slot: Control) -> void:
	_dragging = false
	if get_parent() != slot:
		_reparent_keeping_global(slot)
	position = _target_position_in(slot)


# --- Internals ------------------------------------------------------------

## Compute the position (in `slot`'s local space) that centers this item
## inside the slot.
func _target_position_in(slot: Control) -> Vector2:
	return (slot.size - size) * 0.5


## Move this node under `new_parent` without visually jumping. We compute
## the current global rect position, reparent, then write back a local
## position that produces the same global position.
func _reparent_keeping_global(new_parent: Control) -> void:
	var global_pos: Vector2 = global_position
	var current_parent: Node = get_parent()
	if current_parent:
		current_parent.remove_child(self)
	new_parent.add_child(self)
	global_position = global_pos
