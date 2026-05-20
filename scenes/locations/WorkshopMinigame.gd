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

# Active drag state.
# - _active_drag_segment is the MASTER: the segment the user actually clicked.
#   It's the only one that tracks its own drag bookkeeping.
# - _passenger_segments are non-master paired members. They do NOT
#   compute their own positions — they're teleported relative to the
#   master every frame using offsets captured at pickup time.
# - This guarantees zero drift (Issue 1) and that only the topmost
#   clicked segment becomes the drag root (Issue 4).
var _active_drag_segment: WorkshopSegment = null
var _passenger_segments: Array = []
var _passenger_offsets: Dictionary = {}  # WorkshopSegment -> Vector2 offset from master

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
			# Move the master via its normal drag bookkeeping. Then snap
			# every passenger to its locked offset from the master. No
			# independent drag math on passengers = no drift (Issue 1).
			_active_drag_segment.update_drag(event.global_position)
			var master_pos: Vector2 = _active_drag_segment.position
			for passenger in _passenger_segments:
				if passenger is WorkshopSegment and is_instance_valid(passenger):
					passenger.position = master_pos + _passenger_offsets.get(passenger, Vector2.ZERO)
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

	# ONLY the topmost segment under the cursor gets picked up (Issue 4).
	# Paired partners come along as passengers, never as independent drags.
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
		var master: WorkshopSegment = _active_drag_segment
		var passengers: Array = _passenger_segments.duplicate()

		# Clear active drag state up front so nothing can re-enter.
		_active_drag_segment = null
		_passenger_segments = []
		_passenger_offsets.clear()

		# Build the full group in master-first order.
		var group: Array = [master]
		for p in passengers:
			if p is WorkshopSegment and is_instance_valid(p):
				group.append(p)

		# All-or-nothing drop: every member must land in a valid goal.
		var drops: Array = []  # parallel array of [seg, target_slot_or_null]
		var all_valid: bool = true
		for seg in group:
			seg.end_drag()
			var target: WorkshopAssemblySlot = null
			for slot_id in _assembly_slots:
				var slot: WorkshopAssemblySlot = _assembly_slots[slot_id]
				if slot.is_valid_drop_for_segment(seg, global_pos):
					target = slot
					break
			if target == null:
				all_valid = false
			drops.append([seg, target])

		if all_valid:
			for entry in drops:
				var placing_seg: WorkshopSegment = entry[0]
				var placing_slot: WorkshopAssemblySlot = entry[1]
				placing_slot.accept_segment(placing_seg)
			_refresh_collect_button()
		# else: leave every group member where the player let go.
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


# Find the assembly slot whose accepts_segment_id matches this segment.
func _slot_for_segment(segment: WorkshopSegment) -> WorkshopAssemblySlot:
	for slot_id in _assembly_slots:
		var slot: WorkshopAssemblySlot = _assembly_slots[slot_id]
		if slot.accepts_segment_id == segment.segment_id:
			return slot
	return null


# This segment's slot's index in the AssemblyLeg's child list.
# Lower = drawn earlier (underneath). Returns -1 if not found.
func _slot_tree_index(segment: WorkshopSegment) -> int:
	var slot: WorkshopAssemblySlot = _slot_for_segment(segment)
	if slot == null:
		return -1
	if slot.get_parent() == null:
		return -1
	return slot.get_index()


# --- pick-up ---

func _pick_up_segment(segment: WorkshopSegment, global_pos: Vector2) -> void:
	# Build the passenger list: every non-locked pair partner of the
	# clicked segment. Self and locked partners are excluded.
	var passengers: Array = []
	for partner in segment.pair_partners:
		if partner is WorkshopSegment and is_instance_valid(partner) and not partner.locked:
			if partner != segment and not passengers.has(partner):
				passengers.append(partner)

	# Order ALL members (master + passengers) by slot tree position under
	# AssemblyLeg so the stacking is deterministic and matches the
	# authored layering. Earlier slot index = drawn underneath. Later
	# slot index = drawn on top (Issue 3).
	var all_members: Array = [segment]
	for p in passengers:
		all_members.append(p)
	all_members.sort_custom(func(a, b): return _slot_tree_index(a) < _slot_tree_index(b))

	# Reparent every member under the minigame root.
	for seg in all_members:
		if seg.get_parent() != self:
			var gp: Vector2 = seg.global_position
			seg.get_parent().remove_child(seg)
			add_child(seg)
			seg.global_position = gp
	# Now apply final sibling order: iterating bottom-up and moving each
	# to the end of the sibling list puts them in correct stacking order.
	for seg in all_members:
		move_child(seg, get_child_count() - 1)

	# Master state.
	_active_drag_segment = segment
	segment.start_drag(global_pos)

	# Lock every passenger's offset to the master at this exact moment.
	# They're now puppeted by the master in _input mouse-motion handling.
	_passenger_segments = passengers
	_passenger_offsets.clear()
	for p in passengers:
		_passenger_offsets[p] = p.position - segment.position


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
#
# For paired groups, the segments must maintain the SAME relative offset
# they have in the authored leg layout, so the visible art remains
# properly aligned (Issue 2). We do this in two passes:
#  1. Create every segment, build pieces inside, fit grab hitbox.
#  2. Wire pair partners from slot.paired_with.
#  3. For each pair group, pick the segment whose slot has the lowest
#     tree index as the "primary". Center its hitbox on the bin. Each
#     follower's position equals primary.position plus the offset
#     between their respective slot positions in the authored layout.
#     Solo (unpaired) segments still center their own hitbox on the bin
#     like before.
func _spawn_segments_stacked_at_bin_center() -> void:
	var bin_center_global: Vector2 = craft_bin.get_global_transform() \
		* craft_bin.local_center()
	var bin_center_local: Vector2 = get_global_transform().affine_inverse() \
		* bin_center_global

	# --- Pass 1: create segments and pieces ---
	var segments_by_id: Dictionary = {}  # StringName -> WorkshopSegment

	for seg_id in _segments:
		var seg_data: Dictionary = _segments[seg_id]
		var pieces_defs: Array = seg_data["pieces"]

		var segment := WorkshopSegment.new()
		segment.name = "Segment_" + String(seg_id)
		segment.segment_id = seg_id
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
		segment.auto_fit_grab_hitbox = true

		segments_by_id[seg_id] = segment

	# --- Pass 2: wire pair partners from slot.paired_with ---
	for slot_id in _assembly_slots:
		var slot: WorkshopAssemblySlot = _assembly_slots[slot_id]
		if String(slot.paired_with) == "":
			continue
		var this_seg: WorkshopSegment = segments_by_id.get(slot.accepts_segment_id)
		var other_seg: WorkshopSegment = segments_by_id.get(slot.paired_with)
		if this_seg and other_seg and not this_seg.pair_partners.has(other_seg):
			this_seg.pair_partners.append(other_seg)

	# --- Pass 3: position each segment ---
	var positioned: Dictionary = {}  # WorkshopSegment -> bool

	for seg_id in segments_by_id:
		var segment: WorkshopSegment = segments_by_id[seg_id]
		if positioned.get(segment, false):
			continue

		# Build this segment's full pair group (including itself).
		var group: Array = [segment]
		for partner in segment.pair_partners:
			if partner is WorkshopSegment and is_instance_valid(partner):
				if not group.has(partner):
					group.append(partner)

		# Pick the primary: lowest slot tree index. Stable regardless of
		# dictionary iteration order.
		var primary: WorkshopSegment = group[0]
		var primary_idx: int = _slot_tree_index(primary)
		for member in group:
			var idx: int = _slot_tree_index(member)
			if idx >= 0 and (primary_idx < 0 or idx < primary_idx):
				primary = member
				primary_idx = idx

		# Center the primary's hitbox on the bin center.
		var primary_hb: Rect2 = primary.grab_hitbox_rect
		if primary_hb.size.x > 0.0 and primary_hb.size.y > 0.0:
			var hb_center: Vector2 = primary_hb.position + primary_hb.size * 0.5
			primary.position = bin_center_local - hb_center
		else:
			primary.position = bin_center_local - primary.size * 0.5
			push_warning("Workshop: segment '%s' has no usable grab hitbox — fell back to canvas-center positioning." % primary.segment_id)
		positioned[primary] = true

		# Position each follower at the same offset from primary as the
		# offset between their slots in the authored layout. This
		# preserves the visual alignment of the assembled leg (Issue 2).
		var primary_slot: WorkshopAssemblySlot = _slot_for_segment(primary)
		if primary_slot == null:
			continue
		var primary_slot_global: Vector2 = primary_slot.get_global_transform().origin

		for member in group:
			if member == primary:
				continue
			var member_slot: WorkshopAssemblySlot = _slot_for_segment(member)
			if member_slot == null:
				continue
			var member_slot_global: Vector2 = member_slot.get_global_transform().origin
			var offset_global: Vector2 = member_slot_global - primary_slot_global
			# Both segments live under the minigame Control (no scale/rotate)
			# so global offset equals local offset in pixels.
			member.position = primary.position + offset_global
			positioned[member] = true

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
