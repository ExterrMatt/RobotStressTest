extends CanvasLayer
class_name InventoryOverlay
## Player-wide inventory overlay.
##
## Toggled by Space from Main.gd. Renders on top of everything via CanvasLayer
## with a high layer index. Shows:
##   - Ingredients with counts > 0 (scrap_metal, electronics, etc).
##   - Tools the player owns (excluding the defaults "mouth" and "hand"
##     which everyone always has — they'd just be noise).
##   - Any future store-bought gadgets stored in GameState.ingredients
##     (e.g. sneaky_shoes is currently stored there as a stacking item).
##
## Items render as Minecraft-style hotbar tiles anchored to the bottom-right
## of the viewport: sprite + count badge per tile.

## Where to find a sprite for each item id. If not in this map (or the file
## doesn't exist on disk), the placeholder is used.
const TEXTURE_PATHS: Dictionary = {
	"scrap_metal": "res://assets/textures/icons/scrap_metal.png",
	"synth_skin": "res://assets/textures/icons/synth_skin.png",
	"nuts_bolts": "res://assets/textures/icons/nuts_bolts.png",
	"electronics": "res://assets/textures/icons/electronics.png",
	"nanobots": "res://assets/textures/icons/nanobots.png",
	"oil": "res://assets/textures/icons/oil.png",
	"sneaky_shoes": "res://assets/textures/icons/sneaky_shoes.png",
	# Tools
	"screwdriver": "res://assets/textures/icons/screwdriver.png",
	"crank": "res://assets/textures/icons/crank.png",
	"electric_prod": "res://assets/textures/icons/electric_prod.png",
	"foam_spray": "res://assets/textures/icons/foam_spray.png",
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
	"oil": "Oil",
	"sneaky_shoes": "Sneaky Shoes",
	"screwdriver": "Screwdriver",
	"crank": "Crank",
	"electric_prod": "Electric Prod",
	"foam_spray": "Foam Spray",
}

const TILE_SIZE: Vector2 = Vector2(72, 72)
const TILE_SEPARATION: int = 6
const SPRITE_SIZE: Vector2 = Vector2(48, 48)
## How far in from the bottom-right corner the row of tiles sits.
const RIGHT_MARGIN: int = 24
const BOTTOM_MARGIN: int = 24


@onready var dim_background: ColorRect = $DimBackground
@onready var tile_row: HBoxContainer = $TileRow
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

	for entry in entries:
		tile_row.add_child(_build_tile(entry))


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
		})

	for id in GameState.owned_tools:
		if id in HIDDEN_TOOLS:
			continue
		out.append({
			"id": id,
			"name": _display_name(id),
			"count": 1,
			"texture": _load_texture_for(id),
		})

	return out


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

	# Sprite (centered).
	var sprite_holder := CenterContainer.new()
	sprite_holder.anchor_left = 0.0
	sprite_holder.anchor_top = 0.0
	sprite_holder.anchor_right = 1.0
	sprite_holder.anchor_bottom = 1.0
	sprite_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(sprite_holder)

	var sprite := TextureRect.new()
	sprite.custom_minimum_size = SPRITE_SIZE
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = entry["texture"]
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite_holder.add_child(sprite)

	# Count badge in the bottom-right of the tile (Minecraft style).
	# Hidden when count is 1 AND the entry is a tool (looks cleaner that way),
	# but we still show "1" for ingredients in case the player has exactly one.
	var count: int = int(entry.get("count", 1))
	if count > 1 or not (entry["id"] in GameState.owned_tools):
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
