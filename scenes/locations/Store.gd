extends LocationBase
## Store location.
##
## Items sit directly on the store_table inside the framed picture — no
## tile chrome, no labels under each item. Click an item sprite to buy
## it (immediate spend, no cart). One of each item per day.
##
## Visual layering, per item:
##   shadow (50% darker when dimmed)
##   sprite (50% darker when dimmed)
##
## Item catalog lives in the Inspector as the `items` array on the Store
## node — see StoreItemData.gd for the per-item fields, including the
## optional shadow tweaks.
##
## Click handling note:
## The item slots are reparented (via Main.show_scene_overlay) into
## SceneImage, which is buried deep in a chain of nested PanelContainers
## that have STOP mouse_filters by default. Rather than try to thread a
## click path through that whole chain, we listen on `_input` (the global
## input pipe, which fires regardless of Control routing) and do our own
## hit-testing against each slot's global rect. This is the same pattern
## WorkInventory uses for its drop-release handling.

## Editor-driven item catalog. Edit by selecting the Store node in
## Store.tscn and expanding `items` in the Inspector. Each entry is a
## StoreItemData resource (see StoreItemData.gd).
##
## Items are placed into the grid in array order, left-to-right then
## top-to-bottom. The grid is GRID_COLUMNS * GRID_ROWS slots; entries
## beyond that are silently dropped.
@export var items: Array[StoreItemData] = []


## Fallback sprite used when an item has no texture set (or when the
## configured texture failed to load).
const PLACEHOLDER_TEXTURE_PATH: String = "res://assets/textures/icons/placeholder_item.png"

## Pixel size of each item's sprite slot on the table.
const SLOT_SIZE: Vector2 = Vector2(160, 160)

## Grid layout on the table surface.
const GRID_COLUMNS: int = 3
const GRID_ROWS: int = 3
const GRID_H_SPACING: float = 180.0
const GRID_V_SPACING: float = 175.0
const GRID_BOTTOM_OFFSET: float = 120.0

## Modulate applied to items the player can't currently click — either
## already bought today or can't afford. Half RGB = visibly darker without
## going transparent, so items still read as physically present.
const ITEM_DIMMED_MODULATE: Color = Color(0.5, 0.5, 0.5, 1)
const ITEM_NORMAL_MODULATE: Color = Color(1, 1, 1, 1)

## Track whether the player has bought ANYTHING this visit.
var _bought_anything: bool = false

## Map of item_id (String) -> the Control node holding sprite+shadow.
var _slot_by_id: Dictionary = {}

## Reverse map for hit-testing: array of {slot, item} pairs in build order.
## We walk this in _input to figure out which slot the click landed on.
var _slot_hits: Array = []


@onready var furniture_layer: Control = $FurnitureLayer
@onready var item_grid: Control = %ItemGrid


func _ready() -> void:
	# The Store root spans the whole screen. If it eats clicks, they
	# never reach our reparented slots inside SceneImage. IGNORE means
	# we render but never consume input — clicks pass straight through.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_grid()

	# Hand FurnitureLayer (table + items) to Main so it renders inside the
	# framed picture. interactive=true makes Main flip SceneImage's
	# mouse_filter so child clicks can route through — though we ALSO use
	# our own _input handler below as a backup, since the SceneImage chain
	# is too deep to rely on Control routing alone.
	var main: Node = get_tree().current_scene
	if main and main.has_method("show_scene_overlay") and furniture_layer:
		main.show_scene_overlay(furniture_layer, true)

	GameState.money_changed.connect(_on_money_changed)
	GameState.purchased_today_changed.connect(_on_purchased_today_changed)

	_refresh_corner_button()


func _exit_tree() -> void:
	var main: Node = get_tree().current_scene
	if main and main.has_method("hide_corner_button"):
		main.hide_corner_button()


## Global input handler. We listen here (rather than relying on each
## slot's _gui_input) because the slots are deep inside a chain of
## PanelContainers with STOP mouse_filters. _input fires before any
## Control routing, so we get clicks regardless of where the cursor is
## on the screen, and we hit-test ourselves against each slot's global
## rect.
##
## Safety: bail out if a dialogue overlay or transition is active so we
## don't fire purchases during scene swaps.
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	# If the picture-frame transition is mid-wipe, ignore clicks.
	var main: Node = get_tree().current_scene
	if main and "transition" in main:
		var tr = main.transition
		if tr and tr.has_method("is_playing") and tr.is_playing():
			return

	# Walk each slot and check whether the click landed on it.
	# get_global_rect() reflects the slot's CURRENT screen position,
	# which is what we want after the reparent into SceneImage.
	for hit in _slot_hits:
		var slot: Control = hit["slot"]
		var item: StoreItemData = hit["item"]
		if slot == null or not is_instance_valid(slot):
			continue
		if not slot.visible or not slot.is_visible_in_tree():
			continue
		if slot.get_global_rect().has_point(mb.global_position):
			_try_purchase(item)
			# Consume the event so the click doesn't fall through to
			# anything else (e.g. the corner button if we happen to
			# overlap, or background UI).
			get_viewport().set_input_as_handled()
			return


# --- grid construction ---

func _build_grid() -> void:
	for child in item_grid.get_children():
		child.queue_free()
	_slot_by_id.clear()
	_slot_hits.clear()

	# ItemGrid spans 800x200 inside FurnitureLayer (bottom-anchored).
	# Position each slot's CENTER inside that rect using the constants.
	var rect_size: Vector2 = item_grid.size
	if rect_size == Vector2.ZERO:
		rect_size = Vector2(800, 200)

	for i in items.size():
		var item: StoreItemData = items[i]
		if item == null:
			continue

		var col: int = i % GRID_COLUMNS
		var row: int = i / GRID_COLUMNS
		if row >= GRID_ROWS:
			break

		var center_x: float = rect_size.x * 0.5 \
			+ (float(col) - float(GRID_COLUMNS - 1) * 0.5) * GRID_H_SPACING
		var center_y: float = rect_size.y - GRID_BOTTOM_OFFSET - float(row) * GRID_V_SPACING

		var slot: Control = _build_slot(item, Vector2(center_x, center_y))
		item_grid.add_child(slot)
		_slot_by_id[String(item.id)] = slot
		_slot_hits.append({"slot": slot, "item": item})
		_refresh_slot(String(item.id))


## Build one item's slot — a Control containing the shadow (behind) and
## the sprite (in front). The slot itself doesn't need to be clickable
## here (we hit-test in _input), so its mouse_filter is irrelevant —
## but set to IGNORE for clarity since we never use Control routing.
func _build_slot(item: StoreItemData, center: Vector2) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.size = SLOT_SIZE
	slot.position = center - SLOT_SIZE * 0.5
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.tooltip_text = "%s — $%d" % [
		item.display_name if item.display_name != "" else String(item.id),
		item.cost,
	]

	# Shadow (optional).
	var shadow_tex: Texture2D = _resolve_shadow_texture(item)
	if shadow_tex:
		var shadow := TextureRect.new()
		shadow.name = "Shadow"
		shadow.texture = shadow_tex
		shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shadow_size: Vector2 = SLOT_SIZE * item.shadow_scale
		shadow.size = shadow_size
		shadow.position = (SLOT_SIZE - shadow_size) * 0.5 + item.shadow_offset
		shadow.self_modulate = item.shadow_modulate
		slot.add_child(shadow)

	# Sprite.
	var sprite := TextureRect.new()
	sprite.name = "Sprite"
	sprite.texture = _resolve_item_texture(item)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.anchor_right = 1.0
	sprite.anchor_bottom = 1.0
	slot.add_child(sprite)

	return slot


func _resolve_item_texture(item: StoreItemData) -> Texture2D:
	if item.texture:
		return item.texture
	if ResourceLoader.exists(PLACEHOLDER_TEXTURE_PATH):
		return load(PLACEHOLDER_TEXTURE_PATH)
	push_warning("Store: item %s has no texture and placeholder %s is missing." % [
		item.id, PLACEHOLDER_TEXTURE_PATH,
	])
	return null


func _resolve_shadow_texture(item: StoreItemData) -> Texture2D:
	if item.shadow_texture:
		return item.shadow_texture
	if item.texture == null:
		return null
	var sprite_path: String = item.texture.resource_path
	if sprite_path == "":
		return null
	var derived: String = sprite_path.get_basename() + "_shadow." + sprite_path.get_extension()
	if not ResourceLoader.exists(derived):
		return null
	return load(derived)


# --- interactivity refresh ---

func _refresh_slot(item_id: String) -> void:
	if not _slot_by_id.has(item_id):
		return
	var slot: Control = _slot_by_id[item_id]
	var item: StoreItemData = _find_item(item_id)
	if item == null:
		return

	var bought: bool = GameState.has_purchased_today(item_id)
	var affordable: bool = GameState.can_afford(item.cost)
	var clickable: bool = (not bought) and affordable

	var mod: Color = ITEM_NORMAL_MODULATE if clickable else ITEM_DIMMED_MODULATE
	for child in slot.get_children():
		if child is CanvasItem:
			(child as CanvasItem).modulate = mod


func _refresh_all_slots() -> void:
	for item_id in _slot_by_id:
		_refresh_slot(item_id)


func _find_item(item_id: String) -> StoreItemData:
	for item in items:
		if item != null and String(item.id) == item_id:
			return item
	return null


# --- click / buy ---

## Centralized purchase logic. Called from _input after hit-testing.
## Returns silently if the item is unaffordable or already purchased.
func _try_purchase(item: StoreItemData) -> void:
	var item_id: String = String(item.id)
	if item_id == "":
		return

	if GameState.has_purchased_today(item_id):
		return
	if not GameState.spend_money(item.cost):
		return

	if item.is_tool:
		GameState.unlock_tool(item_id)
	else:
		GameState.add_ingredient(item_id, item.amount)

	GameState.mark_purchased_today(item_id)
	_bought_anything = true
	_refresh_corner_button()


# --- corner button ---

func _refresh_corner_button() -> void:
	var main: Node = get_tree().current_scene
	if main == null or not main.has_method("show_corner_button"):
		return
	var label: String = "LEAVE WITH YOUR PURCHASES" if _bought_anything else "WINDOW SHOP AND LEAVE"
	main.show_corner_button(label, _on_leave_pressed)


func _on_leave_pressed() -> void:
	var main: Node = get_tree().current_scene
	if main and main.has_method("hide_corner_button"):
		main.hide_corner_button()
	finish(0, 0, 0, {}, false)


# --- signal handlers ---

func _on_money_changed(_v: int) -> void:
	_refresh_all_slots()


func _on_purchased_today_changed(_ids: Array) -> void:
	_refresh_all_slots()
