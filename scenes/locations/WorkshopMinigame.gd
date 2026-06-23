extends Control
class_name WorkshopMinigame

signal collected(part_id: String)

const CRAFTABLE_PARTS: Dictionary = {
	"head": {
		"display_name": "Head",
		"recipe": {"head_segments": 1},
	},
	"leg": {
		"display_name": "Leg",
		"recipe": {"scrap_metal": 1},
	},
}

const INGREDIENT_PATHS: Dictionary = {
	"scrap_metal":   "res://assets/textures/icons/scrap_metal.png",
	"nuts_bolts":    "res://assets/textures/icons/nuts_bolts.png",
	"nanobots":      "res://assets/textures/icons/nanobots.png",
	"electronics":   "res://assets/textures/icons/electronics.png",
	"synth_skin":    "res://assets/textures/icons/synth_skin.png",
	"head_segments": "res://assets/textures/icons/placeholder_item.png",
	"oil":           "res://assets/textures/icons/oil.png",
}
const HEAD_TEXTURE_DIR: String = "res://assets/textures/characters/robot/workshop/workshop robot head"
const HEAD_ASSEMBLY_SIZE: Vector2 = Vector2(200, 200)
const HEAD_SEGMENT_IDS: Array[StringName] = [
	&"neck",
	&"metal_head",
	&"left_ear",
	&"right_ear",
	&"left_side_panel",
	&"right_side_panel",
	&"forehead",
	&"left_cheek",
	&"right_cheek",
	&"mouth",
	&"nose",
	&"left_eye",
	&"right_eye",
	&"left_eyelid",
	&"right_eyelid",
	&"hair",
]
const HEAD_EYE_SEGMENT_IDS: Array[StringName] = [&"left_eye", &"right_eye"]
const HEAD_EYELID_SEGMENT_IDS: Array[StringName] = [&"left_eyelid", &"right_eyelid"]
const HEAD_EYE_HITBOX_GROW: Vector2 = Vector2(18.0, 14.0)
const INGREDIENT_SHADOW_PATHS: Dictionary = {
	"scrap_metal":   "res://assets/textures/icons/scrap_metal_shadow.png",
	"nuts_bolts":    "res://assets/textures/icons/nuts_bolts_shadow.png",
	"electronics":   "res://assets/textures/icons/electronics_shadow.png",
	"synth_skin":    "res://assets/textures/icons/synth_skin_shadow.png",
	"head_segments": "res://assets/textures/icons/placeholder_item.png",
	"oil":           "res://assets/textures/icons/oil_shadow.png",
}
const UI_SOUND := preload("res://scenes/ui/UiSound.gd")
const WORKSHOP_PIECE_SCRIPT_PATH: String = "res://scenes/locations/WorkshopPiece.gd"
const PLACEMENT_HINT_SHADER_CODE: String = """
shader_type canvas_item;

uniform vec4 border_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha_threshold = 0.08;
uniform float border_width = 1.4;

float alpha_at(vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(TEXTURE, uv).a;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * border_width;
	float center = alpha_at(UV);
	float has_clear_neighbor = 0.0;
	has_clear_neighbor = max(has_clear_neighbor, 1.0 - step(alpha_threshold, alpha_at(UV + vec2(px.x, 0.0))));
	has_clear_neighbor = max(has_clear_neighbor, 1.0 - step(alpha_threshold, alpha_at(UV + vec2(-px.x, 0.0))));
	has_clear_neighbor = max(has_clear_neighbor, 1.0 - step(alpha_threshold, alpha_at(UV + vec2(0.0, px.y))));
	has_clear_neighbor = max(has_clear_neighbor, 1.0 - step(alpha_threshold, alpha_at(UV + vec2(0.0, -px.y))));
	has_clear_neighbor = max(has_clear_neighbor, 1.0 - step(alpha_threshold, alpha_at(UV + vec2(px.x, px.y))));
	has_clear_neighbor = max(has_clear_neighbor, 1.0 - step(alpha_threshold, alpha_at(UV + vec2(-px.x, px.y))));
	has_clear_neighbor = max(has_clear_neighbor, 1.0 - step(alpha_threshold, alpha_at(UV + vec2(px.x, -px.y))));
	has_clear_neighbor = max(has_clear_neighbor, 1.0 - step(alpha_threshold, alpha_at(UV + vec2(-px.x, -px.y))));

	float edge = step(alpha_threshold, center) * step(0.5, has_clear_neighbor);
	COLOR = vec4(border_color.rgb, border_color.a * edge);
}
"""

@onready var ingredients_tray: Control = %IngredientsTray
@onready var craft_bin: WorkshopBin = %CraftBin
@onready var craft_button: Button = %CraftButton
@onready var assembly: Control = %AssemblyArea
@onready var collect_button: Button = %CollectButton

var _segments: Dictionary = {}
var _assembly_slots: Dictionary = {}
var _leg_assembly_slot_ids: Array[StringName] = []
var _active_assembly_slot_ids: Array[StringName] = []
var _head_slot_placement_offsets: Dictionary = {}
var _head_assembly: Control = null

var _active_drag_segment: WorkshopSegment = null
var _passenger_segments: Array = []
var _passenger_offsets: Dictionary = {} 

var _active_drag_piece: WorkshopPiece = null

var _crafted: bool = false
var _crafted_part_id: String = ""

var _shadow_group: CanvasGroup = null
var _shadow_drawer: Control = null
var _spawn_rng := RandomNumberGenerator.new()
var _assembly_templates_collected: bool = false
var _placement_hint_layer: Control = null
var _placement_hint_material: ShaderMaterial = null
var _placement_hint_elapsed: float = 0.0


func _enter_tree() -> void:
	var assembly_node := get_node_or_null("AssemblyArea") as Control
	if assembly_node != null:
		_collect_assembly_slots(assembly_node)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spawn_rng.randomize()

	_setup_head_assembly()
	_configure_assembly_for_part("")

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

	_setup_placement_hint_layer()
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
	_update_placement_hint_flash(_delta)


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


func _setup_placement_hint_layer() -> void:
	_placement_hint_layer = Control.new()
	_placement_hint_layer.name = "PlacementHintLayer"
	_placement_hint_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placement_hint_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_placement_hint_layer.visible = false
	add_child(_placement_hint_layer)


func _get_placement_hint_material() -> ShaderMaterial:
	if _placement_hint_material != null:
		return _placement_hint_material
	var shader := Shader.new()
	shader.code = PLACEMENT_HINT_SHADER_CODE
	_placement_hint_material = ShaderMaterial.new()
	_placement_hint_material.shader = shader
	return _placement_hint_material


func _update_placement_hint_flash(delta: float) -> void:
	if _placement_hint_layer == null or not _placement_hint_layer.visible:
		return
	_placement_hint_elapsed += delta
	var wave := (sin(_placement_hint_elapsed * TAU * 1.45) + 1.0) * 0.5
	var color := _placement_hint_layer.modulate
	color.a = lerpf(0.1, 0.95, wave)
	_placement_hint_layer.modulate = color


func _clear_placement_hints() -> void:
	if _placement_hint_layer == null:
		return
	for child in _placement_hint_layer.get_children():
		child.queue_free()
	_placement_hint_layer.visible = false
	_placement_hint_elapsed = 0.0


func _show_piece_placement_hint(piece: WorkshopPiece, target_global_position: Vector2) -> void:
	_clear_placement_hints()
	_add_piece_hint(piece, target_global_position)
	_show_placement_hint_layer()


func _show_segment_placement_hints(segments: Array) -> void:
	_clear_placement_hints()
	for segment in segments:
		if not (segment is WorkshopSegment):
			continue
		if not is_instance_valid(segment) or segment.locked:
			continue
		if not _head_prerequisites_met(segment.segment_id):
			continue
		for slot in _slots_for_segment(segment):
			if slot == null or slot.filled:
				continue
			var slot_xform: Transform2D = slot.get_global_transform()
			var target_placement_offset: Vector2 = _placement_offset_for_slot(segment, slot)
			for child in segment.get_children():
				if child is WorkshopPiece:
					var piece := child as WorkshopPiece
					var texture_global_position: Vector2 = slot_xform * (
						target_placement_offset
						+ piece.position
						+ _piece_texture_draw_position(piece)
					)
					_add_piece_hint(piece, texture_global_position)
	_show_placement_hint_layer()


func _show_placement_hint_layer() -> void:
	if _placement_hint_layer == null:
		return
	_placement_hint_layer.visible = _placement_hint_layer.get_child_count() > 0
	_placement_hint_layer.modulate = Color(1.0, 1.0, 1.0, 0.95)
	_placement_hint_elapsed = 0.0


func _add_piece_hint(piece: WorkshopPiece, target_texture_global_position: Vector2) -> void:
	if _placement_hint_layer == null or piece == null or piece.texture == null:
		return
	var ghost := TextureRect.new()
	ghost.texture = piece.texture
	ghost.size = piece.texture.get_size()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.material = _get_placement_hint_material()
	_placement_hint_layer.add_child(ghost)
	ghost.global_position = target_texture_global_position


func _piece_texture_draw_position(piece: WorkshopPiece) -> Vector2:
	var tex_pos: Vector2 = piece.visual_offset if typeof(piece.visual_offset) == TYPE_VECTOR2 else Vector2.ZERO
	if piece.auto_center and piece.texture != null:
		tex_pos = (piece.size - piece.texture.get_size()) / 2.0
	return tex_pos


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
		_clear_placement_hints()
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
			for slot_id in _active_assembly_slot_ids:
				var slot: WorkshopAssemblySlot = _assembly_slots[slot_id]
				if _is_valid_segment_drop(seg, slot, global_pos):
					target = slot
					break
			if target == null:
				all_valid = false
			drops.append([seg, target])

		if all_valid:
			for entry in drops:
				var placing_seg: WorkshopSegment = entry[0]
				var placing_slot: WorkshopAssemblySlot = entry[1]
				_accept_segment_into_slot(placing_seg, placing_slot)
			_refresh_collect_button()
		return

	if _active_drag_piece != null:
		_clear_placement_hints()
		var piece: WorkshopPiece = _active_drag_piece
		_active_drag_piece = null
		piece.end_drag()

		if craft_bin.accepts_point(global_pos):
			_drop_into_bin(piece, global_pos)
			return

		_return_piece_home_or_discard(piece)
		craft_bin.contents_changed.emit()
		_refresh_tray_counts()


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
		if _node_is_workshop_piece(child):
			out.append(child)
		_collect_pieces(child, out)


func _piece_is_inside_segment(piece: WorkshopPiece) -> bool:
	var n: Node = piece.get_parent()
	while n != null:
		if n is WorkshopSegment:
			return true
		n = n.get_parent()
	return false


func _node_is_workshop_piece(node: Node) -> bool:
	if node is WorkshopPiece:
		return true
	var script: Script = node.get_script()
	return script != null and script.resource_path == WORKSHOP_PIECE_SCRIPT_PATH


func _slot_for_segment(segment: WorkshopSegment) -> WorkshopAssemblySlot:
	var exact_slot: WorkshopAssemblySlot = _assembly_slots.get(segment.segment_id)
	if exact_slot != null:
		return exact_slot
	for slot_id in _assembly_slots:
		var slot: WorkshopAssemblySlot = _assembly_slots[slot_id]
		if _slot_accepts_segment(slot, segment):
			return slot
	return null


func _slots_for_segment(segment: WorkshopSegment) -> Array[WorkshopAssemblySlot]:
	var slots: Array[WorkshopAssemblySlot] = []
	for slot_id in _active_assembly_slot_ids:
		var slot: WorkshopAssemblySlot = _assembly_slots.get(slot_id)
		if slot != null and _slot_accepts_segment(slot, segment):
			slots.append(slot)
	return slots


func _slot_accepts_segment(slot: WorkshopAssemblySlot, segment: WorkshopSegment) -> bool:
	if slot == null or segment == null:
		return false
	return _segment_id_matches_slot(segment.segment_id, slot.accepts_segment_id)


func _segment_id_matches_slot(segment_id: StringName, slot_id: StringName) -> bool:
	if segment_id == slot_id:
		return true
	if _crafted_part_id == "head" and HEAD_EYE_SEGMENT_IDS.has(segment_id) and HEAD_EYE_SEGMENT_IDS.has(slot_id):
		return true
	return false


func _is_valid_segment_drop(segment: WorkshopSegment, slot: WorkshopAssemblySlot, release_global_pos: Vector2) -> bool:
	if slot == null or slot.filled:
		return false
	if not _slot_accepts_segment(slot, segment):
		return false
	var release_hits_slot: bool = slot.get_global_hitbox().has_point(release_global_pos)
	if not release_hits_slot:
		if _crafted_part_id == "leg":
			return false
		if not _segment_overlaps_slot(segment, slot):
			return false
	if not _head_prerequisites_met(segment.segment_id):
		return false
	return true


func _segment_overlaps_slot(segment: WorkshopSegment, slot: WorkshopAssemblySlot) -> bool:
	if slot.filled:
		return false
	if not _slot_accepts_segment(slot, segment):
		return false
	return segment.get_global_hitbox().intersects(slot.get_global_hitbox())


func _head_prerequisites_met(segment_id: StringName) -> bool:
	if _crafted_part_id != "head":
		return true
	if segment_id == &"metal_head":
		return true
	var metal_slot: WorkshopAssemblySlot = _assembly_slots.get(&"metal_head")
	if metal_slot == null or not metal_slot.filled:
		return false
	if HEAD_EYELID_SEGMENT_IDS.has(segment_id):
		return _head_slot_filled(&"left_eye") and _head_slot_filled(&"right_eye")
	if segment_id == &"hair":
		return _head_slot_filled(&"left_ear") and _head_slot_filled(&"right_ear")
	return true


func _head_slot_filled(segment_id: StringName) -> bool:
	var slot: WorkshopAssemblySlot = _assembly_slots.get(segment_id)
	return slot != null and slot.filled


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
	var all_members: Array = [segment]
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

	_show_segment_placement_hints(all_members)
	if _placement_hint_layer != null and _placement_hint_layer.visible:
		move_child(_placement_hint_layer, get_child_count() - 1)
		for seg in all_members:
			if seg is WorkshopSegment and seg.get_parent() == self:
				move_child(seg, get_child_count() - 1)


func _sync_passenger_segments_to_active_drag() -> void:
	if _active_drag_segment == null:
		return
	var master_pos: Vector2 = _active_drag_segment.position
	for passenger in _passenger_segments:
		if passenger is WorkshopSegment and is_instance_valid(passenger):
			passenger.position = master_pos + _passenger_offsets.get(passenger, Vector2.ZERO)


func _accept_segment_into_slot(segment: WorkshopSegment, slot: WorkshopAssemblySlot) -> void:
	if segment == null or slot == null:
		return
	slot.accept_segment(segment)
	segment.position = _placement_offset_for_slot(segment, slot)


func _placement_offset_for_slot(segment: WorkshopSegment, slot: WorkshopAssemblySlot) -> Vector2:
	if segment == null or slot == null:
		return Vector2.ZERO
	if _crafted_part_id == "head" and HEAD_EYE_SEGMENT_IDS.has(segment.segment_id) and HEAD_EYE_SEGMENT_IDS.has(slot.accepts_segment_id):
		return _head_slot_placement_offsets.get(slot.accepts_segment_id, segment.placement_offset)
	return segment.placement_offset


func _pick_up_piece(piece: WorkshopPiece, global_pos: Vector2) -> void:
	var was_from_tray: bool = piece.get_parent() != null \
		and piece.get_parent().get_parent() == ingredients_tray
	var was_from_bin: bool = piece.get_parent() == craft_bin
	_active_drag_piece = piece
	if piece.get_parent() != self:
		var gp: Vector2 = piece.global_position
		piece.get_parent().remove_child(piece)
		add_child(piece)
		piece.global_position = gp
	move_child(piece, get_child_count() - 1)
	piece.start_drag(global_pos)

	if was_from_bin:
		craft_bin.contents_changed.emit()
		_refresh_tray_counts()
	elif was_from_tray and piece.home_parent and piece.home_parent.get_parent() == ingredients_tray:
		var id: String = String(piece.home_parent.name).trim_prefix("Tray_")
		call_deferred("_maybe_replace_tray_tile", id, piece.home_parent)

	var target_texture_global_position: Vector2 = craft_bin.get_global_transform() * (
		craft_bin.local_center()
		- piece.size * 0.5
		+ _piece_texture_draw_position(piece)
	)
	_show_piece_placement_hint(piece, target_texture_global_position)
	if _placement_hint_layer != null and _placement_hint_layer.visible:
		move_child(_placement_hint_layer, get_child_count() - 1)
		move_child(piece, get_child_count() - 1)


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


# --- assembly setup ---

func _setup_head_assembly() -> void:
	if _head_assembly != null:
		return
	_head_assembly = Control.new()
	_head_assembly.name = "AssemblyHead"
	_head_assembly.size = HEAD_ASSEMBLY_SIZE
	_head_assembly.position = (assembly.size - HEAD_ASSEMBLY_SIZE) * 0.5
	_head_assembly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head_assembly.visible = false

	for segment_id in HEAD_SEGMENT_IDS:
		var tex: Texture2D = _load_head_layer(segment_id)
		if tex == null:
			push_warning("Workshop: missing head layer '%s' in %s." % [segment_id, HEAD_TEXTURE_DIR])
			continue

		var used_rect: Rect2 = _used_rect_for_texture(tex)
		_head_slot_placement_offsets[segment_id] = used_rect.position

		var slot := WorkshopAssemblySlot.new()
		slot.name = "%sSlot" % String(segment_id).capitalize().replace(" ", "")
		slot.accepts_segment_id = segment_id
		slot.position = Vector2.ZERO
		slot.size = HEAD_ASSEMBLY_SIZE
		slot.hitbox_rect = _head_slot_hitbox(segment_id, used_rect)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var placed_callable := Callable(self, "_on_slot_placed")
		if not slot.placed.is_connected(placed_callable):
			slot.placed.connect(placed_callable)
		_head_assembly.add_child(slot)
		_assembly_slots[segment_id] = slot
		_segments[segment_id] = {
			"pieces": [
				{
					"id": segment_id,
					"texture": tex,
					"outline": _load_head_outline(segment_id),
					"shadow": null,
				}
			]
		}

	assembly.add_child.call_deferred(_head_assembly)


func _load_head_layer(segment_id: StringName) -> Texture2D:
	return _load_texture("%s/%s.png" % [HEAD_TEXTURE_DIR, segment_id])


func _load_head_outline(segment_id: StringName) -> Texture2D:
	return _load_texture("%s/%s_outline.png" % [HEAD_TEXTURE_DIR, segment_id])


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _used_rect_for_texture(tex: Texture2D) -> Rect2:
	if tex == null:
		return Rect2(Vector2.ZERO, HEAD_ASSEMBLY_SIZE)
	var img: Image = tex.get_image()
	if img == null:
		return Rect2(Vector2.ZERO, tex.get_size())
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return Rect2(Vector2.ZERO, tex.get_size())
	return Rect2(Vector2(used.position), Vector2(used.size))


func _head_slot_hitbox(segment_id: StringName, used_rect: Rect2) -> Rect2:
	if HEAD_EYE_SEGMENT_IDS.has(segment_id):
		return _clamp_rect_to_bounds(
			_grow_rect(used_rect, HEAD_EYE_HITBOX_GROW),
			Rect2(Vector2.ZERO, HEAD_ASSEMBLY_SIZE)
		)
	return used_rect


func _grow_rect(rect: Rect2, grow: Vector2) -> Rect2:
	return Rect2(rect.position - grow, rect.size + grow * 2.0)


func _clamp_rect_to_bounds(rect: Rect2, bounds: Rect2) -> Rect2:
	var pos := Vector2(
		maxf(rect.position.x, bounds.position.x),
		maxf(rect.position.y, bounds.position.y)
	)
	var end := Vector2(
		minf(rect.end.x, bounds.end.x),
		minf(rect.end.y, bounds.end.y)
	)
	return Rect2(pos, Vector2(maxf(end.x - pos.x, 0.0), maxf(end.y - pos.y, 0.0)))


func _configure_assembly_for_part(part_id: String) -> void:
	var leg_node := assembly.get_node_or_null("AssemblyLeg") as CanvasItem
	if leg_node != null:
		leg_node.visible = part_id == "" or part_id == "leg"
	if _head_assembly != null:
		_head_assembly.visible = part_id == "head"

	_active_assembly_slot_ids.clear()
	if part_id == "head":
		for id in HEAD_SEGMENT_IDS:
			if _assembly_slots.has(id):
				_active_assembly_slot_ids.append(id)
	elif part_id == "leg":
		_active_assembly_slot_ids.assign(_leg_assembly_slot_ids)


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
		if _counts_contain_recipe(counts, recipe):
			return String(part_id)
	return ""


func _counts_contain_recipe(counts: Dictionary, recipe: Dictionary) -> bool:
	for id_key in recipe:
		if int(counts.get(String(id_key), 0)) < int(recipe[id_key]):
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
	_consume_recipe_pieces(recipe)
	craft_bin.output_mode = true
	_configure_assembly_for_part(_crafted_part_id)

	_spawn_segments_stacked_at_bin_center()

	_refresh_tray_counts()
	craft_button.disabled = true
	craft_button.text = "CRAFTED %s" % _part_display_name(_crafted_part_id).to_upper()
	collect_button.visible = true
	collect_button.text = "COLLECT %s" % _part_display_name(_crafted_part_id).to_upper()


func _consume_recipe_pieces(recipe: Dictionary) -> void:
	var consumed_pieces: Array[WorkshopPiece] = []
	for id_key in recipe:
		var id: String = String(id_key)
		var need: int = int(recipe[id_key])
		GameState.ingredients[id] = max(0, int(GameState.ingredients.get(id, 0)) - need)

		var consumed: int = 0
		for piece in craft_bin.pieces_with_id(StringName(id)):
			if consumed >= need:
				break
			var parent: Node = piece.get_parent()
			if parent != null:
				parent.remove_child(piece)
			piece.queue_free()
			consumed_pieces.append(piece)
			consumed += 1

	for piece in craft_bin.all_pieces():
		if consumed_pieces.has(piece):
			continue
		if not is_instance_valid(piece):
			continue
		_return_piece_home_or_discard(piece)
	craft_bin.contents_changed.emit()


func _return_piece_home_or_discard(piece: WorkshopPiece) -> void:
	if piece == null or not is_instance_valid(piece):
		return
	if piece.home_parent == null:
		piece.queue_free()
		return
	for child in piece.home_parent.get_children():
		if child is WorkshopPiece and child != piece:
			piece.queue_free()
			return
	piece.snap_home()


func _spawn_segments_stacked_at_bin_center() -> void:
	var segments_by_id: Dictionary = {} 
	var output_parent: Control = craft_bin

	var spawn_order: Array[StringName] = _spawn_segment_order()
	for seg_id in spawn_order:
		if not _active_assembly_slot_ids.has(seg_id):
			continue
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

			var tex_rect: Rect2 = _piece_visible_rect(piece)
			if tex_rect.size.x > 0.0 and tex_rect.size.y > 0.0:
				if not found_any:
					bounds = tex_rect
					found_any = true
				else:
					bounds = bounds.merge(tex_rect)

		if not found_any:
			push_warning("Workshop: segment '%s' has no pieces with textures — skipped spawn." % seg_id)
			segment.queue_free()
			continue

		for child in segment.get_children():
			if child is WorkshopPiece:
				child.position -= bounds.position
		segment.size = bounds.size
		segment.placement_offset = bounds.position
		output_parent.add_child(segment)
		segment.auto_fit_grab_hitbox = true
		if _crafted_part_id == "head" and HEAD_EYE_SEGMENT_IDS.has(seg_id):
			segment.grab_hitbox_rect = _grow_rect(segment.grab_hitbox_rect, HEAD_EYE_HITBOX_GROW)

		segments_by_id[seg_id] = segment

	for slot_id in _active_assembly_slot_ids:
		var slot: WorkshopAssemblySlot = _assembly_slots[slot_id]
		if String(slot.paired_with) == "":
			continue
		var this_seg: WorkshopSegment = segments_by_id.get(slot.accepts_segment_id)
		var other_seg: WorkshopSegment = segments_by_id.get(slot.paired_with)
		if this_seg and other_seg and not this_seg.pair_partners.has(other_seg):
			this_seg.pair_partners.append(other_seg)

	var positioned: Dictionary = {}
	var group_index: int = 0

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

		var spawn_center: Vector2 = _segment_spawn_center(group_index, segments_by_id.size())
		group_index += 1

		var primary_hb: Rect2 = primary.grab_hitbox_rect
		if primary_hb.size.x > 0.0 and primary_hb.size.y > 0.0:
			var hb_center: Vector2 = primary_hb.position + primary_hb.size * 0.5
			primary.position = _clamped_segment_spawn_position(primary, spawn_center - hb_center)
		else:
			primary.position = _clamped_segment_spawn_position(primary, spawn_center - primary.size * 0.5)
			push_warning("Workshop: segment '%s' has no usable grab hitbox — fell back to canvas-center positioning." % primary.segment_id)
		positioned[primary] = true

		var primary_slot: WorkshopAssemblySlot = _slot_for_segment(primary)
		if primary_slot == null:
			continue
		var primary_slot_local: Vector2 = output_parent.get_global_transform().affine_inverse() \
			* primary_slot.get_global_transform().origin

		for member in group:
			if member == primary:
				continue
			var member_slot: WorkshopAssemblySlot = _slot_for_segment(member)
			if member_slot == null:
				continue
			var member_slot_local: Vector2 = output_parent.get_global_transform().affine_inverse() \
				* member_slot.get_global_transform().origin
			member.position = primary.position \
				+ member_slot_local + member.placement_offset \
				- primary_slot_local - primary.placement_offset
			positioned[member] = true

	craft_bin.contents_changed.emit()


func _segment_spawn_center(index: int, total: int) -> Vector2:
	return craft_bin.local_center() + _segment_spawn_offset(index, total)


func _clamped_segment_spawn_position(segment: WorkshopSegment, desired_position: Vector2) -> Vector2:
	var bounds := Rect2(Vector2(6, 6), craft_bin.size - Vector2(12, 12))
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return desired_position
	var hitbox: Rect2 = segment.grab_hitbox_rect
	if hitbox.size.x <= 0.0 or hitbox.size.y <= 0.0:
		hitbox = Rect2(Vector2.ZERO, segment.size)
	return Vector2(
		clampf(desired_position.x, bounds.position.x - hitbox.position.x, bounds.end.x - hitbox.end.x),
		clampf(desired_position.y, bounds.position.y - hitbox.position.y, bounds.end.y - hitbox.end.y),
	)


func _piece_visible_rect(piece: WorkshopPiece) -> Rect2:
	if piece == null or piece.texture == null:
		return Rect2()
	var img: Image = piece.texture.get_image()
	if img == null:
		return Rect2(Vector2.ZERO, piece.texture.get_size())
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return Rect2()
	var tex_pos: Vector2 = piece.visual_offset if typeof(piece.visual_offset) == TYPE_VECTOR2 else Vector2.ZERO
	if piece.auto_center:
		tex_pos = (piece.size - piece.texture.get_size()) / 2.0
	return Rect2(tex_pos + Vector2(used.position), Vector2(used.size))


func _spawn_segment_order() -> Array[StringName]:
	var order: Array[StringName] = _active_assembly_slot_ids.duplicate()
	order.shuffle()
	if _crafted_part_id == "head":
		order.erase(&"metal_head")
		order.append(&"metal_head")
	return order


func _segment_spawn_offset(index: int, total: int) -> Vector2:
	if total <= 1:
		return Vector2.ZERO
	var columns: int = mini(4, int(ceil(sqrt(float(total)))))
	var rows: int = int(ceil(float(total) / float(columns)))
	var col: int = index % columns
	var row: int = index / columns
	var spacing := Vector2(68, 54)
	var base := Vector2(
		(float(col) - float(columns - 1) * 0.5) * spacing.x,
		(float(row) - float(rows - 1) * 0.5) * spacing.y,
	)
	var jitter_radius: float = 38.0 if _crafted_part_id == "head" else 24.0
	return base + Vector2(
		_spawn_rng.randf_range(-jitter_radius, jitter_radius),
		_spawn_rng.randf_range(-jitter_radius, jitter_radius),
	)


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
	piece.outline_texture = piece_def.get("outline")

	piece.piece_offset = Vector2.ZERO
	piece.visual_offset = Vector2.ZERO
	piece.shadow_offset = Vector2.ZERO
	piece.auto_center = false

	piece.size = tex.get_size()

	return piece


# --- collect ---

func _refresh_collect_button() -> void:
	var all_filled: bool = true
	if _active_assembly_slot_ids.is_empty():
		all_filled = false
	for slot_id in _active_assembly_slot_ids:
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

func _collect_assembly_slots(root: Node = null) -> void:
	if _assembly_templates_collected:
		return
	_assembly_slots.clear()
	_segments.clear()
	_leg_assembly_slot_ids.clear()
	var collect_root: Node = root
	if collect_root == null:
		collect_root = assembly
	_collect_slots_recursive(collect_root)
	_assembly_templates_collected = true


func _collect_slots_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is WorkshopAssemblySlot:
			var slot: WorkshopAssemblySlot = child
			var slot_id: StringName = slot.accepts_segment_id
			_assembly_slots[slot_id] = slot
			if not _leg_assembly_slot_ids.has(slot_id):
				_leg_assembly_slot_ids.append(slot_id)
			var placed_callable := Callable(self, "_on_slot_placed")
			if not slot.placed.is_connected(placed_callable):
				slot.placed.connect(placed_callable)

			var pieces: Array = []
			for i in range(slot.get_child_count() - 1, -1, -1):
				var p: Node = slot.get_child(i)
				if _node_is_workshop_piece(p):
					var tex: Texture2D = p.get("texture")
					if tex == null:
						push_warning("Workshop: piece '%s' under slot '%s' has no texture set in the .tscn." % [p.name, slot.name])
					var def: Dictionary = {
						"id": p.get("item_id"),
						"texture": tex,
						"shadow": p.get("shadow_texture"),
						"outline": p.get("outline_texture"),
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
