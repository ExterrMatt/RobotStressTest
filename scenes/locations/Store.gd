extends LocationBase
## Store location.
##
## A grid of clickable item tiles in the middle of the screen. Click an
## item to buy it (immediate spend, no cart). One of each item per day.
## The corner button in the picture frame is the exit; its label flips
## between "WINDOW SHOP AND LEAVE" (nothing bought) and "LEAVE WITH YOUR
## PURCHASES" (bought at least one item).
##
## Buying mutates GameState directly (spend_money + add_ingredient/
## unlock_tool) rather than batching into a finished-result Dictionary,
## because each purchase is its own atomic transaction. The HUD updates
## live via GameState's existing money_changed signal.

## Item catalog. Each entry:
##   id           - String  matching either an ingredients key on GameState,
##                          or a tool id (for tools, set is_tool=true).
##   display_name - String  shown in the tooltip / item label.
##   cost         - int     deducted from GameState.money on purchase.
##   amount       - int     how many ingredient units the player gets per
##                          purchase. Ignored when is_tool is true.
##   texture_path - String  res:// path to the item sprite. Falls back to
##                          placeholder_item.png if the file is missing.
##   is_tool      - bool    if true, treated as a one-time tool unlock
##                          (added to GameState.owned_tools) instead of
##                          stacking into ingredients.
##
## Edit this array to add/remove store items. The grid auto-builds from it.
const ITEMS: Array = [
	{
		"id": "scrap_metal",
		"display_name": "Scrap Metal x3",
		"cost": 40,
		"amount": 3,
		"texture_path": "res://assets/textures/icons/scrap_metal.png",
		"is_tool": false,
	},
	{
		"id": "electronics",
		"display_name": "Electronics x3",
		"cost": 40,
		"amount": 3,
		"texture_path": "res://assets/textures/icons/electronics.png",
		"is_tool": false,
	},
	{
		"id": "nuts_bolts",
		"display_name": "Nuts & Bolts x5",
		"cost": 25,
		"amount": 5,
		"texture_path": "res://assets/textures/icons/nuts_bolts.png",
		"is_tool": false,
	},
	{
		"id": "synth_skin",
		"display_name": "Synth-Skin x2",
		"cost": 60,
		"amount": 2,
		"texture_path": "res://assets/textures/icons/synth_skin.png",
		"is_tool": false,
	},
	{
		"id": "oil",
		"display_name": "Bottle of Oil",
		"cost": 30,
		"amount": 1,
		"texture_path": "res://assets/textures/icons/oil.png",
		"is_tool": false,
	},
	{
		"id": "sneaky_shoes",
		"display_name": "Sneaky Shoes",
		"cost": 80,
		"amount": 1,
		"texture_path": "res://assets/textures/icons/sneaky_shoes.png",
		"is_tool": false,
	},
]

## Fallback sprite used when an item's texture_path doesn't exist on disk.
const PLACEHOLDER_TEXTURE_PATH: String = "res://assets/textures/icons/placeholder_item.png"

## Size of one tile in the grid (sprite + label).
const TILE_SIZE: Vector2 = Vector2(112, 144)
## Pixel size of the item sprite inside its tile.
const SPRITE_SIZE: Vector2 = Vector2(80, 80)
## Number of columns in the item grid.
const GRID_COLUMNS: int = 3

## Modulate applied to tiles the player can't currently click — either
## already bought today or can't afford.
const TILE_DIMMED_MODULATE: Color = Color(1, 1, 1, 0.35)
const TILE_NORMAL_MODULATE: Color = Color(1, 1, 1, 1)

## Track whether the player has bought ANYTHING this visit. Used to flip
## the corner-button label between "window shop" and "leave with purchases".
var _bought_anything: bool = false

## Map of item_id -> the Panel node for that tile, so we can refresh
## interactability without rebuilding the whole grid.
var _tile_by_id: Dictionary = {}


@onready var title_label: Label = %TitleLabel
@onready var blurb_label: Label = %BlurbLabel
@onready var grid: GridContainer = %ItemGrid


func _ready() -> void:
	title_label.text = "Store"
	blurb_label.text = "Click an item to buy it. One of each per day."

	grid.columns = GRID_COLUMNS
	_build_grid()

	# Repaint tiles whenever money changes (affordability can flip) or
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
	for child in grid.get_children():
		child.queue_free()
	_tile_by_id.clear()

	for item in ITEMS:
		var tile: Panel = _build_tile(item)
		grid.add_child(tile)
		_tile_by_id[item["id"]] = tile
		_refresh_tile(item["id"])


func _build_tile(item: Dictionary) -> Panel:
	var tile := Panel.new()
	tile.custom_minimum_size = TILE_SIZE
	tile.mouse_filter = Control.MOUSE_FILTER_STOP

	# Vertical layout: sprite on top, name + cost below.
	var vbox := VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(vbox)

	# Sprite (centered TextureRect inside a fixed-size CenterContainer so the
	# image sits in the same spot regardless of source dimensions).
	var sprite_holder := CenterContainer.new()
	sprite_holder.custom_minimum_size = Vector2(TILE_SIZE.x, SPRITE_SIZE.y + 12)
	sprite_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sprite_holder)

	var sprite := TextureRect.new()
	sprite.custom_minimum_size = SPRITE_SIZE
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture = _load_item_texture(item.get("texture_path", ""))
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite_holder.add_child(sprite)

	# Item name.
	var name_label := Label.new()
	name_label.text = item.get("display_name", item.get("id", "?"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# Cost.
	var cost_label := Label.new()
	cost_label.text = "$%d" % int(item.get("cost", 0))
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 14)
	cost_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cost_label)

	# Click handler — bind the item dictionary so we don't have to look
	# it up by index later.
	tile.gui_input.connect(_on_tile_gui_input.bind(item))

	return tile


## Load `path` if it exists, else fall back to the placeholder sprite.
## Returns null only if BOTH are missing (we just push a warning then).
func _load_item_texture(path: String) -> Texture2D:
	if path != "" and ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		if tex:
			return tex
	if ResourceLoader.exists(PLACEHOLDER_TEXTURE_PATH):
		return load(PLACEHOLDER_TEXTURE_PATH)
	push_warning("Store: neither %s nor placeholder %s exist." % [path, PLACEHOLDER_TEXTURE_PATH])
	return null


# --- interactivity refresh ---

## Refresh a tile's clickability and visual dimming based on whether the
## player can afford it AND hasn't already bought it today.
func _refresh_tile(item_id: String) -> void:
	if not _tile_by_id.has(item_id):
		return
	var tile: Panel = _tile_by_id[item_id]
	var item: Dictionary = _find_item(item_id)
	if item.is_empty():
		return

	var bought: bool = GameState.has_purchased_today(item_id)
	var affordable: bool = GameState.can_afford(int(item.get("cost", 0)))
	var clickable: bool = (not bought) and affordable

	tile.modulate = TILE_NORMAL_MODULATE if clickable else TILE_DIMMED_MODULATE
	# Mouse filter still STOP either way — we want to consume the click so
	# unaffordable / already-bought tiles don't fall through to anything
	# behind them. The handler itself rejects the click in those cases.


func _refresh_all_tiles() -> void:
	for item_id in _tile_by_id:
		_refresh_tile(item_id)


func _find_item(item_id: String) -> Dictionary:
	for item in ITEMS:
		if item.get("id", "") == item_id:
			return item
	return {}


# --- click / buy ---

func _on_tile_gui_input(event: InputEvent, item: Dictionary) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	var item_id: String = item.get("id", "")
	if item_id == "":
		return

	# Reject silently if already bought today or can't afford.
	if GameState.has_purchased_today(item_id):
		return
	var cost: int = int(item.get("cost", 0))
	if not GameState.spend_money(cost):
		return

	# Apply the purchase.
	if bool(item.get("is_tool", false)):
		GameState.unlock_tool(item_id)
	else:
		GameState.add_ingredient(item_id, int(item.get("amount", 1)))

	GameState.mark_purchased_today(item_id)
	_bought_anything = true
	_refresh_corner_button()
	# _refresh_tile for this id will fire via purchased_today_changed.


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
	_refresh_all_tiles()


func _on_purchased_today_changed(_ids: Array) -> void:
	_refresh_all_tiles()
