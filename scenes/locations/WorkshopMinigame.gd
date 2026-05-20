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

var _active_drag_segment: WorkshopSegment = null
var _active_drag_piece: WorkshopPiece = null

var _crafted: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

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

	if event is InputEventMouseMotion:
		if _active_drag_segment:
			_active_drag_segment.update_drag(event.global_position)
		elif _active_drag_piece:
			_active_drag_piece.update_drag(event.global_position)


func _handle_left_press(global_pos: Vector2) -> void:
	if _active_drag_segment or _active_drag_piece:
		return

	if _hit_button(craft_button, global_pos):
		if not craft_button.disabled:
			_on_craft_pressed()
		return
	if _hit_button(collect_button, global_pos):
		if not collect_button.disabled:
			_on_collect_pressed()
		return

	var seg: WorkshopSegment = _find_topmost_segment_at(global_pos)
	if seg != null:
		_pick_up_segment(seg, global_pos)
		return

	var hit: WorkshopPiece = _find_topmost_piece_at(global_pos)
	if hit == null:
		return
	_pick_up_piece(hit, global_pos)


func _handle_left_release(global_pos: Vector2) -> void:
	if _active_drag_segment != null:
		var segment: WorkshopSegment = _active_drag_segment
		_active_drag_segment = null
		segment.end_drag()

		for slot_id in _assembly_slots:
			var slot: WorkshopAssemblySlot = _assembly_slots[slot_id]
			if slot.is_valid_drop_for_segment(segment, global_pos):
				slot.accept_segment(segment)
				_refresh_collect_button()
				return
		return

	if _active_drag_piece != null:
		var piece: WorkshopPiece = _active_drag_piece
		_active_drag_piece = null
		piece.end_drag()

		if craft_bin.accepts_point(global_pos):
			_drop_into_bin(piece, global_pos)
			return

		piece.snap_home()


# --- hit testing helpers ---

func _hit_button(btn: Button, global_pos: Vector2) -> bool:
	if btn == null or not btn.visible or not btn.is_visible_in_tree():
		return false
	return btn.get_global_rect().has_point(global_pos)


func _find_topmost_segment_at(global_pos: Vector2) -> WorkshopSegment:
	var hits: Array = []
	_collect_segments(self, hits)
	for i in range(hits.size() - 1, -1, -1):
		var seg: WorkshopSegment = hits[i]
		if seg.hit_test(global_pos):
			return seg
	return null


func _collect_segments(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is WorkshopSegment:
			out.append(child)
		_collect_segments(child, out)


func _find_topmost_piece_at(global_pos: Vector2) -> WorkshopPiece:
	var hits: Array = []
	_collect_pieces(self, hits)
	for i in range(hits.size() - 1, -1, -1):
		var piece: WorkshopPiece = hits[i]
		if _piece_is_inside_segment(piece):
			continue
		if piece.hit_test(global_pos):
			return piece
	return null


func _collect_pieces(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is WorkshopPiece:
			out.append(child)
		_collect_pieces(child, out)


func _piece_is_inside_segment(piece: WorkshopPiece) -> bool:
	var n: Node = piece.get_parent()
	while n != null:
		if n is WorkshopSegment:
			return true
		n = n.get_parent()
	return false


# --- pick-up ---

func _pick_up_segment(segment: WorkshopSegment, global_pos: Vector2) -> void:
	_active_drag_segment = segment
	if segment.get_parent() != self:
		var gp: Vector2 = segment.global_position
		segment.get_parent().remove_child(segment)
		add_child(segment)
		segment.global_position = gp
	move_child(segment, get_child_count() - 1)
	segment.start_drag(global_pos)


func _pick_up_piece(piece: WorkshopPiece, global_pos: Vector2) -> void:
	_active_drag_piece = piece
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
	_spawn_segments_stacked_at_bin_center()

	_refresh_tray_counts()
	craft_button.disabled = true
	collect_button.visible = true


# Spawn every segment overlapping at the center of the craft bin.
# IMPORTANT: We center using the segment's GRAB HITBOX (the tight bounds
# of the visible art) — NOT the segment's Control size, which is the
# full texture canvas. Texture canvases are usually huge with most of
# the canvas being transparent, and the visible art lives at a different
# spot within each canvas. Centering by canvas size would just lay the
# textures down in their authored positions, reconstructing the leg.
func _spawn_segments_stacked_at_bin_center() -> void:
	var bin_center_global: Vector2 = craft_bin.get_global_transform() \
		* craft_bin.local_center()
	var bin_center_local: Vector2 = get_global_transform().affine_inverse() \
		* bin_center_global

	for seg_id in _segments:
		var seg_data: Dictionary = _segments[seg_id]
		var pieces_defs: Array = seg_data["pieces"]

		var segment := WorkshopSegment.new()
		segment.name = "Segment_" + String(seg_id)
		segment.segment_id = seg_id
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Build the segment Control sized to the full texture canvas
		# (pieces draw into their own texture coordinates, so we need
		# the Control big enough to contain those draws).
		var bounds: Rect2 = Rect2()
		var found_any: bool = false

		for piece_def in pieces_defs:
			var piece: WorkshopPiece = _make_segment_piece(seg_id, piece_def)
			if piece == null:
				continue
			segment.add_child(piece)
			piece.position = Vector2.ZERO

			if piece.texture != null:
				var tex_rect := Rect2(Vector2.ZERO, piece.texture.get_size())
				if not found_any:
					bounds = tex_rect
					found_any = true
				else:
					bounds = bounds.merge(tex_rect)

		if not found_any:
			push_warning("Workshop: segment '%s' has no pieces with textures — skipped spawn." % seg_id)
			segment.queue_free()
			continue

		segment.size = bounds.size

		add_child(segment)

		# Fit the grab hitbox to the union of every piece's
		# non-transparent pixels. This runs synchronously (it's a setter
		# that calls _auto_fit_grab_hitbox immediately), so grab_hitbox_rect
		# is populated before the next line.
		segment.auto_fit_grab_hitbox = true

		# Center the segment so the CENTER OF THE GRAB HITBOX (i.e. the
		# visible art) lands on the bin's center. The hitbox is in
		# segment-local coords, so:
		#   art_center_global = segment.position + hitbox.position + hitbox.size * 0.5
		# Solving for segment.position to put art_center at bin_center_local:
		var hb: Rect2 = segment.grab_hitbox_rect
		if hb.size.x > 0.0 and hb.size.y > 0.0:
			var hb_center_in_segment: Vector2 = hb.position + hb.size * 0.5
			segment.position = bin_center_local - hb_center_in_segment
		else:
			# Hitbox didn't get computed (e.g. all pieces transparent).
			# Fall back to canvas-center positioning so the segment is
			# at least somewhere visible.
			segment.position = bin_center_local - segment.size * 0.5
			push_warning("Workshop: segment '%s' has no usable grab hitbox — fell back to canvas-center positioning." % seg_id)

	craft_bin.contents_changed.emit()


func _make_segment_piece(seg_id: StringName, piece_def: Dictionary) -> WorkshopPiece:
	var tex: Texture2D = piece_def.get("texture")
	if tex == null:
		push_warning("Workshop: piece '%s' in segment '%s' has no texture in the .tscn — skipping." % [
			piece_def.get("id", "?"), seg_id])
		return null

	var piece := WorkshopPiece.new()
	piece.item_id = StringName(piece_def.get("id", ""))
	piece.segment_id = seg_id
	piece.texture = tex
	piece.shadow_texture = piece_def.get("shadow")

	piece.piece_offset = Vector2.ZERO
	piece.visual_offset = Vector2.ZERO
	piece.shadow_offset = Vector2.ZERO
	piece.auto_center = false

	piece.size = tex.get_size()

	return piece


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


# --- EDITOR HARVESTING ---

func _collect_assembly_slots() -> void:
	_assembly_slots.clear()
	_segments.clear()
	_collect_slots_recursive(assembly)


func _collect_slots_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is WorkshopAssemblySlot:
			var slot: WorkshopAssemblySlot = child
			var slot_id: String = String(slot.accepts_segment_id)
			_assembly_slots[slot_id] = slot
			slot.placed.connect(_on_slot_placed)

			var pieces: Array = []
			for i in range(slot.get_child_count() - 1, -1, -1):
				var p: Node = slot.get_child(i)
				if p is WorkshopPiece:
					if p.texture == null:
						push_warning("Workshop: piece '%s' under slot '%s' has no texture set in the .tscn." % [p.name, slot.name])
					var def: Dictionary = {
						"id": p.item_id,
						"texture": p.texture,
						"shadow": p.shadow_texture,
					}
					pieces.append(def)
					slot.remove_child(p)
					p.queue_free()

			if pieces.size() == 0:
				push_warning("Workshop: slot '%s' (segment '%s') has no WorkshopPiece children — no segment will spawn for it." % [slot.name, slot_id])
			else:
				_segments[StringName(slot_id)] = {
					"pieces": pieces
				}
		else:
			_collect_slots_recursive(child)


func _on_slot_placed(_slot: WorkshopAssemblySlot) -> void:
	_refresh_collect_button()
