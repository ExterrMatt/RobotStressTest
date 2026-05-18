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
## optional shadow tweaks (offset, scale, modulate, texture override).
## Shadow textures default to "<sprite_basename>_shadow.<ext>" alongside
## the sprite; missing shadows are skipped silently.
##
## The corner button in the picture frame is the exit; its label flips
## between "WINDOW SHOP AND LEAVE" (nothing bought) and "LEAVE WITH YOUR
## PURCHASES" (bought at least one item).
##
## Buying mutates GameState directly (spend_money + add_ingredient/
## unlock_tool) rather than batching into a finished-result Dictionary,
## because each purchase is its own atomic transaction. The HUD updates
## live via GameState's existing money_changed signal.


## Editor-driven item catalog. Edit by selecting the Store node in
## Store.tscn and expanding `items` in the Inspector. Each entry is a
## StoreItemData resource (see StoreItemData.gd).
##
## Items are placed into the grid in array order, left-to-right then
## top-to-bottom. The grid is GRID_COLUMNS * GRID_ROWS slots; entries
## beyond that are silently dropped.
@export var items: Array[StoreItemData] = []


## Fallback sprite used when an item has no texture set (or when the
## configured texture failed to load). Keeps an obviously-broken slot
## visible so designers notice rather than seeing nothing.
const PLACEHOLDER_TEXTURE_PATH: String = "res://assets/textures/icons/placeholder_item.png"

## Pixel size of each item's sprite slot on the table. Matches the source
## icon size at the project's native pixel ratio — no scaling, so the items
## stay pixel-perfect on the table art.
const SLOT_SIZE: Vector2 = Vector2(160, 160)

## Grid layout on the table surface. The grid sits inside the 800x200
## ItemGrid rect (anchored bottom-center, same as the StoreTable above it).
## Tweak these to nudge items around without rebuilding tiles.
const GRID_COLUMNS: int = 3
const GRID_ROWS: int = 2
## Horizontal/vertical spacing between slot CENTERS, in source pixels.
const GRID_H_SPACING: float = 180.0
const GRID_V_SPACING: float = 175.0
## Y position of the FIRST (top) row of slot centers, relative to the
## bottom of the ItemGrid rect. Positive means "above the bottom edge".
## Adjust if the table surface ends at a different height in your art.
const GRID_BOTTOM_OFFSET: float = 120.0

## Modulate applied to items the player can't currently click — either
## already bought today or can't afford. Half RGB = visibly darker without
## going transparent, so items still read as physically present.
const ITEM_DIMMED_MODULATE: Color = Color(0.5, 0.5, 0.5, 1)
const ITEM_NORMAL_MODULATE: Color = Color(1, 1, 1, 1)

## Track whether the player has bought ANYTHING this visit. Used to flip
## the corner-button label between "window shop" and "leave with purchases".
var _bought_anything: bool = false

## Map of item_id -> the Control node holding sprite+shadow for that item,
## so we can refresh dimming without rebuilding everything. Keyed by
## String for consistency with GameState's purchased_today array.
var _slot_by_id: Dictionary = {}


@onready var furniture_layer: Control = $FurnitureLayer
@onready var item_grid: Control = %ItemGrid


func _ready() -> void:
	_build_grid()

	# Hand FurnitureLayer (table + items) to Main so it renders inside the
	# framed picture, exactly like Work does with its furniture overlay.
	var main: Node = get_tree().current_scene
	if main and main.has_method("show_scene_overlay") and furniture_layer:
		main.show_scene_overlay(furniture_layer, true)

	# Repaint items whenever money changes (affordability can flip) or
	# the purchased-today set changes (own purchases flip availability).
	GameState.money_changed.connect(_on_money_changed)
	GameState.purchased_today_changed.connect(_on_purchased_today_changed)

	_refresh_corner_button()


func _exit_tree() -> void:
	# Defensive: leave Main's corner button cleared when we go away.
	# Main.hide_corner_button() is normally called on _on_leave_pressed,
	# but if the scene tears down for any other reason we still want this.
	var main: Node = get_tree().current_scene
	if main and main.has_method("hide_corner_button"):
		main.hide_corner_button()


# --- grid construction ---

func _build_grid() -> void:
	for child in item_grid.get_children():
		child.queue_free()
	_slot_by_id.clear()

	# ItemGrid is anchored to the bottom-center of FurnitureLayer with a
	# rect spanning 800px wide and 200px tall. We position each slot's
	# CENTER inside that rect using offsets from the rect's bottom-center.
	# The rect's local origin is its top-left, so:
	#   center_x = rect_width/2  + (col - (cols-1)/2) * h_spacing
	#   center_y = rect_height   - bottom_offset - row * v_spacing
	# where row 0 is the TOP row (furthest from the table edge).
	var rect_size: Vector2 = item_grid.size
	# Fall back to the design size if Godot hasn't laid out the rect yet
	# (first frame in editor preview etc.). 800x200 matches the .tscn.
	if rect_size == Vector2.ZERO:
		rect_size = Vector2(800, 200)

	for i in items.size():
		var item: StoreItemData = items[i]
		# Tolerate empty slots in the array (designer added a row but
		# hasn't filled it in yet) — just skip them rather than crashing.
		if item == null:
			continue

		var col: int = i % GRID_COLUMNS
		var row: int = i / GRID_COLUMNS  # int division on purpose
		if row >= GRID_ROWS:
			break  # silently drop overflow; grid is sized for GRID_COLUMNS*GRID_ROWS

		var center_x: float = rect_size.x * 0.5 \
			+ (float(col) - float(GRID_COLUMNS - 1) * 0.5) * GRID_H_SPACING
		var center_y: float = rect_size.y - GRID_BOTTOM_OFFSET - float(row) * GRID_V_SPACING

		var slot: Control = _build_slot(item, Vector2(center_x, center_y))
		item_grid.add_child(slot)
		_slot_by_id[String(item.id)] = slot
		_refresh_slot(String(item.id))


## Build one item's slot — a Control containing the shadow (behind) and
## the sprite (in front). The sprite fills the SLOT_SIZE rect; the shadow
## can be independently offset, scaled, and tinted per item.
##
## Click handling is on the slot itself, which lets transparent pixels of
## the sprite still register — fine for icons that fill most of the rect.
func _build_slot(item: StoreItemData, center: Vector2) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.size = SLOT_SIZE
	# Anchor to ItemGrid top-left so our manual position is absolute within it.
	slot.position = center - SLOT_SIZE * 0.5
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.tooltip_text = "%s — $%d" % [
		item.display_name if item.display_name != "" else String(item.id),
		item.cost,
	]

	# --- Shadow (behind the sprite) ---
	# Optional. Falls back to the auto-derived "_shadow" path if neither
	# shadow_texture nor a "<sprite>_shadow.<ext>" file is set. Per-item
	# offset/scale/modulate live on the StoreItemData; defaults give the
	# same result as a plain centered shadow filling the slot rect.
	var shadow_tex: Texture2D = _resolve_shadow_texture(item)
	if shadow_tex:
		var shadow := TextureRect.new()
		shadow.name = "Shadow"
		shadow.texture = shadow_tex
		shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Compute the shadow's rect from the per-item scale + offset.
		# We do NOT anchor the shadow to the slot edges, because that
		# would scale it with the slot and ignore custom_minimum_size.
		# Instead, position it manually inside the slot at:
		#   size = SLOT_SIZE * shadow_scale
		#   top-left = (SLOT_SIZE - shadow_size) / 2 + shadow_offset
		# This keeps the shadow centered on the slot by default, while
		# letting per-item offset nudge it freely.
		var shadow_size: Vector2 = SLOT_SIZE * item.shadow_scale
		shadow.size = shadow_size
		shadow.position = (SLOT_SIZE - shadow_size) * 0.5 + item.shadow_offset

		# Stash the configured modulate on the node itself so the dim
		# refresh can multiply against it without losing the per-item
		# baseline. self_modulate is used because modulate is overwritten
		# every refresh; self_modulate stays put as the "design intent".
		shadow.self_modulate = item.shadow_modulate

		slot.add_child(shadow)

	# --- Sprite — the actual item ---
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

	# Click handler — bind the item resource so we don't have to look
	# it up by id later.
	slot.gui_input.connect(_on_slot_gui_input.bind(item))

	return slot


## Resolve the sprite texture for an item, falling back to the placeholder
## if the item has none assigned. Returns null only if BOTH are missing.
func _resolve_item_texture(item: StoreItemData) -> Texture2D:
	if item.texture:
		return item.texture
	if ResourceLoader.exists(PLACEHOLDER_TEXTURE_PATH):
		return load(PLACEHOLDER_TEXTURE_PATH)
	push_warning("Store: item %s has no texture and placeholder %s is missing." % [
		item.id, PLACEHOLDER_TEXTURE_PATH,
	])
	return null


## Resolve the shadow texture for an item, honoring an explicit
## `shadow_texture` override and otherwise auto-deriving from the sprite's
## resource path by inserting "_shadow" before the extension.
##
## Returns null if no shadow file exists — not an error, just no shadow.
func _resolve_shadow_texture(item: StoreItemData) -> Texture2D:
	# Explicit override takes priority.
	if item.shadow_texture:
		return item.shadow_texture

	# Auto-derive from the sprite's res:// path. resource_path is empty
	# for runtime-generated textures, in which case we just bail.
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

## Refresh a slot's clickability and visual dimming based on whether the
## player can afford it AND hasn't already bought it today.
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

	# Dim both sprite and shadow as a single visual unit. Modulate on the
	# parent slot would also work, but applying per-child keeps the slot
	# Control itself at full modulate so any future overlays (e.g. a "SOLD
	# OUT" badge) can be added at normal brightness.
	#
	# The shadow's per-item color/alpha lives in self_modulate (set at
	# build time); we only ever overwrite modulate here. Final on-screen
	# color = modulate * self_modulate, so a half-transparent shadow stays
	# half-transparent and just gets darker when dimmed.
	var mod: Color = ITEM_NORMAL_MODULATE if clickable else ITEM_DIMMED_MODULATE
	for child in slot.get_children():
		if child is CanvasItem:
			(child as CanvasItem).modulate = mod

	# Mouse filter stays STOP either way — we consume the click so
	# unaffordable/already-bought items don't fall through. The handler
	# itself rejects the click in those cases.


func _refresh_all_slots() -> void:
	for item_id in _slot_by_id:
		_refresh_slot(item_id)


func _find_item(item_id: String) -> StoreItemData:
	for item in items:
		if item != null and String(item.id) == item_id:
			return item
	return null


# --- click / buy ---

func _on_slot_gui_input(event: InputEvent, item: StoreItemData) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	var item_id: String = String(item.id)
	if item_id == "":
		return

	# Reject silently if already bought today or can't afford.
	if GameState.has_purchased_today(item_id):
		return
	if not GameState.spend_money(item.cost):
		return

	# Apply the purchase.
	if item.is_tool:
		GameState.unlock_tool(item_id)
	else:
		GameState.add_ingredient(item_id, item.amount)

	GameState.mark_purchased_today(item_id)
	_bought_anything = true
	_refresh_corner_button()
	# _refresh_slot for this id will fire via purchased_today_changed.


# --- corner button ---

func _refresh_corner_button() -> void:
	var main: Node = get_tree().current_scene
	if main == null or not main.has_method("show_corner_button"):
		return
	var label: String = "LEAVE WITH YOUR PURCHASES" if _bought_anything else "WINDOW SHOP AND LEAVE"
	main.show_corner_button(label, _on_leave_pressed)


func _on_leave_pressed() -> void:
	# Money/ingredients were already mutated directly via GameState during
	# purchases. We finish with an empty result and skip_advance=false so
	# the day phase moves on like any other location.
	#
	# If you'd rather make the store a free action (player can browse
	# without burning the evening), set the last arg to true.
	var main: Node = get_tree().current_scene
	if main and main.has_method("hide_corner_button"):
		main.hide_corner_button()
	finish(0, 0, 0, {}, false)


# --- signal handlers ---

func _on_money_changed(_v: int) -> void:
	_refresh_all_slots()


func _on_purchased_today_changed(_ids: Array) -> void:
	_refresh_all_slots()
