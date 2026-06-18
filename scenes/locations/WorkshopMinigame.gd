extends Control
class_name WorkshopMinigame

signal collected(part_id: String)

const CRAFTABLE_PARTS: Dictionary = {
	"leg": {
		"display_name": "Leg",
		"recipe": {"nanobots": 1, "scrap_metal": 1, "nuts_bolts": 1},
	},
	"arm": {
		"display_name": "Arm",
		"recipe": {"nanobots": 1},
	},
	"torso": {
		"display_name": "Torso",
		"recipe": {"electronics": 1},
	},
	"hand": {
		"display_name": "Hand",
		"recipe": {"synth_skin": 1},
	},
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
const UI_SOUND := preload("res://scenes/ui/UiSound.gd")

@onready var ingredients_tray: Control = %IngredientsTray
@onready var craft_bin: WorkshopBin = %CraftBin
@onready var craft_button: Button = %CraftButton
@onready var assembly: Control = %AssemblyArea
@onready var collect_button: Button = %CollectButton

var _segments: Dictionary = {}
var _assembly_slots: Dictionary = {}

var _active_drag_segment: WorkshopSegment = null
var _passenger_segments: Array = []
var _passenger_offsets: Dictionary = {} 

var _active_drag_piece: WorkshopPiece = null

var _crafted: bool = false
var _crafted_part_id: String = ""

var _shadow_group: CanvasGroup = null
var _shadow_drawer: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Set up global shadow rendering layer (drawn entirely behind pieces)
	_shadow_group = CanvasGroup.new()
	_shadow_group.name = "ShadowLayer"
	# CanvasGroup modulates the compiled intersection of textures dynamically
	_shadow_group.modulate = Color(1, 1, 1, 0.25)
	_shadow_group.fit_margin = 250.0 
	add_child(_shadow_group)
	move_child(_shadow_group, 0)

	_shadow_drawer = Control.new()
	_shadow_drawer.name = "ShadowDrawer"
	_shadow_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Guarantee the CanvasGroup never culls our custom draws
	_shadow_drawer.position = Vector2(-2000, -2000)
	_shadow_drawer.size = Vector2(6000, 6000)
	
	# THE NEW FIX: Use a shader to force the drawn shadow textures to be 
	# 100% opaque. This stops baked-in transparency from accumulating 
	# on overlaps. The CanvasGroup will uniformly apply 50% opacity to the result.
	var shadow_mat := ShaderMaterial.new()
	var shadow_shader := Shader.new()
	shadow_shader.code = """
	shader_type canvas_item;
	void fragment() {
		vec4 tex = texture(TEXTURE, UV);
		// Multiply alpha to force the core to 1.0 (fully opaque), ensuring overlaps don't darken.
		// (Using 5.0 ensures even very faint soft edges are caught and boosted to opaque)
		COLOR = vec4(0.0, 0.0, 0.0, clamp(tex.a * 5.0, 0.0, 1.0));
	}
	"""
	shadow_mat.shader = shadow_shader
	_shadow_drawer.material = shadow_mat
	
	_shadow_drawer.draw.connect(_on_shadow_drawer_draw)
	_shadow_group.add_child(_shadow_drawer)

	_collect_assembly_slots()
	_populate_ingredients_tray()

	craft_bin.contents_changed.connect(_refresh_craft_button)

	craft_button.disabled = true
	craft_button.text = "CRAFT"
	collect_button.disabled = true
	collect_button.visible = false
	collect_button.text = "COLLECT"


func _process(_delta: float) -> void:
	# Force shadow drawer to redraw every frame so shadows follow smoothly while dragging
	if is_instance_valid(_shadow_drawer):
		_shadow_drawer.queue_redraw()
	_sync_passenger_segments_to_active_drag()


func _on_shadow_drawer_draw() -> void:
	_draw_shadows_recursive(self)
	_shadow_drawer.draw_set_transform_matrix(Transform2D()) # Clean up standard bounds


func _draw_shadows_recursive(node: Node) -> void:
	for child in node.get_children():
		if child == _shadow_group:
			continue # Do not recursively render inside the shadow drawer
			
		if child is WorkshopPiece and child.shadow_texture != null and child.is_visible_in_tree():
			# Matrix transform guarantees scale/rotation/translations align perfectly identically
			var s_xform: Transform2D = _shadow_drawer.get_global_transform().affine_inverse() * child.get_global_transform()
			_shadow_drawer.draw_set_transform_matrix(s_xform)
			
			var v_off: Vector2 = child.visual_offset if typeof(child.visual_offset) == TYPE_VECTOR2 else Vector2.ZERO
			var s_off: Vector2 = child.shadow_offset if typeof(child.shadow_offset) == TYPE_VECTOR2 else Vector2.ZERO
			
			var tex_pos: Vector2 = v_off
			if child.auto_center and child.texture != null:
				tex_pos = (child.size - child.texture.get_size()) / 2.0
				
			var s_pos: Vector2 = tex_pos
			if child.auto_center:
				s_pos = (child.size - child.shadow_texture.get_size()) / 2.0
			
			# Draw FULLY opaque white. If drawn full black, intersections remain max black. 
			# The CanvasGroup applies the 50% opacity uniformly to the resulting combined shapes later!
			_shadow_drawer.draw_texture(child.shadow_texture, s_pos + s_off, Color(1, 1, 1, 1))
			
		_draw_shadows_recursive(child)


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
			_sync_passenger_segments_to_active_drag()
		elif _active_drag_piece:
			_active_drag_piece.update_drag(event.global_position)


func _handle_left_press(global_pos: Vector2) -> void:
	if _active_drag_segment or _active_drag_piece:
		return

	if _hit_button(craft_button, global_pos):
		if craft_button.disabled:
			UI_SOUND.play_inaccessible_button(self)
		else:
			_on_craft_pressed()
		return
	if _hit_button(collect_button, global_pos):
		if collect_button.disabled:
			UI_SOUND.play_inaccessible_button(self)
		else:
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
		var master: WorkshopSegment = _active_drag_segment
		var passengers: Array = _passenger_segments.duplicate()

		_active_drag_segment = null
		_passenger_segments = []
		_passenger_offsets.clear()

		var group: Array = [master]
		for p in passengers:
			if p is WorkshopSegment and is_instance_valid(p):
				group.append(p)

		var drops: Array = []
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


func _slot_for_segment(segment: WorkshopSegment) -> WorkshopAssemblySlot:
	for slot_id in _assembly_slots:
		var slot: WorkshopAssemblySlot = _assembly_slots[slot_id]
		if slot.accepts_segment_id == segment.segment_id:
			return slot
	return null


func _slot_tree_index(segment: WorkshopSegment) -> int:
	var slot: WorkshopAssemblySlot = _slot_for_segment(segment)
	if slot == null:
		return -1
	if slot.get_parent() == null:
		return -1
	return slot.get_index()


# --- pick-up ---

func _pick_up_segment(segment: WorkshopSegment, global_pos: Vector2) -> void:
	var passengers: Array = []
	for partner in segment.pair_partners:
		if partner is WorkshopSegment and is_instance_valid(partner) and not partner.locked:
			if partner != segment and not passengers.has(partner):
				passengers.append(partner)

	var all_members: Array = [segment]
	for p in passengers:
		all_members.append(p)
	all_members.sort_custom(func(a, b): return _slot_tree_index(a) < _slot_tree_index(b))

	for seg in all_members:
		if seg.get_parent() != self:
			var gp: Vector2 = seg.global_position
			seg.get_parent().remove_child(seg)
			add_child(seg)
			seg.global_position = gp
			
	for seg in all_members:
		move_child(seg, get_child_count() - 1)

	_active_drag_segment = segment
	segment.start_drag(global_pos)

	_passenger_segments = passengers
	_passenger_offsets.clear()
	for p in passengers:
		_passenger_offsets[p] = p.position - segment.position


func _sync_passenger_segments_to_active_drag() -> void:
	if _active_drag_segment == null:
		return
	var master_pos: Vector2 = _active_drag_segment.position
	for passenger in _passenger_segments:
		if passenger is WorkshopSegment and is_instance_valid(passenger):
			passenger.position = master_pos + _passenger_offsets.get(passenger, Vector2.ZERO)


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
	var part_id := _matching_recipe_part_id()
	craft_button.disabled = part_id == ""
	craft_button.text = "CRAFT" if part_id == "" else "CRAFT %s" % _part_display_name(part_id).to_upper()


func _bin_has_recipe() -> bool:
	return _matching_recipe_part_id() != ""


func _matching_recipe_part_id() -> String:
	var counts: Dictionary = craft_bin.count_items()
	for part_id in CRAFTABLE_PARTS:
		var part_data: Dictionary = CRAFTABLE_PARTS[part_id]
		var recipe: Dictionary = part_data.get("recipe", {})
		if _counts_exactly_match_recipe(counts, recipe):
			return String(part_id)
	return ""


func _counts_exactly_match_recipe(counts: Dictionary, recipe: Dictionary) -> bool:
	for id_key in counts:
		if int(counts[id_key]) > 0 and not recipe.has(String(id_key)):
			return false
	for id_key in recipe:
		if int(counts.get(String(id_key), 0)) != int(recipe[id_key]):
			return false
	return true


func _part_display_name(part_id: String) -> String:
	var part_data: Dictionary = CRAFTABLE_PARTS.get(part_id, {})
	return String(part_data.get("display_name", part_id))


func _on_craft_pressed() -> void:
	if _crafted:
		return
	var part_id := _matching_recipe_part_id()
	if part_id == "":
		return
	_crafted = true
	_crafted_part_id = part_id

	var part_data: Dictionary = CRAFTABLE_PARTS.get(_crafted_part_id, {})
	var recipe: Dictionary = part_data.get("recipe", {})
	for id_key in recipe:
		var id: String = String(id_key)
		var need: int = int(recipe[id_key])
		GameState.ingredients[id] = max(0, int(GameState.ingredients.get(id, 0)) - need)

	craft_bin.clear_pieces()
	craft_bin.output_mode = true
	_spawn_segments_stacked_at_bin_center()

	_refresh_tray_counts()
	craft_button.disabled = true
	craft_button.text = "CRAFTED %s" % _part_display_name(_crafted_part_id).to_upper()
	collect_button.visible = true
	collect_button.text = "COLLECT %s" % _part_display_name(_crafted_part_id).to_upper()


func _spawn_segments_stacked_at_bin_center() -> void:
	var bin_center_global: Vector2 = craft_bin.get_global_transform() \
		* craft_bin.local_center()
	var bin_center_local: Vector2 = get_global_transform().affine_inverse() \
		* bin_center_global

	var segments_by_id: Dictionary = {} 

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

	for slot_id in _assembly_slots:
		var slot: WorkshopAssemblySlot = _assembly_slots[slot_id]
		if String(slot.paired_with) == "":
			continue
		var this_seg: WorkshopSegment = segments_by_id.get(slot.accepts_segment_id)
		var other_seg: WorkshopSegment = segments_by_id.get(slot.paired_with)
		if this_seg and other_seg and not this_seg.pair_partners.has(other_seg):
			this_seg.pair_partners.append(other_seg)

	var positioned: Dictionary = {} 

	for seg_id in segments_by_id:
		var segment: WorkshopSegment = segments_by_id[seg_id]
		if positioned.get(segment, false):
			continue

		var group: Array = [segment]
		for partner in segment.pair_partners:
			if partner is WorkshopSegment and is_instance_valid(partner):
				if not group.has(partner):
					group.append(partner)

		var primary: WorkshopSegment = group[0]
		var primary_idx: int = _slot_tree_index(primary)
		for member in group:
			var idx: int = _slot_tree_index(member)
			if idx >= 0 and (primary_idx < 0 or idx < primary_idx):
				primary = member
				primary_idx = idx

		var primary_hb: Rect2 = primary.grab_hitbox_rect
		if primary_hb.size.x > 0.0 and primary_hb.size.y > 0.0:
			var hb_center: Vector2 = primary_hb.position + primary_hb.size * 0.5
			primary.position = bin_center_local - hb_center
		else:
			primary.position = bin_center_local - primary.size * 0.5
			push_warning("Workshop: segment '%s' has no usable grab hitbox — fell back to canvas-center positioning." % primary.segment_id)
		positioned[primary] = true

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
	if _crafted_part_id == "":
		return
	collected.emit(_crafted_part_id)


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
