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

## The first entries in `items` that are always displayed. One additional
## item is chosen daily from the remaining entries and shown in the next slot.
@export_range(0, 8, 1) var fixed_visible_item_count: int = 5


## Fallback sprite used when an item has no texture set (or when the
## configured texture failed to load).
const PLACEHOLDER_TEXTURE_PATH: String = "res://assets/textures/icons/placeholder_item.png"
const SCENE_PLACEHOLDER_TEXTURE_PATH: String = "res://assets/textures/backgrounds/scene_placeholder.png"
const ED_SHOP_BACKGROUND_TEXTURE_PATH: String = "res://assets/textures/backgrounds/ed_shop.png"
const STORE_BACKGROUND_TEXTURE_PATH: String = "res://assets/textures/backgrounds/store.png"
const STORE_FRAME_SIZE: Vector2 = Vector2(800.0, 640.0)
const STORE_FRAME_OUTER_WIDTH: float = 800.0
const INTRO_STORE_STEP: String = "store"
const INTRO_PICKUP_ITEM_IDS: Array[String] = ["electronics", "nuts_bolts", "nanobots"]
const INTRO_TABLE_VERTICAL_OFFSET: float = 200.0

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
var _store_active: bool = false
var _signals_connected: bool = false
var _intro_pickup_active: bool = false
var _intro_collected_item_ids: Dictionary = {}
var _intro_dialogue_key: String = ""
var _table_intro_offset_applied: bool = false

## Map of item_id (String) -> the Control node holding sprite+shadow.
var _slot_by_id: Dictionary = {}

## Reverse map for hit-testing: array of {slot, item} pairs in build order.
## We walk this in _input to figure out which slot the click landed on.
var _slot_hits: Array = []


@onready var furniture_layer: Control = $FurnitureLayer
@onready var store_table: TextureRect = $FurnitureLayer/StoreTable
@onready var item_grid: Control = %ItemGrid
@onready var dialogue_box: DialogueBox = %DialogueBox


func _ready() -> void:
	# The Store root spans the whole screen. If it eats clicks, they
	# never reach our reparented slots inside SceneImage. IGNORE means
	# we render but never consume input — clicks pass straight through.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	Dialogue.load_file("intro", "res://data/dialogue/intro.dlg")
	if dialogue_box != null:
		dialogue_box.visible = false
		dialogue_box.finished.connect(_on_intro_dialogue_finished)

	if GameState.is_intro_step(INTRO_STORE_STEP):
		_enter_intro_dialogue("store_intro")
		return

	_enter_store_ui()


func _enter_intro_dialogue(dialogue_key: String) -> void:
	_intro_dialogue_key = dialogue_key
	_store_active = false
	_intro_pickup_active = false
	furniture_layer.visible = false
	var main: Node = get_tree().current_scene
	if main != null:
		if main.has_method("hide_scene_overlay"):
			main.hide_scene_overlay()
		if main.has_method("hide_corner_button"):
			main.hide_corner_button()
		if main.has_method("hide_teacher_portrait"):
			main.hide_teacher_portrait()
		if "scene_image" in main:
			var ed_shop := load(ED_SHOP_BACKGROUND_TEXTURE_PATH) as Texture2D
			if ed_shop != null:
				main.scene_image.texture = ed_shop
		if main.has_method("_animate_frame_to") and "_default_frame_outer_width" in main:
			main._animate_frame_to(Vector2(900.0, 225.0), main._default_frame_outer_width)

	if dialogue_box != null:
		dialogue_box.visible = true
		dialogue_box.play_pages(Dialogue.get_pages("intro", dialogue_key))


func _on_intro_dialogue_finished() -> void:
	if not GameState.is_intro_step(INTRO_STORE_STEP):
		return
	if dialogue_box != null:
		dialogue_box.visible = false
	if _intro_dialogue_key == "store_intro":
		var main: Node = get_tree().current_scene
		if main != null and main.has_method("_play_transition_then"):
			main._play_transition_then(Callable(self, "_enter_store_ui"))
		else:
			_enter_store_ui()
	else:
		_finish_intro_store()


func _enter_store_ui() -> void:
	_store_active = true
	_intro_pickup_active = GameState.is_intro_step(INTRO_STORE_STEP)
	furniture_layer.visible = true
	if _intro_pickup_active:
		_intro_collected_item_ids.clear()
		_apply_intro_table_offset()
	var main: Node = get_tree().current_scene
	if main != null:
		if "scene_image" in main:
			var store_background := load(STORE_BACKGROUND_TEXTURE_PATH) as Texture2D
			if store_background != null:
				main.scene_image.texture = store_background
		if main.has_method("_animate_frame_to"):
			main._animate_frame_to(STORE_FRAME_SIZE, STORE_FRAME_OUTER_WIDTH)

	_build_grid()

	if main and main.has_method("show_scene_overlay") and furniture_layer:
		main.show_scene_overlay(furniture_layer, true)

	if _intro_pickup_active:
		if main and main.has_method("hide_corner_button"):
			main.hide_corner_button()
		return

	if not _signals_connected:
		GameState.money_changed.connect(_on_money_changed)
		GameState.purchased_today_changed.connect(_on_purchased_today_changed)
		_signals_connected = true

	_refresh_corner_button()


func _exit_tree() -> void:
	var main: Node = get_tree().current_scene
	if main and main.has_method("hide_corner_button"):
		main.hide_corner_button()
	if main and main.has_method("hide_scene_overlay"):
		main.hide_scene_overlay()


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
	if not _store_active:
		return
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

	var visible_items := _visible_items_for_current_mode()
	for i in visible_items.size():
		var item: StoreItemData = visible_items[i]
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


func _visible_items_for_current_mode() -> Array[StoreItemData]:
	if _intro_pickup_active:
		return _intro_pickup_items()
	return _daily_visible_items()


func _intro_pickup_items() -> Array[StoreItemData]:
	var pickup_items: Array[StoreItemData] = []
	for item_id in INTRO_PICKUP_ITEM_IDS:
		pickup_items.append(_intro_pickup_item(item_id))
	return pickup_items


func _intro_pickup_item(item_id: String) -> StoreItemData:
	var existing := _find_item(item_id)
	if existing != null:
		return existing
	var item := StoreItemData.new()
	item.id = StringName(item_id)
	item.display_name = _intro_pickup_display_name(item_id)
	item.cost = 0
	item.amount = 1
	var icon_path := "res://assets/textures/icons/%s.png" % item_id
	if ResourceLoader.exists(icon_path):
		item.texture = load(icon_path)
	return item


func _intro_pickup_display_name(item_id: String) -> String:
	match item_id:
		"electronics":
			return "Electronics"
		"nuts_bolts":
			return "Nuts & Bolts"
		"nanobots":
			return "Nanobots"
		_:
			return item_id.capitalize()


func _daily_visible_items() -> Array[StoreItemData]:
	var visible_items: Array[StoreItemData] = []
	var fixed_count: int = mini(fixed_visible_item_count, items.size())
	for i in fixed_count:
		var item: StoreItemData = items[i]
		if item != null:
			visible_items.append(item)

	var lottery_items: Array[StoreItemData] = []
	for i in range(fixed_count, items.size()):
		var item: StoreItemData = items[i]
		if item != null and _is_lottery_item_available(item):
			lottery_items.append(item)

	if not lottery_items.is_empty():
		visible_items.append(_daily_lottery_item(lottery_items))

	return visible_items


func _daily_lottery_item(lottery_items: Array[StoreItemData]) -> StoreItemData:
	var selected_id := ""
	var previous_id := ""
	var day_count: int = maxi(1, GameState.day)
	for day in range(1, day_count + 1):
		selected_id = _daily_lottery_item_id_for_day(lottery_items, day, previous_id)
		previous_id = selected_id

	for item in lottery_items:
		if item != null and String(item.id) == selected_id:
			return item

	return lottery_items[0]


func _daily_lottery_item_id_for_day(
	lottery_items: Array[StoreItemData],
	day: int,
	previous_id: String
) -> String:
	var candidates: Array[StoreItemData] = []
	for item in lottery_items:
		if item == null:
			continue
		if lottery_items.size() > 1 and String(item.id) == previous_id:
			continue
		candidates.append(item)

	if candidates.is_empty():
		return ""

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("store_daily_lottery_%d" % day)
	var selected: StoreItemData = candidates[rng.randi_range(0, candidates.size() - 1)]
	return String(selected.id)


func _is_lottery_item_available(item: StoreItemData) -> bool:
	if item == null:
		return false
	var item_id := String(item.id)
	if item_id == "":
		return false
	return not (item.is_tool and _tool_at_max_quantity(item))


func _has_available_lottery_items() -> bool:
	var fixed_count: int = mini(fixed_visible_item_count, items.size())
	for i in range(fixed_count, items.size()):
		var item: StoreItemData = items[i]
		if _is_lottery_item_available(item):
			return true
	return false


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
	if _intro_pickup_active:
		var item_name: String = item.display_name if item.display_name != "" else String(item.id)
		slot.tooltip_text = "Collect %s" % item_name

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
	var icon_path := "res://assets/textures/icons/%s.png" % String(item.id)
	if ResourceLoader.exists(icon_path):
		return load(icon_path)
	if ResourceLoader.exists(PLACEHOLDER_TEXTURE_PATH):
		return load(PLACEHOLDER_TEXTURE_PATH)
	push_warning("Store: item %s has no texture and placeholder %s is missing." % [
		item.id, PLACEHOLDER_TEXTURE_PATH,
	])
	return null


func _resolve_shadow_texture(item: StoreItemData) -> Texture2D:
	if item.shadow_texture:
		return item.shadow_texture
	var sprite_path: String = ""
	if item.texture:
		sprite_path = item.texture.resource_path
	else:
		var icon_path := "res://assets/textures/icons/%s.png" % String(item.id)
		if ResourceLoader.exists(icon_path):
			sprite_path = icon_path
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
	if item == null and not _intro_pickup_active:
		return

	if _intro_pickup_active:
		for child in slot.get_children():
			if child is CanvasItem:
				(child as CanvasItem).modulate = ITEM_NORMAL_MODULATE
		return

	var bought: bool = GameState.has_purchased_today(item_id)
	var already_owned_tool: bool = item.is_tool and _tool_at_max_quantity(item)
	var affordable: bool = GameState.can_afford(item.cost)
	var clickable: bool = (not bought) and (not already_owned_tool) and affordable

	var mod: Color = ITEM_NORMAL_MODULATE if clickable else ITEM_DIMMED_MODULATE
	for child in slot.get_children():
		if child is CanvasItem:
			(child as CanvasItem).modulate = mod


func _refresh_all_slots() -> void:
	for item_id in _slot_by_id:
		_refresh_slot(item_id)


## True when the player already owns as many of this tool as it allows, so it
## should stop being offered. Single-unlock tools cap at one; stackable tools
## (e.g. the screwdriver) cap at their max_quantity.
func _tool_at_max_quantity(item: StoreItemData) -> bool:
	if item == null or not item.is_tool:
		return false
	var cap: int = maxi(1, item.max_quantity)
	return GameState.get_tool_count(String(item.id)) >= cap


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
	if _intro_pickup_active:
		_collect_intro_pickup_item(item)
		return

	if item.is_tool and _tool_at_max_quantity(item):
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
	if not _has_available_lottery_items():
		_build_grid()
	_refresh_corner_button()


func _collect_intro_pickup_item(item: StoreItemData) -> void:
	var item_id := String(item.id)
	if _intro_collected_item_ids.has(item_id):
		return
	_intro_collected_item_ids[item_id] = true

	if _slot_by_id.has(item_id):
		var slot := _slot_by_id[item_id] as Control
		if slot != null:
			slot.visible = false

	if _intro_collected_item_ids.size() >= INTRO_PICKUP_ITEM_IDS.size():
		_finish_intro_store()

func _finish_intro_store() -> void:
	finish(0, 0, 0, {}, false)


func _apply_intro_table_offset() -> void:
	if _table_intro_offset_applied:
		return
	_table_intro_offset_applied = true
	_offset_control_vertically(store_table, INTRO_TABLE_VERTICAL_OFFSET)


func _offset_control_vertically(control: Control, amount: float) -> void:
	if control == null:
		return
	control.offset_top += amount
	control.offset_bottom += amount


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
