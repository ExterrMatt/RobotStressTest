extends Control
class_name WorkshopMinigame
## The crafting + assembly minigame, mounted inside the picture frame.
##
## INPUT MODEL
## -----------
## We sit deep under SceneImage, where Control's mouse_filter chain
## breaks both press and release events. Following Store.gd's pattern,
## we handle ALL input through the global _input pipe and do our own
## hit-testing against global rects.
##
##   Click (left press):
##     1. Walk pieces in reverse z-order (topmost first). First piece
##        whose global_rect contains the click is picked up.
##     2. If no piece was hit, test the CRAFT button (in the bin), then
##        the COLLECT button. Either click is routed manually.
##
##   Motion while _active_drag is set:
##     Forward the global mouse position into _active_drag.update_drag().
##
##   Left release while _active_drag is set:
##     Finish the drag. Try each assembly slot, then the craft bin,
##     then snap home.
##
## LAYOUT
## ------
## Authored in NATIVE source pixels (500x400) since Workshop renders 1:1.
##
##   Ingredients tray:  ( 12,  12) to (240, 184)
##   Craft bin:         ( 12, 196) to (240, 384)
##     CRAFT button:    (170, 354) to (232, 380)
##   Assembly area:     (252,  12) to (488, 384)
##     9 segment slots stacked top->bottom
##     COLLECT button:  (390, 354) to (480, 380)
##
## CRAFT FLOW
## ----------
## Player drags ingredients from tray to bin. CRAFT enables when the bin
## contains at least the recipe inputs (currently 1 nanobot, 1 scrap, 1
## nuts_bolts). On press, we consume from GameState, clear the bin, and
## spawn EVERY segment piece in a loose grid centered in the bin. Player
## then drags pieces to assembly slots. Dropping any piece of a segment
## on its slot places the whole segment (all pieces in the bin that
## share the segment_id snap to their authored offsets). COLLECT
## enables when all slots are filled.

signal collected


## Recipe inputs. Editable in the editor on a per-instance basis.
@export var recipe_inputs: Dictionary = {
	"nanobots": 1,
	"scrap_metal": 1,
	"nuts_bolts": 1,
}

## Ingredient art paths, keyed by GameState ingredient id.
const INGREDIENT_PATHS: Dictionary = {
	"scrap_metal":   "res://assets/textures/icons/scrap_metal.png",
	"nuts_bolts":    "res://assets/textures/icons/nuts_bolts.png",
	"nanobots":      "res://assets/textures/icons/nanobots.png",
	"electronics":   "res://assets/textures/icons/electronics.png",
	"synth_skin":    "res://assets/textures/icons/synth_skin.png",
	"oil":           "res://assets/textures/icons/oil.png",
}
const INGREDIENT_SHADOW_PATHS: Dictionary = {
	"scrap_metal":   "res://assets/textures/icons/scrap_metal_shadow.png",
	"nuts_bolts":    "res://assets/textures/icons/nuts_bolts_shadow.png",
	"electronics":   "res://assets/textures/icons/electronics_shadow.png",
	"synth_skin":    "res://assets/textures/icons/synth_skin_shadow.png",
	"oil":           "res://assets/textures/icons/oil_shadow.png",
}

const LEG_PART_ROOT: String = "res://assets/textures/icons/workshop robot leg/"


@onready var ingredients_tray: Control = %IngredientsTray
@onready var craft_bin: WorkshopBin = %CraftBin
@onready var craft_button: Button = %CraftButton
@onready var assembly: Control = %AssemblyArea
@onready var collect_button: Button = %CollectButton

# segment_id (String) -> {anchor: Vector2, pieces: Array of Dictionaries}
var _segments: Dictionary = {}

# segment_id (String) -> WorkshopAssemblySlot node
var _assembly_slots: Dictionary = {}

# Currently dragged piece, or null.
var _active_drag: WorkshopPiece = null

# Has CRAFT fired? Used for input-routing decisions (e.g. ignore CRAFT
# button after it's been pressed).
var _crafted: bool = false


func _ready() -> void:
	# Root passes clicks through; we hit-test in _input ourselves.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_segment_table()
	_collect_assembly_slots()
	_populate_ingredients_tray()

	craft_bin.contents_changed.connect(_refresh_craft_button)

	craft_button.disabled = true
	collect_button.disabled = true
	collect_button.visible = false


# --- global input pipe (Store pattern) ---

func _input(event: InputEvent) -> void:
	# Bail out during scene transitions so we don't fire clicks while
	# the picture is wiping.
	var main: Node = get_tree().current_scene
	if main and "transition" in main:
		var tr = main.transition
		if tr and tr.has_method("is_playing") and tr.is_playing():
			return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return

		if mb.pressed:
			_handle_left_press(mb.global_position)
		else:
			_handle_left_release(mb.global_position)
		return

	if event is InputEventMouseMotion and _active_drag:
		_active_drag.update_drag(event.global_position)


func _handle_left_press(global_pos: Vector2) -> void:
	# Already dragging? Ignore extra presses.
	if _active_drag:
		return

	# 1. Buttons first — they sit "on top" of the bins. Buttons only
	#    fire if they're enabled and visible.
	if _hit_button(craft_button, global_pos):
		if not craft_button.disabled:
			_on_craft_pressed()
		return
	if _hit_button(collect_button, global_pos):
		if not collect_button.disabled:
			_on_collect_pressed()
		return

	# 2. Pieces — walk in reverse z-order. We collect every piece in our
	#    tree (tray slots, bin, anywhere) and pick the topmost hit.
	var hit: WorkshopPiece = _find_topmost_piece_at(global_pos)
	if hit == null:
		return
	_pick_up(hit, global_pos)


func _handle_left_release(global_pos: Vector2) -> void:
	if _active_drag == null:
		return
	var piece: WorkshopPiece = _active_drag
	_active_drag = null
	piece.end_drag()

	# Tray-originated piece logic — see _on_tray_grab. If the player
	# pulled from a tray slot but never moved, snap home rather than
	# trying to drop on something. We approximate "never moved" via the
	# piece's home_parent being a tray slot AND the cursor still being
	# inside that slot's rect. (Tray slots' names start with "Tray_".)
	# Most cases this just falls through to the normal drop logic.

	# 1. Assembly slot? Only for segment pieces.
	if piece.segment_id != &"":
		for slot_id in _assembly_slots:
			var slot: WorkshopAssemblySlot = _assembly_slots[slot_id]
			if slot.is_valid_drop(piece, global_pos):
				_place_segment(slot, piece)
				return

	# 2. Craft bin?
	if craft_bin.accepts_point(global_pos):
		_drop_into_bin(piece, global_pos)
		return

	# 3. Nothing — snap home.
	piece.snap_home()


# --- hit testing helpers ---

func _hit_button(btn: Button, global_pos: Vector2) -> bool:
	if btn == null or not btn.visible or not btn.is_visible_in_tree():
		return false
	return btn.get_global_rect().has_point(global_pos)


## Walk every piece in our subtree and return the topmost (latest in
## sibling order = drawn on top) whose global rect contains the point.
func _find_topmost_piece_at(global_pos: Vector2) -> WorkshopPiece:
	var hits: Array = []
	_collect_pieces(self, hits)
	# `hits` is in tree-walk order. The Control draw order is sibling
	# order, with later siblings drawing on top. The simplest correct
	# pick is to walk hits in reverse and take the first that contains
	# the point.
	for i in range(hits.size() - 1, -1, -1):
		var piece: WorkshopPiece = hits[i]
		if piece.hit_test(global_pos):
			return piece
	return null


func _collect_pieces(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is WorkshopPiece:
			out.append(child)
		_collect_pieces(child, out)


# --- pick-up ---

func _pick_up(piece: WorkshopPiece, global_pos: Vector2) -> void:
	_active_drag = piece

	# Lift to top of the minigame so we draw above bins/slots.
	if piece.get_parent() != self:
		var gp: Vector2 = piece.global_position
		piece.get_parent().remove_child(piece)
		add_child(piece)
		piece.global_position = gp
	move_child(piece, get_child_count() - 1)

	piece.start_drag(global_pos)

	# Tray-side bookkeeping: if the piece was pulled from a tray slot,
	# the tray needs to know so it can spawn a replacement tile (if the
	# player still has more of that ingredient).
	if piece.home_parent and piece.home_parent.get_parent() == ingredients_tray:
		# home_parent is the tray slot Control; its name encodes the id.
		var id: String = String(piece.home_parent.name).trim_prefix("Tray_")
		call_deferred("_maybe_replace_tray_tile", id, piece.home_parent)


# --- drop into bin ---

func _drop_into_bin(piece: WorkshopPiece, global_drop_pos: Vector2) -> void:
	if piece.get_parent() != craft_bin:
		var current_parent: Node = piece.get_parent()
		if current_parent:
			current_parent.remove_child(piece)
		craft_bin.add_child(piece)

	# Place so the piece's CENTER lands on the drop position.
	var local_pos: Vector2 = craft_bin.get_global_transform().affine_inverse() * global_drop_pos
	piece.position = local_pos - piece.size * 0.5
	# Clamp inside the bin so a piece doesn't bleed off-edge.
	piece.position.x = clamp(piece.position.x, 0, max(0, craft_bin.size.x - piece.size.x))
	piece.position.y = clamp(piece.position.y, 0, max(0, craft_bin.size.y - piece.size.y))

	piece.home_parent = craft_bin
	craft_bin.contents_changed.emit()


# --- ingredients tray ---

func _populate_ingredients_tray() -> void:
	for child in ingredients_tray.get_children():
		child.queue_free()

	# Native pixel sizes — we're rendering 1:1 so these are real pixels.
	const SLOT_SIZE: Vector2 = Vector2(40, 40)
	const SLOT_PAD: Vector2 = Vector2(6, 6)
	const MAX_COLS: int = 4

	var col: int = 0
	var row: int = 0
	for id_key in GameState.ingredients.keys():
		var id: String = String(id_key)
		var count: int = int(GameState.ingredients[id])
		if count <= 0:
			continue

		var slot := Control.new()
		slot.name = "Tray_" + id
		slot.custom_minimum_size = SLOT_SIZE
		slot.size = SLOT_SIZE
		slot.position = Vector2(
			col * (SLOT_SIZE.x + SLOT_PAD.x),
			row * (SLOT_SIZE.y + SLOT_PAD.y),
		)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ingredients_tray.add_child(slot)

		var tile: WorkshopPiece = _make_ingredient_piece(id)
		if tile:
			tile.size = SLOT_SIZE
			tile.home_parent = slot
			slot.add_child(tile)
			tile.position = Vector2.ZERO

		var badge := Label.new()
		badge.name = "Count"
		badge.text = "x%d" % count
		badge.add_theme_font_size_override("font_size", 10)
		badge.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 3)
		badge.position = Vector2(SLOT_SIZE.x - 22, SLOT_SIZE.y - 14)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(badge)

		col += 1
		if col >= MAX_COLS:
			col = 0
			row += 1


func _make_ingredient_piece(id: String) -> WorkshopPiece:
	var tex_path: String = String(INGREDIENT_PATHS.get(id, ""))
	if tex_path == "" or not ResourceLoader.exists(tex_path):
		tex_path = "res://assets/textures/icons/placeholder_item.png"
		if not ResourceLoader.exists(tex_path):
			return null

	var piece := WorkshopPiece.new()
	piece.item_id = StringName(id)
	piece.segment_id = &""
	piece.texture = load(tex_path)

	var shadow_path: String = String(INGREDIENT_SHADOW_PATHS.get(id, ""))
	if shadow_path != "" and ResourceLoader.exists(shadow_path):
		piece.shadow_texture = load(shadow_path)

	return piece


func _maybe_replace_tray_tile(id: String, source_slot: Control) -> void:
	if source_slot == null or not is_instance_valid(source_slot):
		return
	# Already has a piece? Don't stack.
	for child in source_slot.get_children():
		if child is WorkshopPiece:
			return

	var available: int = _available_count(id)
	var badge: Label = source_slot.get_node_or_null("Count")
	if badge:
		badge.text = "x%d" % max(available, 0)

	if available <= 0:
		return

	var tile: WorkshopPiece = _make_ingredient_piece(id)
	if tile == null:
		return
	tile.size = source_slot.size
	tile.home_parent = source_slot
	source_slot.add_child(tile)
	tile.position = Vector2.ZERO


## How many of `id` are visually available (= total owned minus what's
## currently sitting in the bin queued for craft).
func _available_count(id: String) -> int:
	var total: int = int(GameState.ingredients.get(id, 0))
	var in_bin: int = 0
	for piece in craft_bin.all_pieces():
		if String(piece.item_id) == id:
			in_bin += 1
	return total - in_bin


## After CRAFT, refresh all tray badges (since counts decreased).
func _refresh_tray_counts() -> void:
	for slot in ingredients_tray.get_children():
		var id: String = String(slot.name).trim_prefix("Tray_")
		var available: int = _available_count(id)
		var badge: Label = slot.get_node_or_null("Count")
		if badge:
			badge.text = "x%d" % max(available, 0)
		var has_piece: bool = false
		for child in slot.get_children():
			if child is WorkshopPiece:
				has_piece = true
				break
		if not has_piece and available > 0:
			_maybe_replace_tray_tile(id, slot)


# --- craft ---

func _refresh_craft_button() -> void:
	if _crafted:
		craft_button.disabled = true
		return
	craft_button.disabled = not _bin_has_recipe()


func _bin_has_recipe() -> bool:
	var counts: Dictionary = craft_bin.count_items()
	for id_key in recipe_inputs:
		var need: int = int(recipe_inputs[id_key])
		var have: int = int(counts.get(String(id_key), 0))
		if have < need:
			return false
	return true


func _on_craft_pressed() -> void:
	if _crafted or not _bin_has_recipe():
		return
	_crafted = true

	# Consume from GameState (the source of truth).
	for id_key in recipe_inputs:
		var id: String = String(id_key)
		var need: int = int(recipe_inputs[id_key])
		GameState.ingredients[id] = max(0, int(GameState.ingredients.get(id, 0)) - need)

	craft_bin.clear_pieces()
	craft_bin.output_mode = true
	_spawn_segment_pieces_into_bin()

	_refresh_tray_counts()
	craft_button.disabled = true
	collect_button.visible = true


func _spawn_segment_pieces_into_bin() -> void:
	var center: Vector2 = craft_bin.local_center()
	# Native pixel grid since we're 1:1.
	var grid_cols: int = 4
	var spacing: float = 24.0
	var i: int = 0

	for seg_id in _segments:
		var seg: Dictionary = _segments[seg_id]
		for piece_def in seg["pieces"]:
			var piece: WorkshopPiece = _make_segment_piece(seg_id, piece_def)
			if piece == null:
				continue
			craft_bin.add_child(piece)
			piece.home_parent = craft_bin

			var col: int = i % grid_cols
			var row: int = i / grid_cols
			var grid_origin: Vector2 = center - Vector2(grid_cols - 1, 0) * (spacing * 0.5)
			piece.position = grid_origin + Vector2(col * spacing, row * spacing) \
				- piece.size * 0.5
			i += 1

	craft_bin.contents_changed.emit()


func _make_segment_piece(seg_id: StringName, piece_def: Dictionary) -> WorkshopPiece:
	var tex: Texture2D = piece_def.get("texture")
	if tex == null:
		push_warning("Workshop: missing texture for piece %s in segment %s" % [
			piece_def.get("id", "?"), seg_id])
		return null

	var piece := WorkshopPiece.new()
	piece.item_id = StringName(piece_def.get("id", ""))
	piece.segment_id = seg_id
	piece.texture = tex
	piece.shadow_texture = piece_def.get("shadow")
	piece.piece_offset = piece_def.get("offset", Vector2.ZERO)
	piece.shadow_offset = piece_def.get("shadow_offset", Vector2.ZERO)
	piece.size = tex.get_size()
	return piece


# --- place a segment ---

func _place_segment(slot: WorkshopAssemblySlot, _dropped_piece: WorkshopPiece) -> void:
	var seg_id: StringName = slot.accepts_segment_id

	var gathered: Array = []
	_gather_pieces_for_segment(self, seg_id, gathered)

	slot.place_segment(gathered)
	craft_bin.contents_changed.emit()
	_refresh_collect_button()


func _gather_pieces_for_segment(node: Node, seg_id: StringName, out: Array) -> void:
	for child in node.get_children():
		if child is WorkshopPiece and child.segment_id == seg_id and not child.locked:
			out.append(child)
		_gather_pieces_for_segment(child, seg_id, out)


# --- collect ---

func _refresh_collect_button() -> void:
	var all_filled: bool = true
	for slot_id in _assembly_slots:
		var slot: WorkshopAssemblySlot = _assembly_slots[slot_id]
		if not slot.filled:
			all_filled = false
			break
	collect_button.disabled = not all_filled


func _on_collect_pressed() -> void:
	collected.emit()


# --- segment table construction (unchanged from previous version) ---

func _build_segment_table() -> void:
	# Anchors in NATIVE source pixels (Workshop renders 1:1 in the 500x400
	# bottom slice of the pan image). Assembly area lives at x in [252, 488]
	# and y in [12, 384]. We pin segments around x = 374 (center of that
	# range relative to assembly local space, which is x in [0, 236]).
	var anchor_x: float = 118.0

	var add = func(seg_id: String, anchor: Vector2, pieces: Array) -> void:
		_segments[StringName(seg_id)] = {
			"anchor": anchor,
			"pieces": pieces,
		}

	var tex = func(rel_path: String) -> Texture2D:
		var full: String = LEG_PART_ROOT + rel_path
		if not ResourceLoader.exists(full):
			push_warning("Workshop: missing texture %s" % full)
			return null
		return load(full)

	var sha = func(rel_path: String) -> Texture2D:
		var full: String = LEG_PART_ROOT + rel_path
		if not ResourceLoader.exists(full):
			return null
		return load(full)

	add.call("butt", Vector2(anchor_x, 10), [
		{"id": &"butt",
		 "texture": tex.call("robot_leg_thighs/butt.png"),
		 "shadow":  sha.call("robot_leg_shadow/butt_shadow.png"),
		 "offset":  Vector2(0, 0),
		 "shadow_offset": Vector2(-2, 2)},
	])

	add.call("upper_thigh", Vector2(anchor_x, 40), [
		{"id": &"upper_thigh",
		 "texture": tex.call("robot_leg_thighs/upper_thigh.png"),
		 "shadow":  sha.call("robot_leg_shadow/upper_thigh_shadow.png"),
		 "offset":  Vector2(0, 0),
		 "shadow_offset": Vector2(-2, 2)},
		{"id": &"upper_thigh_gears",
		 "texture": tex.call("robot_leg_thighs/upper_thigh_gears.png"),
		 "shadow":  null,
		 "offset":  Vector2(0, 0),
		 "shadow_offset": Vector2.ZERO},
	])

	add.call("mid_thigh", Vector2(anchor_x, 80), [
		{"id": &"mid_thigh",
		 "texture": tex.call("robot_leg_thighs/mid_thigh.png"),
		 "shadow":  sha.call("robot_leg_shadow/mid_thighs_gear_shadow.png"),
		 "offset":  Vector2(0, 0),
		 "shadow_offset": Vector2(-2, 2)},
		{"id": &"mid_thigh_gears",
		 "texture": tex.call("robot_leg_thighs/mid_thigh_gears.png"),
		 "shadow":  null,
		 "offset":  Vector2(0, 0),
		 "shadow_offset": Vector2.ZERO},
	])

	add.call("side_thigh", Vector2(anchor_x, 120), [
		{"id": &"side_thigh",
		 "texture": tex.call("robot_leg_thighs/side_thigh.png"),
		 "shadow":  sha.call("robot_leg_shadow/side_thigh_shadow.png"),
		 "offset":  Vector2(0, 0),
		 "shadow_offset": Vector2(-2, 2)},
	])

	add.call("knee", Vector2(anchor_x, 160), [
		{"id": &"knee_joint",
		 "texture": tex.call("robot_leg_thighs/knee_joint.png"),
		 "shadow":  sha.call("robot_leg_shadow/knee_joint_shadow.png"),
		 "offset":  Vector2(0, 0),
		 "shadow_offset": Vector2(-2, 2)},
		{"id": &"knee_joint_axel",
		 "texture": tex.call("robot_leg_thighs/knee_joint_axel.png"),
		 "shadow":  null,
		 "offset":  Vector2(0, 0),
		 "shadow_offset": Vector2.ZERO},
		{"id": &"knee",
		 "texture": tex.call("robot_leg_thighs/knee.png"),
		 "shadow":  sha.call("robot_leg_shadow/knee_shadow.png"),
		 "offset":  Vector2(0, 0),
		 "shadow_offset": Vector2(-2, 2)},
	])

	add.call("calf", Vector2(anchor_x, 200), [
		{"id": &"calf",
		 "texture": tex.call("robot_leg_lower_legs/calf.png"),
		 "shadow":  sha.call("robot_leg_shadow/calf_shadow.png"),
		 "offset":  Vector2(0, 0),
		 "shadow_offset": Vector2(-2, 2)},
		{"id": &"inner_gears",
		 "texture": tex.call("robot_leg_lower_legs/inner_gears.png"),
		 "shadow":  sha.call("robot_leg_shadow/inner_gear_side_thigh_shadow.png"),
		 "offset":  Vector2(0, 0),
		 "shadow_offset": Vector2(-2, 2)},
	])

	add.call("lower_leg", Vector2(anchor_x, 235), [
		{"id": &"lower_leg",
		 "texture": tex.call("robot_leg_lower_legs/lower_leg.png"),
		 "shadow":  sha.call("robot_leg_shadow/lower_leg_shadow.png"),
		 "offset":  Vector2(0, 0),
		 "shadow_offset": Vector2(-2, 2)},
		{"id": &"shin",
		 "texture": tex.call("robot_leg_lower_legs/shin.png"),
		 "shadow":  sha.call("robot_leg_shadow/shin_shadow.png"),
		 "offset":  Vector2(0, 0),
		 "shadow_offset": Vector2(-2, 2)},
	])

	add.call("ankle", Vector2(anchor_x, 270), [
		{"id": &"ankle_cap",
		 "texture": tex.call("robot_leg_ankle_cap.png"),
		 "shadow":  sha.call("robot_leg_shadow/ankle_shadow.png"),
		 "offset":  Vector2(0, 0),
		 "shadow_offset": Vector2(-2, 2)},
		{"id": &"ankle_axel",
		 "texture": tex.call("robot_leg_foot/ankle_axel.png"),
		 "shadow":  null,
		 "offset":  Vector2(0, 0),
		 "shadow_offset": Vector2.ZERO},
	])

	add.call("foot", Vector2(anchor_x, 305), [
		{"id": &"upper_foot",
		 "texture": tex.call("robot_leg_foot/upper_foot.png"),
		 "shadow":  sha.call("robot_leg_shadow/upper_foot_shadow.png"),
		 "offset":  Vector2(0, 0),
		 "shadow_offset": Vector2(-2, 2)},
		{"id": &"heel",
		 "texture": tex.call("robot_leg_foot/heel.png"),
		 "shadow":  sha.call("robot_leg_shadow/heel_shadow.png"),
		 "offset":  Vector2(0, 0),
		 "shadow_offset": Vector2(-2, 2)},
		{"id": &"middle_foot",
		 "texture": tex.call("robot_leg_foot/middle_foot.png"),
		 "shadow":  sha.call("robot_leg_shadow/middle_foot_shadow.png"),
		 "offset":  Vector2(0, 0),
		 "shadow_offset": Vector2(-2, 2)},
		{"id": &"toes",
		 "texture": tex.call("robot_leg_foot/toes.png"),
		 "shadow":  sha.call("robot_leg_shadow/toes_shadow.png"),
		 "offset":  Vector2(0, 0),
		 "shadow_offset": Vector2(-2, 2)},
		{"id": &"toes_border",
		 "texture": tex.call("robot_leg_foot/toes_border.png"),
		 "shadow":  null,
		 "offset":  Vector2(0, 0),
		 "shadow_offset": Vector2.ZERO},
	])


# --- assembly slot lookup ---

func _collect_assembly_slots() -> void:
	_assembly_slots.clear()
	for child in assembly.get_children():
		if child is WorkshopAssemblySlot:
			_assembly_slots[String(child.accepts_segment_id)] = child
			child.placed.connect(_on_slot_placed)


func _on_slot_placed(_slot: WorkshopAssemblySlot) -> void:
	_refresh_collect_button()
