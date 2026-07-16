extends CanvasLayer
class_name InventoryOverlay
## Player-wide inventory overlay.
##
## Toggled by Space from Main.gd. Renders on top of everything via CanvasLayer
## with a high layer index. Shows:
##   - Ingredients with counts > 0 (scrap_metal, electronics, etc).
##   - Tools the player owns (excluding the defaults "mouth" and "hand"
##     which everyone always has — they'd just be noise).
##
## Items render as Minecraft-style tiles (sprite + count badge) in a centered
## grid that wraps into as many rows as needed so nothing runs off screen.
##
## Debug: shift + left-click a tile wipes that item from the inventory entirely.

## Where to find a sprite for each item id. If not in this map (or the file
## doesn't exist on disk), the placeholder is used.
const TEXTURE_PATHS: Dictionary = {
	"scrap_metal": "res://assets/textures/icons/scrap_metal.png",
	"synth_skin": "res://assets/textures/icons/synth_skin.png",
	"nuts_bolts": "res://assets/textures/icons/nuts_bolts.png",
	"electronics": "res://assets/textures/icons/electronics.png",
	"nanobots": "res://assets/textures/icons/nanobots.png",
	"head_segments": "res://assets/textures/icons/head_segments.png",
	"oil": "res://assets/textures/icons/oil.png",
	"sneaky_shoes": "res://assets/textures/icons/sneaky_shoes.png",
	"leg": "res://assets/textures/icons/leg.png",
	"arm": "res://assets/textures/icons/arm.png",
	# The stomach's icon art still lives in the legacy torso.png file.
	"stomach": "res://assets/textures/icons/torso.png",
	"chest": "res://assets/textures/icons/chest.png",
	"head": "res://assets/textures/icons/head.png",
	"hand": "res://assets/textures/icons/hand.png",
	# Cosmetic chest items — placeholder icons reuse the torso overlay art for now.
	"big_coconuts": "res://assets/textures/characters/robot/stresstest/torso/big_coconuts.png",
	"small_coconuts": "res://assets/textures/characters/robot/stresstest/torso/small_coconuts.png",
	"big_chest_cover": "res://assets/textures/characters/robot/stresstest/chest_cover.png",
	# Tools
	"screwdriver": "res://assets/textures/icons/screwdriver.png",
	"crank": "res://assets/textures/icons/crank.png",
	"electric_prod": "res://assets/textures/icons/taser.png",
	"taser": "res://assets/textures/icons/taser.png",
	"foam_spray": "res://assets/textures/icons/foam_spray.png",
	"welding_gun": "res://assets/textures/icons/welding_gun.png",
}

const PLACEHOLDER_TEXTURE_PATH: String = "res://assets/textures/icons/placeholder_item.png"

## Default tools that don't need to clutter the inventory — they're always
## available so showing them is just visual noise.
const HIDDEN_TOOLS: Array[String] = ["mouth", "hand"]

## Friendly display names for each item id. Falls back to the raw id with
## underscores replaced by spaces if not listed.
const DISPLAY_NAMES: Dictionary = {
	"scrap_metal": "Scrap Metal",
	"synth_skin": "Synth-Skin",
	"nuts_bolts": "Nuts & Bolts",
	"electronics": "Electronics",
	"nanobots": "Nanobots",
	"head_segments": "Head Segments",
	"oil": "Oil",
	"sneaky_shoes": "Sneaky Shoes",
	"leg": "Leg",
	"arm": "Arm",
	"stomach": "Stomach",
	"chest": "Chest",
	"head": "Head",
	"hand": "Hand",
	"big_coconuts": "Big Coconuts",
	"small_coconuts": "Small Coconuts",
	"big_chest_cover": "Big Chest Cover",
	"screwdriver": "Screwdriver",
	"crank": "Crank",
	"electric_prod": "Taser",
	"taser": "Taser",
	"foam_spray": "Foam Spray",
	"welding_gun": "Welding Gun",
}

const TILE_SIZE: Vector2 = Vector2(72, 72)
const TILE_SEPARATION: int = 6
const SPRITE_SIZE: Vector2 = Vector2(48, 48)
## How far in from the bottom-right corner the row of tiles sits.
const RIGHT_MARGIN: int = 24
const BOTTOM_MARGIN: int = 24


@onready var dim_background: ColorRect = $DimBackground
@onready var tile_row: GridContainer = $TileArea/TileRow
@onready var title_label: Label = $TitleLabel
@onready var empty_label: Label = $EmptyLabel


func _ready() -> void:
	# High layer so we sit above HUD, dialogue boxes, anything.
	layer = 100

	# Repaint whenever the inventory state changes. We don't poll.
	# (Hooked once at _ready and freed with the node.)
	GameState.ingredients = GameState.ingredients  # no-op, just here for clarity
	# GameState doesn't emit a per-ingredient signal in the current
	# version, so we refresh whenever the overlay becomes visible. That's
	# fine because the overlay is only visible while shown anyway.

	visible = false
	_refresh()


## Called externally by Main to show/hide. Refreshes content on show.
func show_overlay() -> void:
	_refresh()
	visible = true


func hide_overlay() -> void:
	visible = false


func toggle() -> void:
	if visible:
		hide_overlay()
	else:
		show_overlay()


# --- content build ---

func _refresh() -> void:
	# Clear old tiles.
	for child in tile_row.get_children():
		child.queue_free()

	var entries: Array = _collect_entries()
	empty_label.visible = entries.is_empty()

	# Wrap the tiles into as many rows as needed so nothing runs off screen.
	# Columns = however many tiles fit across the viewport, capped at the item
	# count so a short inventory still forms a single tidy row.
	tile_row.columns = maxi(1, mini(entries.size(), _max_columns_for_viewport()))

	for entry in entries:
		tile_row.add_child(_build_tile(entry))


## How many TILE_SIZE tiles fit across the usable width (viewport minus the
## left/right margins the TileArea reserves).
func _max_columns_for_viewport() -> int:
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	var usable: float = maxf(viewport_width - 48.0, TILE_SIZE.x)
	var per_tile: float = TILE_SIZE.x + float(TILE_SEPARATION)
	return maxi(1, int(floor((usable + float(TILE_SEPARATION)) / per_tile)))


## Returns an Array of {id, name, count, texture} dicts to display.
## Order: ingredients in their GameState.ingredients dictionary order
## (with count > 0), then non-default tools.
func _collect_entries() -> Array:
	var out: Array = []

	for id in GameState.ingredients.keys():
		var count: int = int(GameState.ingredients[id])
		if count <= 0:
			continue
		out.append({
			"id": id,
			"name": _display_name(id),
			"count": count,
			"texture": _load_texture_for(id),
			"kind": "ingredient",
		})

	for id in GameState.ROBOT_PART_IDS:
		var part_count: int = GameState.get_robot_part_count(id)
		if part_count <= 0:
			continue
		out.append({
			"id": id,
			"name": _display_name(id),
			"count": part_count,
			"texture": _load_texture_for(id),
			"kind": "robot_part",
		})

	for id in GameState.COSMETIC_ITEM_IDS:
		if GameState.get_cosmetic_item_count(String(id)) <= 0:
			continue
		out.append({
			"id": id,
			"name": _display_name(id),
			"count": GameState.get_cosmetic_item_count(String(id)),
			"texture": _load_texture_for(id),
			"kind": "cosmetic_item",
		})

	for id in GameState.owned_tools:
		if id in HIDDEN_TOOLS:
			continue
		out.append({
			"id": id,
			"name": _display_name(id),
			"count": 1,
			"texture": _load_texture_for(id),
			"kind": "tool",
		})

	return out


## Debug-only: shift + left-click on a tile removes that item from the inventory
## entirely — every copy of it, not just one (so a stack of 99 drops to 0).
func _on_tile_gui_input(event: InputEvent, entry: Dictionary) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.shift_pressed):
		return
	if not GameState.debug_mode_enabled:
		return
	get_viewport().set_input_as_handled()
	_debug_remove_entry(entry)


func _debug_remove_entry(entry: Dictionary) -> void:
	var id: String = String(entry.get("id", ""))
	if id == "":
		return
	match String(entry.get("kind", "")):
		"ingredient":
			if GameState.ingredients.has(id):
				GameState.ingredients[id] = 0
		"robot_part":
			GameState.set_robot_part_count(id, 0)
		"cosmetic_item":
			GameState.set_cosmetic_item(id, 0)
		"tool":
			GameState.owned_tools.erase(id)
			GameState.tool_counts.erase(id)
	_refresh()


func _display_name(id: String) -> String:
	if DISPLAY_NAMES.has(id):
		return DISPLAY_NAMES[id]
	return id.replace("_", " ").capitalize()


func _load_texture_for(id: String) -> Texture2D:
	var path: String = String(TEXTURE_PATHS.get(id, ""))
	if path != "" and ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		if tex:
			return tex
	if ResourceLoader.exists(PLACEHOLDER_TEXTURE_PATH):
		return load(PLACEHOLDER_TEXTURE_PATH)
	return null


func _build_tile(entry: Dictionary) -> Panel:
	var tile := Panel.new()
	tile.custom_minimum_size = TILE_SIZE
	tile.tooltip_text = entry["name"]
	# Debug: shift-click a tile to wipe that item from the inventory entirely.
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.gui_input.connect(_on_tile_gui_input.bind(entry))
	var is_head_segments: bool = String(entry.get("id", "")) == "head_segments"

	# Sprite.
	var sprite_holder: Control = Control.new() if is_head_segments else CenterContainer.new()
	sprite_holder.anchor_left = 0.0
	sprite_holder.anchor_top = 0.0
	sprite_holder.anchor_right = 1.0
	sprite_holder.anchor_bottom = 1.0
	sprite_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(sprite_holder)

	var sprite := TextureRect.new()
	var sprite_size: Vector2 = SPRITE_SIZE * 1.05 if is_head_segments else SPRITE_SIZE
	sprite.custom_minimum_size = sprite_size
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = entry["texture"]
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite_holder.add_child(sprite)
	if is_head_segments:
		sprite.anchor_left = 0.5
		sprite.anchor_right = 0.5
		sprite.anchor_top = 0.0
		sprite.anchor_bottom = 0.0
		sprite.offset_left = -sprite_size.x * 0.5
		sprite.offset_right = sprite_size.x * 0.5
		sprite.offset_top = 0.0
		sprite.offset_bottom = sprite_size.y

	# Count badge in the bottom-right of the tile (Minecraft style).
	# Hidden when count is 1 AND the entry is a tool (looks cleaner that way),
	# but we still show "1" for ingredients in case the player has exactly one.
	var count: int = int(entry.get("count", 1))
	var kind: String = String(entry.get("kind", ""))
	if count > 1 or (kind != "tool" and kind != "cosmetic_item"):
		var badge := Label.new()
		badge.text = str(count)
		badge.anchor_left = 1.0
		badge.anchor_top = 1.0
		badge.anchor_right = 1.0
		badge.anchor_bottom = 1.0
		badge.offset_left = -28.0
		badge.offset_top = -22.0
		badge.offset_right = -4.0
		badge.offset_bottom = -2.0
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.add_theme_font_size_override("font_size", 16)
		badge.add_theme_color_override("font_color", Color.WHITE)
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 4)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(badge)

	return tile
