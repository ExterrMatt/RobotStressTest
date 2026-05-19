extends Control
class_name WorkshopMinigame

signal collected

@export var recipe_inputs: Dictionary = {
	"scrap_metal": 1,
}

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

@onready var ingredients_tray: Control = %IngredientsTray
@onready var craft_bin: WorkshopBin = %CraftBin
@onready var craft_button: Button = %CraftButton
@onready var assembly: Control = %AssemblyArea
@onready var collect_button: Button = %CollectButton

var _segments: Dictionary = {}
var _assembly_slots: Dictionary = {}
var _active_drag: WorkshopPiece = null
var _crafted: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Reads the manually placed pieces out of the editor tree!
	_collect_assembly_slots()
	_populate_ingredients_tray()

	craft_bin.contents_changed.connect(_refresh_craft_button)

	craft_button.disabled = true
	collect_button.disabled = true
	collect_button.visible = false

# --- global input pipe ---

func _input(event: InputEvent) -> void:
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
	if _active_drag:
		return

	if _hit_button(craft_button, global_pos):
		if not craft_button.disabled:
			_on_craft_pressed()
		return
	if _hit_button(collect_button, global_pos):
		if not collect_button.disabled:
			_on_collect_pressed()
		return

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

	if piece.segment_id != &"":
		for slot_id in _assembly_slots:
			var slot: WorkshopAssemblySlot = _assembly_slots[slot_id]
			if slot.is_valid_drop(piece, global_pos):
				_place_segment(slot, piece)
				return

	if craft_bin.accepts_point(global_pos):
		_drop_into_bin(piece, global_pos)
		return

	piece.snap_home()

# --- hit testing helpers ---

func _hit_button(btn: Button, global_pos: Vector2) -> bool:
	if btn == null or not btn.visible or not btn.is_visible_in_tree():
		return false
	return btn.get_global_rect().has_point(global_pos)

func _make_piece_from_def(piece_def: Dictionary, seg_id: StringName) -> WorkshopPiece:
	var tex: Texture2D = piece_def.get("texture")
	if tex == null:
		push_warning("WorkshopMinigame: piece def for segment '%s' has no texture." % [seg_id])
		return null
 
	var piece := WorkshopPiece.new()
	piece.item_id = StringName(piece_def.get("id", ""))
	piece.segment_id = seg_id
	piece.texture = tex
	piece.shadow_texture = piece_def.get("shadow")
 
	piece.piece_offset = piece_def.get("offset", Vector2.ZERO)
	piece.visual_offset = piece_def.get("visual_offset", Vector2.ZERO)
	piece.shadow_offset = piece_def.get("shadow_offset", Vector2.ZERO)
	piece.size = piece_def.get("size", tex.get_size())
 
	# NEW: carry the editor-tuned hitbox into the runtime piece.
	piece.hitbox_rect = piece_def.get("hitbox_rect", Rect2())
 
	return piece


func _find_topmost_piece_at(global_pos: Vector2) -> WorkshopPiece:
	var hits: Array = []
	_collect_pieces(self, hits)
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

# --- pick-up / drop ---

func _pick_up(piece: WorkshopPiece, global_pos: Vector2) -> void:
	_active_drag = piece
	if piece.get_parent() != self:
		var gp: Vector2 = piece.global_position
		piece.get_parent().remove_child(piece)
		add_child(piece)
		piece.global_position = gp
	move_child(piece, get_child_count() - 1)
	piece.start_drag(global_pos)

	if piece.home_parent and piece.home_parent.get_parent() == ingredients_tray:
		var id: String = String(piece.home_parent.name).trim_prefix("Tray_")
		call_deferred("_maybe_replace_tray_tile", id, piece.home_parent)

func _drop_into_bin(piece: WorkshopPiece, global_drop_pos: Vector2) -> void:
	if piece.get_parent() != craft_bin:
		var current_parent: Node = piece.get_parent()
		if current_parent:
			current_parent.remove_child(piece)
		craft_bin.add_child(piece)

	var local_pos: Vector2 = craft_bin.get_global_transform().affine_inverse() * global_drop_pos
	piece.position = local_pos - piece.size * 0.5
	piece.position.x = clamp(piece.position.x, 0, max(0, craft_bin.size.x - piece.size.x))
	piece.position.y = clamp(piece.position.y, 0, max(0, craft_bin.size.y - piece.size.y))

	piece.home_parent = craft_bin
	craft_bin.contents_changed.emit()

# --- ingredients tray ---

func _populate_ingredients_tray() -> void:
	for child in ingredients_tray.get_children():
		child.queue_free()

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
	
	# Ingredients auto-center themselves inside the 40x40 tray slots
	piece.auto_center = true

	var shadow_path: String = String(INGREDIENT_SHADOW_PATHS.get(id, ""))
	if shadow_path != "" and ResourceLoader.exists(shadow_path):
		piece.shadow_texture = load(shadow_path)

	return piece

func _maybe_replace_tray_tile(id: String, source_slot: Control) -> void:
	if source_slot == null or not is_instance_valid(source_slot):
		return
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

func _available_count(id: String) -> int:
	var total: int = int(GameState.ingredients.get(id, 0))
	var in_bin: int = 0
	for piece in craft_bin.all_pieces():
		if String(piece.item_id) == id:
			in_bin += 1
	return total - in_bin

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
	piece.visual_offset = piece_def.get("visual_offset", Vector2.ZERO)
	piece.shadow_offset = piece_def.get("shadow_offset", Vector2.ZERO)
	piece.size = piece_def.get("size", tex.get_size())
	
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

# --- EDITOR HARVESTING ---

func _collect_assembly_slots() -> void:
	_assembly_slots.clear()
	_segments.clear()
 
	for child in assembly.get_children():
		if child is WorkshopAssemblySlot:
			var slot_id: String = String(child.accepts_segment_id)
			_assembly_slots[slot_id] = child
			child.placed.connect(_on_slot_placed)
 
			var pieces: Array = []
			for i in range(child.get_child_count() - 1, -1, -1):
				var p: Node = child.get_child(i)
				if p is WorkshopPiece:
					var def: Dictionary = {
						"id": p.item_id,
						"texture": p.texture,
						"shadow": p.shadow_texture,
						"offset": p.position,
						"visual_offset": p.visual_offset,
						"shadow_offset": p.shadow_offset,
						"size": p.size,
						"hitbox_rect": p.hitbox_rect,  # NEW
					}
					pieces.append(def)
					child.remove_child(p)
					p.queue_free()
 
			if pieces.size() > 0:
				_segments[StringName(slot_id)] = {
					"anchor": child.position,
					"pieces": pieces
				}


func _on_slot_placed(_slot: WorkshopAssemblySlot) -> void:
	_refresh_collect_button()
