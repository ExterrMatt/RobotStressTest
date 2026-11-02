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
## Items render as Minecraft-style tiles (sprite + count badge) in three side-by-side
## sections — ingredients, tools & misc, robot parts — each a grid that wraps into as
## many rows as needed so nothing runs off screen. A bag sits in the bottom-left corner
## (the InventoryBag node; move or resize it in the scene).
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
	"battery": "res://assets/textures/icons/battery.png",
	"shoulder_pad": "res://assets/textures/icons/shoulder_pad.png",
	"sneaky_shoes": "res://assets/textures/icons/sneaky_shoes.png",
	"leg": "res://assets/textures/icons/leg.png",
	"arm": "res://assets/textures/icons/arm_no_hand.png",
	# The stomach's icon art still lives in the legacy torso.png file.
	"stomach": "res://assets/textures/icons/torso.png",
	"chest": "res://assets/textures/icons/chest.png",
	"head": "res://assets/textures/icons/head.png",
	"hand": "res://assets/textures/icons/hand.png",
	# Cosmetic chest items.
	"big_coconuts": "res://assets/textures/icons/big_coconuts.png",
	"small_coconuts": "res://assets/textures/icons/small_coconuts.png",
	"balloons": "res://assets/textures/icons/balloons.png",
	"big_chest_cover": "res://assets/textures/icons/chest_cover.png",
	# Limb sub-assemblies — pre-made segments craftable in the workshop (thigh art is
	# thighs.png).
	"upper_arm": "res://assets/textures/icons/upper_arm.png",
	"forearm": "res://assets/textures/icons/forearm.png",
	"thigh": "res://assets/textures/icons/thighs.png",
	"shin": "res://assets/textures/icons/shin.png",
	"foot": "res://assets/textures/icons/foot.png",
	"ribcage": "res://assets/textures/icons/ribcage.png",
	"upper_plating": "res://assets/textures/icons/upper_plating.png",
	"lower_plating": "res://assets/textures/icons/lower_plating.png",
	"tank": "res://assets/textures/icons/tank.png",
	"pump": "res://assets/textures/icons/pump.png",
	"huge_battery": "res://assets/textures/icons/huge_battery.png",
	"pelvis": "res://assets/textures/icons/pelvis.png",
	"outer_plating": "res://assets/textures/icons/outer_plating.png",
	"external": "res://assets/textures/icons/external.png",
	# Tools
	"screwdriver": "res://assets/textures/icons/screwdriver.png",
	"crank": "res://assets/textures/icons/crank.png",
	"electric_prod": "res://assets/textures/icons/taser.png",
	"taser": "res://assets/textures/icons/taser.png",
	"foam_spray": "res://assets/textures/icons/foam_spray.png",
	"welding_gun": "res://assets/textures/icons/welding_gun.png",
	"curtains": "res://assets/textures/icons/curtains.png",
	"flashlight": "res://assets/textures/icons/flashlight.png",
	"post_it": "res://assets/textures/icons/post-it.png",
}

## The inventory's three sections, left to right. Raw ingredients go in the first; tools
## and odds and ends (MISC_ITEM_IDS) in the second; everything else — robot parts, the
## components they're built from, and what's worn on the robot — in the third.
const SECTION_TITLES: Array[String] = ["INGREDIENTS", "TOOLS & MISC", "ROBOT PARTS"]
const SECTION_INGREDIENTS: int = 0
const SECTION_TOOLS_MISC: int = 1
const SECTION_ROBOT_PARTS: int = 2
const INGREDIENT_IDS: Array[String] = [
	"scrap_metal", "synth_skin", "nuts_bolts", "electronics", "nanobots", "head_segments", "oil", "battery",
]
const MISC_ITEM_IDS: Array[String] = ["balloons"]
## Space between the sections.
const SECTION_SEPARATION: int = 32

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
	"shoulder_pad": "Shoulder Pad",
	"sneaky_shoes": "Sneaky Shoes",
	"leg": "Leg",
	"arm": "Arm",
	"stomach": "Stomach",
	"chest": "Chest",
	"head": "Head",
	"hand": "Hand",
	"big_coconuts": "Big Coconuts",
	"small_coconuts": "Small Coconuts",
	"balloons": "Balloons",
	"upper_arm": "Upper Arm",
	"forearm": "Forearm",
	"thigh": "Thigh",
	"shin": "Shin",
	"foot": "Foot",
	"ribcage": "Rib Cage",
	"upper_plating": "Upper Plating",
	"lower_plating": "Lower Plating",
	"tank": "Tank",
	"pump": "Pump",
	"huge_battery": "Huge Battery",
	"pelvis": "Pelvis",
	"outer_plating": "Outer Plating",
	"external": "External",
	"big_chest_cover": "Big Chest Cover",
	"screwdriver": "Screwdriver",
	"crank": "Crank",
	"electric_prod": "Taser",
	"taser": "Taser",
	"foam_spray": "Foam Spray",
	"welding_gun": "Welding Gun",
	"flashlight": "Flashlight",
	"post_it": "Post-it Note",
}

const TILE_SIZE: Vector2 = Vector2(72, 72)
const TILE_SEPARATION: int = 6
const SPRITE_SIZE: Vector2 = Vector2(48, 48)
## How far in from the bottom-right corner the row of tiles sits.
const RIGHT_MARGIN: int = 24
const BOTTOM_MARGIN: int = 24
## Opening: the screen dims and the INVENTORY sign (hanging from the top edge) slides down
## into place, both over OPEN_SECONDS, easing out, while the bag rises from below the bottom
## edge (see BAG_EXTRA_SECONDS). Closing runs it backwards over CLOSE_SECONDS, easing in:
## the dim lifts, the sign rises away off the top and the bag sinks back below the bottom.
const OPEN_SECONDS: float = 0.3
const CLOSE_SECONDS: float = 0.15
## Opening, the tiles (and the empty message) fade in this long after the rest starts,
## finishing with it. Closing, they fade out with the rest, no delay.
const TILE_FADE_DELAY: float = 0.09
## The bag rises from below the bottom edge into its corner (and sinks back out) with the
## sign's easing, but this much slower than the sign.
const BAG_EXTRA_SECONDS: float = 0.1


@onready var dim_background: ColorRect = $DimBackground
@onready var tile_area: Control = $TileArea
@onready var sections_row: HBoxContainer = $TileArea/Sections
@onready var inventory_label: TextureRect = $InventoryLabel
@onready var empty_label: Label = $EmptyLabel
## The bag in the bottom-left corner (placed in the scene; slides up from below the screen).
@onready var inventory_bag: TextureRect = $InventoryBag

## How dark the dim gets once it's faded in (the scene's own setting).
var _dim_alpha: float = 0.55
## The bag's top offset from the bottom edge where it rests (the scene's own placement).
var _bag_rest_offset_top: float = 0.0
var _open_tween: Tween = null
## True while the close animation plays: the overlay is still drawn but counts as shut (it
## leaves GROUP and takes no clicks), and opening again picks up from where it's got to.
var _closing: bool = false

## Lets the post-it note step aside while the inventory is open.
const GROUP: StringName = &"inventory_overlay"
## Scenes where items can be taken out of the inventory into the player's hand join this
## group (Maintenance does). Such a scene provides can_grab_inventory_items() -> bool and
## grab_inventory_item(entry) -> bool: while it can, the open hand shows anywhere over the
## block of tiles, and a press on an item hands that item's entry over (it then holds the
## item) and the inventory closes, leaving the rest of that press - the let-go - to it.
const GRABBER_GROUP: StringName = &"inventory_item_grabbers"
## Movement keys the scene behind would use; swallowed while the inventory is open.
const MOVEMENT_KEYS: Array[Key] = [KEY_W, KEY_A, KEY_S, KEY_D]


## True while the inventory is up (not while it's closing). The scenes behind it hold
## their camera sway and WASD movement still while it is.
static func is_open(tree: SceneTree) -> bool:
	if tree == null:
		return false
	for node in tree.get_nodes_in_group(GROUP):
		if node is CanvasLayer and node.visible:
			return true
	return false

## Each tile on screen with the entry it shows, for routing clicks (see _input).
var _tiles: Array = []
## Mouse buttons whose press the inventory took, so their release is its too.
var _claimed_buttons: Dictionary = {}


func _ready() -> void:
	# High layer so we sit above HUD, dialogue boxes, anything.
	layer = 100
	add_to_group(GROUP)
	_dim_alpha = dim_background.color.a
	_bag_rest_offset_top = inventory_bag.offset_top

	# Repaint whenever the inventory state changes. We don't poll.
	# (Hooked once at _ready and freed with the node.)
	GameState.ingredients = GameState.ingredients  # no-op, just here for clarity
	# GameState doesn't emit a per-ingredient signal in the current
	# version, so we refresh whenever the overlay becomes visible. That's
	# fine because the overlay is only visible while shown anyway.

	visible = false
	_refresh()
	visibility_changed.connect(_on_visibility_changed)
	# The flashlight's tile lights up while its beam is on.
	GameState.flashlight_on_changed.connect(func(_on: bool) -> void: _refresh())


## While the inventory is up, hand cursors from the scene behind don't show through it.
func _on_visibility_changed() -> void:
	if visible:
		CursorTheme.set_override(self, CursorTheme.Grab.NONE)
	else:
		CursorTheme.release_override(self)


func _exit_tree() -> void:
	CursorTheme.release_override(self)


## Where items can be grabbed, the open hand over the tiles. It covers the whole block of
## them (gaps between tiles and sections too), so the cursor doesn't flicker back to the
## arrow while crossing a gap.
func _process(_delta: float) -> void:
	if not visible or _closing:
		return
	var state: int = CursorTheme.Grab.NONE
	if _grabber() != null and _tiles_rect().has_point(get_viewport().get_mouse_position()):
		state = CursorTheme.Grab.OPEN
	CursorTheme.set_override(self, state)


## The scene items can be grabbed into right now, if any (see GRABBER_GROUP).
func _grabber() -> Node:
	var node := get_tree().get_first_node_in_group(GRABBER_GROUP)
	if node == null or not node.has_method("grab_inventory_item") or not node.has_method("can_grab_inventory_items"):
		return null
	return node if bool(node.call("can_grab_inventory_items")) else null


## The rect covering every tile on screen.
func _tiles_rect() -> Rect2:
	var rect := Rect2()
	var first := true
	for pair in _tiles:
		var tile: Control = pair[0]
		if not is_instance_valid(tile) or not tile.is_visible_in_tree():
			continue
		rect = tile.get_global_rect() if first else rect.merge(tile.get_global_rect())
		first = false
	return rect


## Called externally by Main to show/hide. Refreshes content on show.
func show_overlay() -> void:
	var was_closing := _closing
	_closing = false
	add_to_group(GROUP)
	_refresh()
	visible = true
	# Be the last of our siblings, so our _input runs before the scene's (see _input).
	if get_parent() != null:
		get_parent().move_child(self, -1)
	_play_open(was_closing)


## Fades the dim in from clear and slides the INVENTORY sign down from just above the top
## edge until it hangs flush with it (see OPEN_SECONDS). Reopened mid-close, it carries on
## from wherever the close had got to.
func _play_open(from_current: bool = false) -> void:
	_kill_tween()
	if not from_current:
		dim_background.color.a = 0.0
		inventory_label.position.y = -inventory_label.size.y
		inventory_bag.position.y = _bag_hidden_y()
		_set_tiles_alpha(0.0)
	_open_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(dim_background, "color:a", _dim_alpha, OPEN_SECONDS)
	_open_tween.tween_property(inventory_label, "position:y", 0.0, OPEN_SECONDS)
	_open_tween.tween_property(inventory_bag, "position:y", _bag_rest_y(), OPEN_SECONDS + BAG_EXTRA_SECONDS)
	_tween_tiles_alpha(1.0, OPEN_SECONDS, TILE_FADE_DELAY)


## The open animation in reverse (see CLOSE_SECONDS); hides the overlay once it's done.
func _play_close() -> void:
	_kill_tween()
	_open_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_open_tween.tween_property(dim_background, "color:a", 0.0, CLOSE_SECONDS)
	_open_tween.tween_property(inventory_label, "position:y", -inventory_label.size.y, CLOSE_SECONDS)
	_open_tween.tween_property(inventory_bag, "position:y", _bag_hidden_y(), CLOSE_SECONDS + BAG_EXTRA_SECONDS)
	_tween_tiles_alpha(0.0, CLOSE_SECONDS)
	_open_tween.chain().tween_callback(func() -> void:
		_closing = false
		visible = false)


## Adds the tiles' fade to `alpha` to the running tween: `delay` in, ending with the rest of
## the `seconds`-long animation.
func _tween_tiles_alpha(alpha: float, seconds: float, delay: float = 0.0) -> void:
	var fade := maxf(0.01, seconds - delay)
	for node in [tile_area, empty_label]:
		_open_tween.tween_property(node, "modulate:a", alpha, fade).set_delay(delay)


func _set_tiles_alpha(alpha: float) -> void:
	tile_area.modulate.a = alpha
	empty_label.modulate.a = alpha


## Where the bag rests (its place in the scene) and where it waits just below the screen.
func _bag_rest_y() -> float:
	return get_viewport().get_visible_rect().size.y + _bag_rest_offset_top


func _bag_hidden_y() -> float:
	return get_viewport().get_visible_rect().size.y


func _kill_tween() -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_open_tween = null


## While the inventory is up it takes every click first: some scenes (the workshop) read the
## mouse in their own _input, which runs before any GUI, so a click on a tile would also
## reach whatever sits behind it. Clicks are handed to the tile under the cursor here and
## go no further. (Mouse movement still passes, for the tiles' tooltips.) WASD stops here
## too, so nothing behind moves.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and visible and not _closing:
		var key := event as InputEventKey
		if key.keycode in MOVEMENT_KEYS or key.physical_keycode in MOVEMENT_KEYS:
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	# A click that closed the inventory (opening the post-it) still owns its release.
	if not mb.pressed and _claimed_buttons.has(mb.button_index):
		_claimed_buttons.erase(mb.button_index)
		get_viewport().set_input_as_handled()
		return
	if not visible or _closing:
		# A fresh press is the end of any claimed one whose release went elsewhere.
		_claimed_buttons.erase(mb.button_index)
		return
	get_viewport().set_input_as_handled()
	if mb.pressed:
		_claimed_buttons[mb.button_index] = true
	var at: Vector2 = mb.global_position
	for pair in _tiles:
		var tile: Control = pair[0]
		if is_instance_valid(tile) and tile.is_visible_in_tree() and tile.get_global_rect().has_point(at):
			_on_tile_gui_input(event, pair[1])
			return


func hide_overlay() -> void:
	if not visible or _closing:
		return
	_closing = true
	# Shut as far as everything else is concerned from the start of the close (the post-it
	# and minigames look for an open inventory in this group).
	remove_from_group(GROUP)
	_play_close()


func toggle() -> void:
	if visible and not _closing:
		hide_overlay()
	else:
		show_overlay()


# --- content build ---

func _refresh() -> void:
	# Clear old sections.
	for child in sections_row.get_children():
		sections_row.remove_child(child)
		child.queue_free()

	_tiles.clear()
	var entries: Array = _collect_entries()
	empty_label.visible = entries.is_empty()

	var by_section: Array = [[], [], []]
	for entry in entries:
		by_section[_section_for(entry)].append(entry)

	# Each section gets an equal share of the width; its grid wraps into as many rows as
	# needed, capped at its item count so a short section still forms one tidy row.
	var columns: int = _max_columns_per_section()
	for i in by_section.size():
		var section_entries: Array = by_section[i]
		if section_entries.is_empty():
			continue
		sections_row.add_child(_build_section(SECTION_TITLES[i], section_entries, columns))


func _section_for(entry: Dictionary) -> int:
	var id: String = String(entry.get("id", ""))
	var kind := String(entry.get("kind", ""))
	if kind == "tool" or kind == "note" or id in MISC_ITEM_IDS:
		return SECTION_TOOLS_MISC
	if id in INGREDIENT_IDS:
		return SECTION_INGREDIENTS
	return SECTION_ROBOT_PARTS


func _build_section(title: String, entries: Array, max_columns: int) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_theme_constant_override("separation", 8)

	var header := Label.new()
	header.text = title
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	header.add_theme_color_override("font_outline_color", Color.BLACK)
	header.add_theme_constant_override("outline_size", 4)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_child(header)

	var grid := GridContainer.new()
	grid.columns = maxi(1, mini(entries.size(), max_columns))
	grid.add_theme_constant_override("h_separation", TILE_SEPARATION)
	grid.add_theme_constant_override("v_separation", TILE_SEPARATION)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_child(grid)
	for entry in entries:
		var tile := _build_tile(entry)
		_tiles.append([tile, entry])
		grid.add_child(tile)
	return section


## How many TILE_SIZE tiles fit across one section: a third of the usable width (viewport
## minus the TileArea's margins and the gaps between sections).
func _max_columns_per_section() -> int:
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	var usable: float = maxf(viewport_width - 48.0 - 2.0 * SECTION_SEPARATION, TILE_SIZE.x * 3.0) / 3.0
	var per_tile: float = TILE_SIZE.x + float(TILE_SEPARATION)
	return maxi(1, int(floor((usable + float(TILE_SEPARATION)) / per_tile)))


## Returns an Array of {id, name, count, texture, kind} dicts to display (sorted into
## sections by _section_for). Order: ingredients in their GameState.ingredients dictionary
## order (with count > 0), robot parts, cosmetics, then non-default tools.
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

	# The parts in hand - not the ones on the robot (a part taken off her lands here as
	# itself, and putting one on uses it up).
	for id in GameState.ROBOT_PART_IDS:
		var part_count: int = GameState.get_robot_part_count(id)
		if part_count > 0:
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

	# The post-it note is always on hand; clicking it opens it to write on.
	out.append({
		"id": "post_it",
		"name": _display_name("post_it"),
		"count": 1,
		"texture": _load_texture_for("post_it"),
		"kind": "note",
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


## A click on a tile (routed here by _input). Clicking the post-it note closes the
## inventory and opens the note to write on. In a scene that takes items into the hand
## (GRABBER_GROUP), pressing on any other item grabs it: the scene holds it and the
## inventory closes, the press left unclaimed so its release reaches the scene.
## Debug-only: shift + left-click on a tile removes that item from the inventory
## entirely — every copy of it, not just one (so a stack of 99 drops to 0).
func _on_tile_gui_input(event: InputEvent, entry: Dictionary) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
		return
	if String(entry.get("kind", "")) == "note" and not mb.shift_pressed:
		get_viewport().set_input_as_handled()
		_open_post_it()
		return
	var grabber := _grabber()
	if grabber != null and not mb.shift_pressed and bool(grabber.call("grab_inventory_item", entry)):
		_claimed_buttons.erase(mb.button_index)
		# The scene's grip (closed hand) shows from here, not this overlay's cursor.
		CursorTheme.release_override(self)
		hide_overlay()
		return
	if not mb.shift_pressed:
		return
	if not GameState.debug_mode_enabled:
		return
	get_viewport().set_input_as_handled()
	_debug_remove_entry(entry)


func _open_post_it() -> void:
	hide_overlay()
	PostItNote.open_in(get_parent())


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
	# Lit only while its beam is on (see FlashlightIcon).
	if id == "flashlight":
		return FlashlightIcon.texture(GameState.flashlight_on)
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
	# Clicks reach tiles through _input; STOP keeps hover (tooltips) on the tile.
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	if String(entry.get("kind", "")) == "note":
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
	if count > 1 or (kind != "tool" and kind != "cosmetic_item" and kind != "note"):
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
