extends Control
class_name WorkArmMinigame
## Second Work-scene minigame: assemble the UPPER ARM of a robot.
##
## Unlike the Workshop (craft ingredients -> assemble a whole limb -> COLLECT),
## this is a pure assembly puzzle that lives on the factory floor. The upper-arm
## segments (shoulder + upper arm + elbow — no forearm, no hand) sit pre-made in
## two tall side containers. The player drags each one onto the assembly area on
## the table. When the last piece snaps home the puzzle is finished and the Work
## location routes to the same completion screen the shape-sorting shift uses.
##
## There is no craft bin, no ingredients tray, no drop panel, and no COLLECT
## button. Reuses WorkshopSegment / WorkshopAssemblySlot / WorkshopPiece and the
## Workshop's segment-composition math so the placed pieces line up into a
## coherent arm.

## Emitted once every assembly slot is filled.
signal completed()

const ARM_TEXTURE_DIR: String = "res://assets/textures/characters/robot/workshop/workshop robot arm"
const ARM_ASSEMBLY_SIZE: Vector2 = Vector2(350, 350)

## The upper-arm subset (shoulder + upper arm plates/muscles + elbow). The
## forearm, wrist and hand segments are intentionally excluded — those belong to
## other parts of the arm build.
const UPPER_ARM_SEGMENT_IDS: Array[StringName] = [
	&"shoulder_joint",
	&"shoulder_pad",
	&"tricep",
	&"bicep",
	&"upper_arm_plate",
	&"upper_arm_plate_lower",
	&"elbow_cap",
	&"elbow_joint",
	&"elbow_inner_gears",
]
## Segments whose "_outline" art is part of the final look and must keep drawing
## after placement (rather than being a pick-up-only drag hint).
const PERSISTENT_OUTLINE_IDS: Array[StringName] = [&"elbow_inner_gears"]

# --- Side-container geometry, mirrored from Main's large-scene HUD panels so the
# two containers read as the same gilded frames stacked below the DAY / SUS
# panels: same width, same gap from the viewport edge. ---
const HUD_PANEL_WIDTH: float = 156.0
const HUD_MARGIN: Vector2 = Vector2(64.0, 24.0)
const HUD_LEFT_PANEL_HEIGHT: float = 178.0
## Gap between the bottom of the HUD panel and the top of our container.
const CONTAINER_TOP_GAP: float = 16.0
## Space left below the container for the bottom-corner action buttons.
const CONTAINER_BOTTOM_MARGIN: float = 72.0

@export_group("Assembled arm")
## Nudges the assembled arm's centre within the table assembly area. Editable in
## the editor: open WorkArmMinigame.tscn and select the root node.
@export var arm_position_offset: Vector2 = Vector2(0.0, 40.0)
## Uniform scale of the assembled arm. The loose draggable segments are scaled to
## match, so a piece is the same size while dragged as it is once placed. 1.0 is
## the original art size. Editable in the editor alongside arm_position_offset.
@export var arm_scale: float = 1.0

@onready var furniture: Control = $Furniture
@onready var assembly_area: Control = $Furniture/AssemblyArea
@onready var side_containers: Control = $SideContainers
@onready var left_container: PanelContainer = $SideContainers/LeftContainer
@onready var right_container: PanelContainer = $SideContainers/RightContainer
@onready var left_holder: Control = $SideContainers/LeftContainer/Holder
@onready var right_holder: Control = $SideContainers/RightContainer/Holder

var _assembly_slots: Dictionary = {}
var _segment_defs: Dictionary = {}
var _active_slot_ids: Array[StringName] = []
var _arm_assembly: Control = null
var _all_segments: Array = []

var _active_drag_segment: WorkshopSegment = null

var _placement_hint_layer: Control = null
var _placement_hint_sprite: TextureRect = null
var _pending_hint_entries: Array = []
var _placement_hint_elapsed: float = 0.0

var _completed: bool = false
var _started: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_arm_assembly()
	_spawn_segments()
	_setup_placement_hint_layer()


## Called by the Work location after it has handed `furniture` and
## `side_containers` off to Main's overlays, so layout happens once the nodes
## are anchored in their final parents.
func begin() -> void:
	_started = true
	_position_side_containers()


func _process(_delta: float) -> void:
	if not _started or _completed:
		return
	_position_side_containers()
	_pin_resting_segments()
	_update_placement_hint_flash(_delta)


# --- input / dragging ------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not _started or _completed:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_left_press(event.global_position)
		else:
			_handle_left_release(event.global_position)
	elif event is InputEventMouseMotion and _active_drag_segment != null:
		_active_drag_segment.update_drag(event.global_position)
		get_viewport().set_input_as_handled()


func _handle_left_press(global_pos: Vector2) -> void:
	if _active_drag_segment != null:
		return
	var seg: WorkshopSegment = _find_topmost_segment_at(global_pos)
	if seg != null:
		_pick_up_segment(seg, global_pos)
		get_viewport().set_input_as_handled()


func _handle_left_release(global_pos: Vector2) -> void:
	if _active_drag_segment == null:
		return
	var seg: WorkshopSegment = _active_drag_segment
	_active_drag_segment = null
	_clear_placement_hints()
	seg.end_drag()

	var slot: WorkshopAssemblySlot = _best_segment_drop_target(seg, global_pos)
	if slot != null:
		_accept_segment_into_slot(seg, slot)
		_refresh_complete()
	# Otherwise the segment simply stays where it was released (it is already
	# parented to the top overlay at its dropped position) — no snap-back.
	get_viewport().set_input_as_handled()


func _pick_up_segment(segment: WorkshopSegment, global_pos: Vector2) -> void:
	# Reparent onto the top-most overlay (the side containers) so the dragged
	# piece renders above both the table and the container panels.
	if segment.get_parent() != side_containers:
		var gp: Vector2 = segment.global_position
		segment.get_parent().remove_child(segment)
		side_containers.add_child(segment)
		segment.global_position = gp
	side_containers.move_child(segment, side_containers.get_child_count() - 1)

	_active_drag_segment = segment
	# Once grabbed, a segment is never auto-pinned back to its container slot —
	# it stays wherever the player releases it.
	segment.set_meta("moved", true)
	segment.start_drag(global_pos)

	_show_segment_placement_hints([segment])
	# Keep the dragged piece above the hint sprite.
	if _placement_hint_layer != null and _placement_hint_layer.visible:
		side_containers.move_child(_placement_hint_layer, side_containers.get_child_count() - 1)
		side_containers.move_child(segment, side_containers.get_child_count() - 1)


# --- hit testing -----------------------------------------------------------

func _find_topmost_segment_at(global_pos: Vector2) -> WorkshopSegment:
	var hits: Array = []
	_collect_segments(get_tree().current_scene, hits)
	for i in range(hits.size() - 1, -1, -1):
		var seg: WorkshopSegment = hits[i]
		if seg.hit_test(global_pos):
			return seg
	return null


func _collect_segments(node: Node, out: Array) -> void:
	if node == null:
		return
	for child in node.get_children():
		if child is WorkshopSegment:
			out.append(child)
		_collect_segments(child, out)


# --- drop scoring (mirrors WorkshopMinigame) -------------------------------

func _best_segment_drop_target(segment: WorkshopSegment, release_global_pos: Vector2) -> WorkshopAssemblySlot:
	var best_slot: WorkshopAssemblySlot = null
	var best_score: float = -1.0e19
	for slot_id in _active_slot_ids:
		var slot: WorkshopAssemblySlot = _assembly_slots.get(slot_id)
		var score: float = _segment_drop_score(segment, slot, release_global_pos)
		if score > best_score:
			best_score = score
			best_slot = slot
	if best_score <= -1.0e19:
		return null
	return best_slot


func _segment_drop_score(segment: WorkshopSegment, slot: WorkshopAssemblySlot, release_global_pos: Vector2) -> float:
	if segment == null or slot == null or slot.filled:
		return -1.0e20
	if segment.segment_id != slot.accepts_segment_id:
		return -1.0e20

	var slot_hitbox: Rect2 = slot.get_global_hitbox()
	var segment_hitbox: Rect2 = segment.get_global_hitbox()
	var release_hits_slot: bool = slot_hitbox.has_point(release_global_pos)
	var overlap_area: float = _rect_overlap_area(segment_hitbox, slot_hitbox)
	if not release_hits_slot and overlap_area <= 0.0:
		return -1.0e20

	var slot_center: Vector2 = slot_hitbox.position + slot_hitbox.size * 0.5
	var score: float = overlap_area - release_global_pos.distance_squared_to(slot_center) * 0.001
	if release_hits_slot:
		score += 1000000.0
	return score


func _rect_overlap_area(a: Rect2, b: Rect2) -> float:
	var left: float = maxf(a.position.x, b.position.x)
	var top: float = maxf(a.position.y, b.position.y)
	var right: float = minf(a.end.x, b.end.x)
	var bottom: float = minf(a.end.y, b.end.y)
	if right <= left or bottom <= top:
		return 0.0
	return (right - left) * (bottom - top)


func _accept_segment_into_slot(segment: WorkshopSegment, slot: WorkshopAssemblySlot) -> void:
	if segment == null or slot == null:
		return
	_clear_placed_part_outline(segment)
	slot.accept_segment(segment)
	# The slot lives under the scaled assembly, which now provides the arm scale,
	# so drop the loose-segment scale to avoid compounding it.
	segment.scale = Vector2.ONE
	segment.position = segment.placement_offset


## Drop the pick-up-only outline once a piece is placed, keeping any outline that
## is part of the final art (elbow inner gears).
func _clear_placed_part_outline(segment: WorkshopSegment) -> void:
	for child in segment.get_children():
		if not (child is WorkshopPiece):
			continue
		var piece := child as WorkshopPiece
		if piece.persistent_outline:
			continue
		piece.outline_texture = null
		piece.queue_redraw()


# --- assembly setup --------------------------------------------------------

func _setup_arm_assembly() -> void:
	_arm_assembly = Control.new()
	_arm_assembly.name = "AssemblyArm"
	_arm_assembly.size = ARM_ASSEMBLY_SIZE
	_arm_assembly.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var content_bounds: Rect2 = Rect2()
	var found_any: bool = false

	for segment_id in UPPER_ARM_SEGMENT_IDS:
		var tex: Texture2D = _load_arm_layer(segment_id)
		if tex == null:
			push_warning("WorkArmMinigame: missing arm layer '%s' in %s." % [segment_id, ARM_TEXTURE_DIR])
			continue

		var used_rect: Rect2 = _used_rect_for_texture(tex)
		if used_rect.size.x > 0.0 and used_rect.size.y > 0.0:
			if not found_any:
				content_bounds = used_rect
				found_any = true
			else:
				content_bounds = content_bounds.merge(used_rect)

		var slot := WorkshopAssemblySlot.new()
		slot.name = "%sSlot" % String(segment_id).capitalize().replace(" ", "")
		slot.accepts_segment_id = segment_id
		slot.position = Vector2.ZERO
		slot.size = ARM_ASSEMBLY_SIZE
		slot.hitbox_rect = used_rect
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_arm_assembly.add_child(slot)
		_assembly_slots[segment_id] = slot
		_active_slot_ids.append(segment_id)
		_segment_defs[segment_id] = {
			"id": segment_id,
			"texture": tex,
			"outline": _load_arm_outline(segment_id),
			"persistent_outline": PERSISTENT_OUTLINE_IDS.has(segment_id),
		}

	if not found_any:
		content_bounds = Rect2(Vector2.ZERO, ARM_ASSEMBLY_SIZE)
	# Centre the visible cluster (not the whole 350x350 canvas) in the assembly
	# area, then apply the editor position/scale. The pivot is set to the cluster
	# centre so scaling keeps the arm centred on the same spot on the table.
	var content_center: Vector2 = content_bounds.position + content_bounds.size * 0.5
	_arm_assembly.pivot_offset = content_center
	_arm_assembly.scale = Vector2(_effective_scale(), _effective_scale())
	_arm_assembly.position = ARM_ASSEMBLY_SIZE * 0.5 - content_center + arm_position_offset
	assembly_area.add_child(_arm_assembly)


## Clamped uniform scale for the assembled arm and the loose segments.
func _effective_scale() -> float:
	return maxf(0.05, arm_scale)


func _spawn_segments() -> void:
	for segment_id in _active_slot_ids:
		var segment: WorkshopSegment = _build_segment(segment_id)
		if segment != null:
			_all_segments.append(segment)

	# Shuffle so the pieces aren't in the same container slots every shift, then
	# split as evenly as possible between the two containers (5 / 4 for 9 pieces).
	var shuffled: Array = _all_segments.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(shuffled.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp

	var total: int = shuffled.size()
	var left_count: int = int(ceil(float(total) / 2.0))
	var left_segments: Array = shuffled.slice(0, left_count)
	var right_segments: Array = shuffled.slice(left_count, total)
	_assign_to_holder(left_holder, left_segments)
	_assign_to_holder(right_holder, right_segments)


func _build_segment(segment_id: StringName) -> WorkshopSegment:
	var piece_def: Dictionary = _segment_defs.get(segment_id, {})
	var tex: Texture2D = piece_def.get("texture")
	if tex == null:
		return null

	var segment := WorkshopSegment.new()
	segment.name = "Segment_" + String(segment_id)
	segment.segment_id = segment_id
	segment.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var piece := _make_segment_piece(segment_id, piece_def)
	segment.add_child(piece)
	piece.position = Vector2.ZERO

	var bounds: Rect2 = _piece_visible_rect(piece)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		bounds = Rect2(Vector2.ZERO, ARM_ASSEMBLY_SIZE)
	piece.position -= bounds.position
	segment.size = bounds.size
	segment.placement_offset = bounds.position
	segment.auto_fit_grab_hitbox = true
	# Match the assembled arm's scale so a loose piece is the same size while
	# dragged as it is once placed. Reset to 1 on placement (the assembly node
	# then provides the scale — see _accept_segment_into_slot).
	segment.scale = Vector2(_effective_scale(), _effective_scale())
	return segment


func _make_segment_piece(segment_id: StringName, piece_def: Dictionary) -> WorkshopPiece:
	var piece := WorkshopPiece.new()
	piece.item_id = segment_id
	piece.segment_id = segment_id
	piece.texture = piece_def.get("texture")
	piece.outline_texture = piece_def.get("outline")
	piece.persistent_outline = bool(piece_def.get("persistent_outline", false))
	piece.auto_center = false
	piece.visual_offset = Vector2.ZERO
	if piece.texture != null:
		piece.size = piece.texture.get_size()
	return piece


func _assign_to_holder(holder: Control, segments: Array) -> void:
	var count: int = segments.size()
	for i in count:
		var segment: WorkshopSegment = segments[i]
		holder.add_child(segment)
		segment.set_meta("home_holder", holder)
		segment.set_meta("home_index", i)
		segment.set_meta("home_count", count)


## Keep every never-grabbed segment pinned to its evenly-spaced slot in its home
## container, so the untouched bin self-corrects after the containers get
## repositioned or the window resizes. Once a segment has been picked up (its
## "moved" meta is set) it is left wherever the player dropped it — no snap-back.
func _pin_resting_segments() -> void:
	for segment in _all_segments:
		if not is_instance_valid(segment):
			continue
		if segment == _active_drag_segment or segment.locked:
			continue
		if bool(segment.get_meta("moved", false)):
			continue
		var holder: Control = segment.get_meta("home_holder", null)
		if holder == null or not is_instance_valid(holder) or segment.get_parent() != holder:
			continue
		var count: int = int(segment.get_meta("home_count", 1))
		var index: int = int(segment.get_meta("home_index", 0))
		var hs: Vector2 = holder.size
		if hs.x <= 0.0 or hs.y <= 0.0:
			continue
		var scale_value: float = _effective_scale()
		var target_center := Vector2(hs.x * 0.5, hs.y * (float(index) + 0.5) / float(count))
		var hb: Rect2 = segment.grab_hitbox_rect
		var hb_center: Vector2 = hb.position + hb.size * 0.5 if hb.size.x > 0.0 else segment.size * 0.5
		# The segment carries the arm scale, so its art centre sits scale*hb_center
		# from its top-left; offset by that so the visible piece lands centred.
		segment.position = target_center - hb_center * scale_value


# --- side-container positioning --------------------------------------------

func _position_side_containers() -> void:
	if left_container == null or right_container == null:
		return
	var viewport_width: float = get_viewport_rect().size.x
	var viewport_height: float = get_viewport_rect().size.y
	var image_rect: Rect2 = _scene_image_global_rect()
	var left_space: float = maxf(0.0, image_rect.position.x)
	var right_space: float = maxf(0.0, viewport_width - image_rect.end.x)
	var left_gap: float = _hud_outer_gap(left_space)
	var right_gap: float = _hud_outer_gap(right_space)
	var top: float = HUD_MARGIN.y + HUD_LEFT_PANEL_HEIGHT + CONTAINER_TOP_GAP
	var bottom: float = viewport_height - CONTAINER_BOTTOM_MARGIN

	left_container.anchor_left = 0.0
	left_container.anchor_right = 0.0
	left_container.offset_left = left_gap
	left_container.offset_right = left_gap + HUD_PANEL_WIDTH
	left_container.offset_top = top
	left_container.offset_bottom = bottom

	right_container.anchor_left = 1.0
	right_container.anchor_right = 1.0
	right_container.offset_left = -right_gap - HUD_PANEL_WIDTH
	right_container.offset_right = -right_gap
	right_container.offset_top = top
	right_container.offset_bottom = bottom


func _hud_outer_gap(side_space: float) -> float:
	var available_gap: float = maxf(0.0, side_space - HUD_PANEL_WIDTH)
	return minf(HUD_MARGIN.x * 0.5, available_gap * 0.5)


func _scene_image_global_rect() -> Rect2:
	var main: Node = get_tree().current_scene
	if main != null and "scene_image" in main and main.scene_image != null:
		return (main.scene_image as Control).get_global_rect()
	return Rect2(Vector2.ZERO, get_viewport_rect().size)


# --- completion ------------------------------------------------------------

func _refresh_complete() -> void:
	if _completed:
		return
	for slot_id in _active_slot_ids:
		var slot: WorkshopAssemblySlot = _assembly_slots.get(slot_id)
		if slot == null or not slot.filled:
			return
	_completed = true
	completed.emit()


## Debug (Work forwards number-6 / held-Enter): drop every remaining segment
## straight into its slot so the puzzle completes without manual dragging.
func debug_auto_solve() -> void:
	if _completed:
		return
	for slot_id in _active_slot_ids:
		var slot: WorkshopAssemblySlot = _assembly_slots.get(slot_id)
		if slot == null or slot.filled:
			continue
		var segment: WorkshopSegment = _segment_for_id(slot_id)
		if segment == null or segment.locked:
			continue
		segment.end_drag()
		_accept_segment_into_slot(segment, slot)
	_refresh_complete()


func _segment_for_id(segment_id: StringName) -> WorkshopSegment:
	for segment in _all_segments:
		if is_instance_valid(segment) and not segment.locked and segment.segment_id == segment_id:
			return segment
	return null


# --- placement hints (easy-workshop gated flashing) ------------------------

func _easy_workshop_enabled() -> bool:
	var settings := get_node_or_null("/root/GameState")
	return settings != null and settings.easy_workshop_enabled


## Hints only flash when Easy Workshop Mode is on. Off -> no hint at all.
func _hints_active() -> bool:
	return _easy_workshop_enabled()


func _setup_placement_hint_layer() -> void:
	_placement_hint_layer = Control.new()
	_placement_hint_layer.name = "PlacementHintLayer"
	_placement_hint_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placement_hint_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_placement_hint_layer.visible = false
	side_containers.add_child(_placement_hint_layer)


func _show_segment_placement_hints(segments: Array) -> void:
	_clear_placement_hints()
	if not _hints_active():
		return
	for segment in segments:
		if not (segment is WorkshopSegment):
			continue
		if not is_instance_valid(segment) or segment.locked:
			continue
		for slot in _slots_for_segment(segment):
			if slot == null or slot.filled:
				continue
			var slot_xform: Transform2D = slot.get_global_transform()
			var target_placement_offset: Vector2 = segment.placement_offset
			for child in segment.get_children():
				if child is WorkshopPiece:
					var piece := child as WorkshopPiece
					var texture_global_position: Vector2 = slot_xform * (
						target_placement_offset
						+ piece.position
						+ piece.texture_draw_position()
					)
					_add_piece_hint(piece, texture_global_position, _effective_scale())
	_show_placement_hint_layer()


func _slots_for_segment(segment: WorkshopSegment) -> Array:
	var slots: Array = []
	for slot_id in _active_slot_ids:
		var slot: WorkshopAssemblySlot = _assembly_slots.get(slot_id)
		if slot != null and slot.accepts_segment_id == segment.segment_id:
			slots.append(slot)
	return slots


func _add_piece_hint(piece: WorkshopPiece, target_texture_global_position: Vector2, draw_scale: float = 1.0) -> void:
	if _placement_hint_layer == null or piece == null or piece.texture == null:
		return
	# Sizes are multiplied by the arm scale so the flashing hint matches the size
	# the piece renders at once placed under the scaled assembly.
	if piece.outline_texture != null and piece.persistent_outline:
		_pending_hint_entries.append({
			"texture": piece.outline_texture,
			"position": target_texture_global_position,
			"size": piece.texture_draw_size(piece.outline_texture) * draw_scale,
		})
	_pending_hint_entries.append({
		"texture": piece.texture,
		"position": target_texture_global_position,
		"size": piece.texture_draw_size() * draw_scale,
	})


## Bake all pending hint pieces into one flat texture so it can fade as a single
## straight-alpha image (see WorkshopMinigame for the GL Compatibility rationale).
func _bake_pending_hints() -> void:
	if _pending_hint_entries.is_empty():
		return

	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for e in _pending_hint_entries:
		var p: Vector2 = e["position"]
		var s: Vector2 = e["size"]
		min_p = min_p.min(p)
		max_p = max_p.max(p + s)

	var origin := Vector2(floorf(min_p.x), floorf(min_p.y))
	var w := int(ceilf(max_p.x - origin.x))
	var h := int(ceilf(max_p.y - origin.y))
	if w <= 0 or h <= 0:
		return

	var canvas := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for e in _pending_hint_entries:
		var tex: Texture2D = e["texture"]
		if tex == null:
			continue
		var src: Image = tex.get_image()
		if src == null:
			continue
		if src.is_compressed():
			src.decompress()
		if src.get_format() != Image.FORMAT_RGBA8:
			src.convert(Image.FORMAT_RGBA8)
		var s: Vector2 = e["size"]
		var sw := maxi(1, int(roundf(s.x)))
		var sh := maxi(1, int(roundf(s.y)))
		if src.get_width() != sw or src.get_height() != sh:
			src.resize(sw, sh, Image.INTERPOLATE_BILINEAR)
		var p: Vector2 = e["position"]
		var dst := Vector2i(int(roundf(p.x - origin.x)), int(roundf(p.y - origin.y)))
		canvas.blend_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), dst)

	_placement_hint_sprite = TextureRect.new()
	_placement_hint_sprite.texture = ImageTexture.create_from_image(canvas)
	_placement_hint_sprite.size = Vector2(w, h)
	_placement_hint_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placement_hint_layer.add_child(_placement_hint_sprite)
	_placement_hint_sprite.global_position = origin
	_pending_hint_entries.clear()


func _show_placement_hint_layer() -> void:
	if _placement_hint_layer == null:
		return
	_bake_pending_hints()
	var has_hints: bool = _placement_hint_sprite != null and is_instance_valid(_placement_hint_sprite)
	_placement_hint_layer.visible = has_hints
	_placement_hint_layer.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if has_hints:
		var color := _placement_hint_sprite.modulate
		color.a = 0.85
		_placement_hint_sprite.modulate = color
	_placement_hint_elapsed = 0.0


func _update_placement_hint_flash(delta: float) -> void:
	if _placement_hint_layer == null or not _placement_hint_layer.visible:
		return
	if _placement_hint_sprite == null or not is_instance_valid(_placement_hint_sprite):
		return
	_placement_hint_elapsed += delta
	var wave := (sin(_placement_hint_elapsed * TAU * 1.45) + 1.0) * 0.5
	var color := _placement_hint_sprite.modulate
	color.a = lerpf(0.2, 0.85, wave)
	_placement_hint_sprite.modulate = color


func _clear_placement_hints() -> void:
	if _placement_hint_layer == null:
		return
	for child in _placement_hint_layer.get_children():
		child.queue_free()
	_placement_hint_sprite = null
	_pending_hint_entries.clear()
	_placement_hint_layer.visible = false
	_placement_hint_elapsed = 0.0


# --- texture helpers -------------------------------------------------------

func _load_arm_layer(segment_id: StringName) -> Texture2D:
	return _load_texture("%s/%s.png" % [ARM_TEXTURE_DIR, segment_id])


func _load_arm_outline(segment_id: StringName) -> Texture2D:
	return _load_texture("%s/%s_outline.png" % [ARM_TEXTURE_DIR, segment_id])


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _used_rect_for_texture(tex: Texture2D) -> Rect2:
	if tex == null:
		return Rect2(Vector2.ZERO, ARM_ASSEMBLY_SIZE)
	var img: Image = tex.get_image()
	if img == null:
		return Rect2(Vector2.ZERO, tex.get_size())
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return Rect2(Vector2.ZERO, tex.get_size())
	return Rect2(Vector2(used.position), Vector2(used.size))


func _piece_visible_rect(piece: WorkshopPiece) -> Rect2:
	if piece == null or piece.texture == null:
		return Rect2()
	var img: Image = piece.texture.get_image()
	if img == null:
		return Rect2(Vector2.ZERO, piece.texture.get_size())
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return Rect2()
	var scale_value: float = maxf(0.001, piece.visual_scale)
	return Rect2(
		piece.texture_draw_position() + Vector2(used.position) * scale_value,
		Vector2(used.size) * scale_value
	)
