extends Control
class_name WorkshopMinigame

signal collected(part_id: String)
signal ended()
## Emitted once, after the player has spent EASY_MODE_OFFER_SECONDS in a normal
## (non-tutorial) workshop with Easy Workshop Mode still off, so the location can
## offer to switch it on.
signal easy_mode_offered()

## How long the player struggles before the Easy Workshop Mode offer appears.
const EASY_MODE_OFFER_SECONDS: float = 60.0

@export var forced_part_id: String = ""

## Fine-tune the on-screen placement of the procedurally-built head and arm
## assemblies. These are created at runtime (unlike the leg, which is authored
## in the scene), so this is the only way to nudge them in the editor. The arm
## defaults to having its visible art centred in the assembly area.
@export var head_assembly_offset: Vector2 = Vector2.ZERO
@export var arm_assembly_offset: Vector2 = Vector2.ZERO
@export var hand_assembly_offset: Vector2 = Vector2.ZERO
@export var stomach_assembly_offset: Vector2 = Vector2.ZERO
@export var chest_assembly_offset: Vector2 = Vector2.ZERO

const CRAFTABLE_PARTS: Dictionary = {
	"head": {
		"display_name": "Head",
		"recipe": {"head_segments": 1},
	},
	"leg": {
		"display_name": "Leg",
		"recipe": {"scrap_metal": 1},
	},
	"arm": {
		"display_name": "Arm",
		"recipe": {"nuts_bolts": 1},
	},
	"hand": {
		"display_name": "Hand",
		"recipe": {"nanobots": 1},
	},
	"stomach": {
		"display_name": "Stomach",
		"recipe": {"synth_skin": 1},
	},
	"chest": {
		"display_name": "Chest",
		"recipe": {"electronics": 1},
	},
}

const INGREDIENT_PATHS: Dictionary = {
	"scrap_metal":   "res://assets/textures/icons/scrap_metal.png",
	"nuts_bolts":    "res://assets/textures/icons/nuts_bolts.png",
	"nanobots":      "res://assets/textures/icons/nanobots.png",
	"electronics":   "res://assets/textures/icons/electronics.png",
	"synth_skin":    "res://assets/textures/icons/synth_skin.png",
	"head_segments": "res://assets/textures/icons/head_segments.png",
	"oil":           "res://assets/textures/icons/oil.png",
}
const HEAD_TEXTURE_DIR: String = "res://assets/textures/characters/robot/workshop/workshop robot head"
const HEAD_ASSEMBLY_SIZE: Vector2 = Vector2(200, 200)
## Back-to-front draw order for the assembled head. Godot draws later Control
## siblings on top, so this is the reverse of the visible layer stack.
const HEAD_SEGMENT_IDS: Array[StringName] = [
	&"neck",
	&"metal_head",
	&"left_eye",
	&"right_eye",
	&"mouth",
	&"nose",
	&"forehead",
	&"right_side_panel",
	&"left_side_panel",
	&"right_eyelid",
	&"left_eyelid",
	&"right_cheek",
	&"left_cheek",
	&"right_ear",
	&"left_ear",
	&"hair",
]
const HEAD_EYE_SEGMENT_IDS: Array[StringName] = [&"left_eye", &"right_eye"]
const HEAD_EYELID_SEGMENT_IDS: Array[StringName] = [&"left_eyelid", &"right_eyelid"]
const HEAD_EYE_HITBOX_GROW: Vector2 = Vector2(18.0, 14.0)

const ARM_TEXTURE_DIR: String = "res://assets/textures/characters/robot/workshop/workshop robot arm"
const ARM_ASSEMBLY_SIZE: Vector2 = Vector2(350, 350)
## Back-to-front draw order for the assembled arm. Godot draws later Control
## siblings on top, so this is the reverse of the Aseprite layer stack. The
## "_outline" layers are not listed here — each is loaded as its base piece's
## outline (drawn behind the base, dragged with it, hidden once placed).
##
## The hand (fingers, palm, thumb) is now its own craftable part — see
## HAND_SEGMENT_IDS — so it is no longer part of the arm and its segments are not
## handed out when crafting an arm. The arm runs shoulder -> forearm -> wrist.
const ARM_SEGMENT_IDS: Array[StringName] = [
	&"wrist",
	&"elbow_inner_gears",
	&"forearm_lower",
	&"forearm",
	&"elbow_joint",
	&"elbow_cap",
	&"upper_arm_plate_lower",
	&"upper_arm_plate",
	&"bicep",
	&"tricep",
	&"shoulder_pad",
	&"shoulder_joint",
]
## The hand is grafted separately (recipe: nanobots). Its segments live in the
## same arm art directory. Back-to-front draw order, same convention as the arm.
const HAND_TEXTURE_DIR: String = "res://assets/textures/characters/robot/workshop/workshop robot arm"
const HAND_ASSEMBLY_SIZE: Vector2 = Vector2(350, 350)
## hand_right (the upper/right palm) is drawn before hand_left so the left palm's
## texture sits on top of it — see HAND_PERSISTENT_OUTLINE_IDS.
const HAND_SEGMENT_IDS: Array[StringName] = [
	&"thumb_base",
	&"thumb_tip",
	&"hand_right",
	&"hand_left",
	&"pinky_base",
	&"pinky_tip",
	&"ring_tip",
	&"ring_base",
	&"middle_base",
	&"middle_tip",
	&"pointer_tip",
	&"pointer_base",
]
## Hand segments whose "_outline" is part of the final art and must keep drawing
## after placement. hand_right's seam outline is kept; it draws under hand_left
## (see the order above) so the left palm texture stays on top of it.
const HAND_PERSISTENT_OUTLINE_IDS: Array[StringName] = [&"hand_right"]
## Arm segments whose "_outline" is part of the final art and must keep drawing
## after the piece is placed (rather than acting as a pick-up-only drag hint).
const ARM_PERSISTENT_OUTLINE_IDS: Array[StringName] = [&"elbow_inner_gears"]

## The stomach and chest are built with `unified_outline` enabled: their
## "_outline" layers are authored as one contiguous block *behind* every base
## layer, so a placed piece keeps its outline (repainted behind all bases by a
## unified outline layer) instead of the arm/head behaviour where a placed
## outline is dropped.
##
## (The stomach art still lives under the legacy "workshop robot body/torso"
## folder; the segment names below are its texture filenames.)
const STOMACH_TEXTURE_DIR: String = "res://assets/textures/characters/robot/workshop/workshop robot body/torso"
const STOMACH_ASSEMBLY_SIZE: Vector2 = Vector2(337, 337)
## Back-to-front draw order for the assembled stomach. Godot draws later Control
## siblings on top, so this is the reverse of the Aseprite layer stack (taken
## bottom-to-top straight from the source .ase). The "_outline" layers are not
## listed here — each is loaded as its base piece's outline, kept visible behind
## all bases once placed.
const STOMACH_SEGMENT_IDS: Array[StringName] = [
	&"top_torso",
	&"belly_button",
	&"gut",
	&"pelvis",
	&"left_torso",
	&"right_torso",
	&"left_socket",
	&"right_socket",
]

const CHEST_TEXTURE_DIR: String = "res://assets/textures/characters/robot/workshop/workshop robot body/chest"
const CHEST_ASSEMBLY_SIZE: Vector2 = Vector2(337, 337)
## Back-to-front draw order for the assembled chest — reverse of the chest group's
## Aseprite layer stack. Only some segments ship an "_outline" layer (collars,
## shoulders and neck do not); the loader returns null for the rest, which is fine.
const CHEST_SEGMENT_IDS: Array[StringName] = [
	&"left_chest",
	&"right_chest",
	&"right_collar",
	&"left_collar",
	&"mid_chest",
	&"left_hole",
	&"right_hole",
	&"left_shoulder",
	&"right_shoulder",
	&"turtle",
	&"neck",
]
const INGREDIENT_SHADOW_PATHS: Dictionary = {
	"scrap_metal":   "res://assets/textures/icons/scrap_metal_shadow.png",
	"nuts_bolts":    "res://assets/textures/icons/nuts_bolts_shadow.png",
	"electronics":   "res://assets/textures/icons/electronics_shadow.png",
	"synth_skin":    "res://assets/textures/icons/synth_skin_shadow.png",
	"head_segments": "res://assets/textures/icons/head_segments.png",
	"oil":           "res://assets/textures/icons/oil_shadow.png",
}
const UI_SOUND := preload("res://scenes/ui/UiSound.gd")
const WORKSHOP_PIECE_SCRIPT_PATH: String = "res://scenes/locations/WorkshopPiece.gd"

@onready var ingredients_tray: Control = %IngredientsTray
@onready var craft_bin: WorkshopBin = %CraftBin
@onready var craft_button: Button = %CraftButton
@onready var assembly: Control = %AssemblyArea
@onready var collect_button: Button = %CollectButton
@onready var end_button: Button = %EndButton

var _segments: Dictionary = {}
var _assembly_slots: Dictionary = {}
var _leg_assembly_slot_ids: Array[StringName] = []
var _active_assembly_slot_ids: Array[StringName] = []
var _head_slot_placement_offsets: Dictionary = {}
var _head_assembly: Control = null
var _arm_assembly: Control = null
var _hand_assembly: Control = null
var _stomach_assembly: Control = null
var _chest_assembly: Control = null
## Slot ids actually built for the procedural hand/stomach/chest assemblies.
## Chest keys are namespaced (see the key_prefix in _build_segmented_assembly) so
## a shared segment name like "neck" can't collide with the head's slot.
var _hand_assembly_slot_ids: Array[StringName] = []
var _stomach_assembly_slot_ids: Array[StringName] = []
var _chest_assembly_slot_ids: Array[StringName] = []
## Back outline layers (one per unified-outline assembly) that repaint every
## placed piece's outline behind all base art.
var _unified_outline_layers: Array = []

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
var _placement_hint_sprite: TextureRect = null
var _pending_hint_entries: Array = []
var _placement_hint_elapsed: float = 0.0
## Wall-clock time spent in this workshop session, used to time the Easy Workshop
## Mode offer. The offer fires once when it crosses EASY_MODE_OFFER_SECONDS.
var _workshop_elapsed: float = 0.0
var _easy_mode_offer_made: bool = false


func _enter_tree() -> void:
	var assembly_node := get_node_or_null("AssemblyArea") as Control
	if assembly_node != null:
		_collect_assembly_slots(assembly_node)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spawn_rng.randomize()

	_setup_head_assembly()
	_setup_arm_assembly()
	_hand_assembly = _build_segmented_assembly(
		"AssemblyHand", HAND_TEXTURE_DIR, HAND_SEGMENT_IDS, HAND_ASSEMBLY_SIZE,
		hand_assembly_offset, false, "hand_", _hand_assembly_slot_ids,
		HAND_PERSISTENT_OUTLINE_IDS)
	_stomach_assembly = _build_segmented_assembly(
		"AssemblyStomach", STOMACH_TEXTURE_DIR, STOMACH_SEGMENT_IDS, STOMACH_ASSEMBLY_SIZE,
		stomach_assembly_offset, true, "", _stomach_assembly_slot_ids)
	_chest_assembly = _build_segmented_assembly(
		"AssemblyChest", CHEST_TEXTURE_DIR, CHEST_SEGMENT_IDS, CHEST_ASSEMBLY_SIZE,
		chest_assembly_offset, true, "chest_", _chest_assembly_slot_ids)
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
	end_button.pressed.connect(_on_end_button_pressed)


func _on_end_button_pressed() -> void:
	ended.emit()


func _process(_delta: float) -> void:
	# Force shadow drawer to redraw every frame so shadows follow smoothly while dragging
	if is_instance_valid(_shadow_drawer):
		_shadow_drawer.queue_redraw()
	# Keep unified outlines (stomach/chest) tracking their pieces every frame so a
	# placed piece's outline follows it while it eases into its slot.
	_queue_unified_outline_redraw()
	_sync_passenger_segments_to_active_drag()
	_update_placement_hint_flash(_delta)
	_update_easy_mode_offer(_delta)
	if _debug_mode_enabled() and _enter_held():
		_auto_progress_with_enter()


## Time the workshop session and, once the player has been at it for a while with
## Easy Workshop Mode still off (and outside the guided intro), offer it once.
func _update_easy_mode_offer(delta: float) -> void:
	if _easy_mode_offer_made or _is_tutorial_workshop() or _easy_workshop_enabled():
		return
	_workshop_elapsed += delta
	if _workshop_elapsed >= EASY_MODE_OFFER_SECONDS:
		_easy_mode_offer_made = true
		easy_mode_offered.emit()


## The intro/tutorial workshop keeps its guiding hints on regardless of the Easy
## Workshop Mode setting; it is the one forced-part run.
func _is_tutorial_workshop() -> bool:
	return not forced_part_id.strip_edges().is_empty()


func _easy_workshop_enabled() -> bool:
	var settings := get_node_or_null("/root/GameState")
	return settings != null and settings.easy_workshop_enabled


## Placement hints only flash in Easy Workshop Mode (or the guided intro). When
## off, no hint is shown.
func _hints_active() -> bool:
	return _easy_workshop_enabled() or _is_tutorial_workshop()


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
			
			var s_off: Vector2 = child.shadow_offset if typeof(child.shadow_offset) == TYPE_VECTOR2 else Vector2.ZERO
			
			# Draw FULLY opaque white. If drawn full black, intersections remain max black. 
			# The CanvasGroup applies the 50% opacity uniformly to the resulting combined shapes later!
			_shadow_drawer.draw_texture_rect(
				child.shadow_texture,
				Rect2(
					child.texture_draw_position(child.shadow_texture) + s_off,
					child.texture_draw_size(child.shadow_texture)
				),
				false,
				Color(1, 1, 1, 1)
			)
			
		_draw_shadows_recursive(child)


func _setup_placement_hint_layer() -> void:
	_placement_hint_layer = Control.new()
	_placement_hint_layer.name = "PlacementHintLayer"
	_placement_hint_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placement_hint_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_placement_hint_layer.visible = false
	add_child(_placement_hint_layer)


## Composites all of the current hint's pieces into one flat texture (cap over
## axle) and displays it as a single TextureRect. Baking to one sprite is what
## lets the hint fade as a single image: a lone straight-alpha texture dissolves
## cleanly via modulate.a, with none of the reveal (each piece fading on its own)
## or the CanvasGroup pitfalls in the GL Compatibility renderer (custom materials
## render as a white box; modulate tints premultiplied colour white or black).
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
		# blend_rect alpha-composites src over the canvas, so entries added
		# back-to-front (axle then cap) merge with the cap on top.
		canvas.blend_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), dst)

	_placement_hint_sprite = TextureRect.new()
	_placement_hint_sprite.texture = ImageTexture.create_from_image(canvas)
	_placement_hint_sprite.size = Vector2(w, h)
	_placement_hint_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placement_hint_layer.add_child(_placement_hint_sprite)
	_placement_hint_sprite.global_position = origin
	_pending_hint_entries.clear()


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


func _show_piece_placement_hint(piece: WorkshopPiece, target_global_position: Vector2) -> void:
	_clear_placement_hints()
	if not _hints_active():
		return
	_add_piece_hint(piece, target_global_position)
	_show_placement_hint_layer()


func _show_segment_placement_hints(segments: Array) -> void:
	_clear_placement_hints()
	if not _hints_active():
		return
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
	_bake_pending_hints()
	var has_hints: bool = _placement_hint_sprite != null and is_instance_valid(_placement_hint_sprite)
	_placement_hint_layer.visible = has_hints
	_placement_hint_layer.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if has_hints:
		var color := _placement_hint_sprite.modulate
		color.a = 0.85
		_placement_hint_sprite.modulate = color
	_placement_hint_elapsed = 0.0


func _add_piece_hint(piece: WorkshopPiece, target_texture_global_position: Vector2) -> void:
	if _placement_hint_layer == null or piece == null or piece.texture == null:
		return
	# When the piece's outline is part of the final art (chest/stomach unified
	# outlines, or any persistent outline) bake it behind the base so the hint
	# matches how the piece looks once placed. Both textures share the piece's
	# draw origin, so they use the same target position; adding the outline first
	# keeps it behind the base in the composite.
	if piece.outline_texture != null and (piece.unified_outline or piece.persistent_outline):
		_pending_hint_entries.append({
			"texture": piece.outline_texture,
			"position": target_texture_global_position,
			"size": piece.texture_draw_size(piece.outline_texture),
		})
	# Queue the piece's real art for baking. Entries are added back-to-front by
	# the caller, so when they are composited into one texture the cap lands on
	# top of the axle and the fade never reveals the pixels hidden behind it.
	_pending_hint_entries.append({
		"texture": piece.texture,
		"position": target_texture_global_position,
		"size": piece.texture_draw_size(),
	})


func _piece_texture_draw_position(piece: WorkshopPiece) -> Vector2:
	return piece.texture_draw_position()


func _debug_mode_enabled() -> bool:
	var settings := get_node_or_null("/root/GameState")
	return settings != null and settings.debug_mode_enabled


## Debug (number-4 give-items): rebuild the ingredients tray from the current
## inventory so newly granted items become available without reloading the scene.
## Only ever called from the key press, never polled.
func debug_recalibrate() -> void:
	_populate_ingredients_tray()
	_refresh_craft_button()


func _enter_held() -> bool:
	return Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER)


## Debug speedrun: advance the craft flow one step per frame while Enter is
## held so the player never has to release Enter. Order mirrors the manual
## flow: drop the recipe ingredients into the bin, CRAFT, auto-assemble the
## spawned segments (the same routine the debug "6" key runs), then COLLECT.
## Only runs while a drag isn't in progress so it never fights the player.
func _auto_progress_with_enter() -> void:
	if _active_drag_segment != null or _active_drag_piece != null:
		return
	if not _crafted:
		if _matching_recipe_part_id() == "":
			_auto_place_recipe_ingredients()
			return
		if not craft_button.disabled:
			_on_craft_pressed()
		return
	if collect_button.disabled:
		_auto_assemble_craft_bin_segments()
		return
	if collect_button.visible and not collect_button.disabled:
		_on_collect_pressed()


## Move enough of each recipe ingredient from the tray into the craft bin to
## satisfy the forced recipe (the intro head). No forced part -> no-op, so
## non-intro workshops are left for the player to fill by hand.
func _auto_place_recipe_ingredients() -> void:
	var recipe := _forced_recipe()
	if recipe.is_empty():
		return
	var counts: Dictionary = craft_bin.count_items()
	for id_key in recipe:
		var id: String = String(id_key)
		var need: int = int(recipe[id_key])
		var have: int = int(counts.get(id, 0))
		while have < need:
			var piece: WorkshopPiece = _take_tray_piece(id)
			if piece == null:
				break
			_drop_piece_in_bin_center(piece)
			have += 1


func _forced_recipe() -> Dictionary:
	if forced_part_id.strip_edges().is_empty():
		return {}
	var data: Dictionary = CRAFTABLE_PARTS.get(forced_part_id, {})
	return data.get("recipe", {})


func _take_tray_piece(id: String) -> WorkshopPiece:
	var slot := ingredients_tray.get_node_or_null("Tray_" + id) as Control
	if slot == null:
		return null
	for child in slot.get_children():
		if child is WorkshopPiece:
			return child as WorkshopPiece
	return null


func _drop_piece_in_bin_center(piece: WorkshopPiece) -> void:
	var parent := piece.get_parent()
	if parent != null:
		parent.remove_child(piece)
	craft_bin.add_child(piece)
	piece.position = craft_bin.local_center() - piece.size * 0.5
	piece.position.x = clamp(piece.position.x, 0, max(0, craft_bin.size.x - piece.size.x))
	piece.position.y = clamp(piece.position.y, 0, max(0, craft_bin.size.y - piece.size.y))
	craft_bin.contents_changed.emit()
	_refresh_tray_counts()


# --- global input pipe ---

func _input(event: InputEvent) -> void:
	var main: Node = get_tree().current_scene
	if main and "transition" in main:
		var tr = main.transition
		if tr and tr.has_method("is_playing") and tr.is_playing():
			return

	if event is InputEventKey:
		var key_event: InputEventKey = event
		if _debug_mode_enabled() and key_event.pressed and not key_event.echo and (key_event.keycode == KEY_6 or key_event.physical_keycode == KEY_6 or key_event.keycode == KEY_KP_6 or key_event.physical_keycode == KEY_KP_6):
			_auto_assemble_craft_bin_segments()
			get_viewport().set_input_as_handled()
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
			get_viewport().set_input_as_handled()
		elif _active_drag_piece:
			_active_drag_piece.update_drag(event.global_position)
			get_viewport().set_input_as_handled()


func _handle_left_press(global_pos: Vector2) -> void:
	if _active_drag_segment or _active_drag_piece:
		get_viewport().set_input_as_handled()
		return

	# The END button must always be clickable so the player can leave the
	# minigame - otherwise lacking a craft recipe can soft-lock them. Route it
	# through the same manual hit-test the other buttons use, and check it first
	# so an overlapping piece can never swallow the click.
	if _hit_button(end_button, global_pos):
		if end_button.disabled:
			UI_SOUND.play_inaccessible_button(self)
		else:
			_on_end_button_pressed()
		get_viewport().set_input_as_handled()
		return

	var seg: WorkshopSegment = _find_topmost_segment_at(global_pos)
	if seg != null:
		_pick_up_segment(seg, global_pos)
		get_viewport().set_input_as_handled()
		return

	var hit: WorkshopPiece = _find_topmost_piece_at(global_pos)
	if hit != null:
		_pick_up_piece(hit, global_pos)
		get_viewport().set_input_as_handled()
		return

	if _hit_button(craft_button, global_pos):
		if craft_button.disabled:
			UI_SOUND.play_inaccessible_button(self)
		else:
			_on_craft_pressed()
		get_viewport().set_input_as_handled()
		return
	if _hit_button(collect_button, global_pos):
		if collect_button.disabled:
			UI_SOUND.play_inaccessible_button(self)
		else:
			_on_collect_pressed()
		get_viewport().set_input_as_handled()
		return


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
			var target: WorkshopAssemblySlot = _best_segment_drop_target(seg, global_pos)
			if target == null:
				all_valid = false
			drops.append([seg, target])

		if all_valid:
			for entry in drops:
				var placing_seg: WorkshopSegment = entry[0]
				var placing_slot: WorkshopAssemblySlot = entry[1]
				_accept_segment_into_slot(placing_seg, placing_slot)
			_refresh_collect_button()
		get_viewport().set_input_as_handled()
		return

	if _active_drag_piece != null:
		_clear_placement_hints()
		var piece: WorkshopPiece = _active_drag_piece
		_active_drag_piece = null
		piece.end_drag()

		if craft_bin.accepts_point(global_pos):
			_drop_into_bin(piece, global_pos)
			get_viewport().set_input_as_handled()
			return

		_return_piece_home_or_discard(piece)
		craft_bin.contents_changed.emit()
		_refresh_tray_counts()
		get_viewport().set_input_as_handled()


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


func _auto_assemble_craft_bin_segments() -> void:
	if _active_drag_segment != null or _active_drag_piece != null:
		return
	if _active_assembly_slot_ids.is_empty():
		return

	var placed_any: bool = true
	while placed_any:
		placed_any = false
		for segment in _craft_bin_segments_in_slot_order():
			var slot: WorkshopAssemblySlot = _auto_assemble_slot_for_segment(segment)
			if slot == null:
				continue
			segment.end_drag()
			_accept_segment_into_slot(segment, slot)
			placed_any = true
	_refresh_collect_button()


func _craft_bin_segments_in_slot_order() -> Array[WorkshopSegment]:
	var segments: Array[WorkshopSegment] = []
	for child in craft_bin.get_children():
		if child is WorkshopSegment and not child.locked and child.visible and child.is_visible_in_tree():
			segments.append(child)
	segments.sort_custom(func(a: WorkshopSegment, b: WorkshopSegment): return _slot_sort_index(a) < _slot_sort_index(b))
	return segments


func _slot_sort_index(segment: WorkshopSegment) -> int:
	var slot: WorkshopAssemblySlot = _slot_for_segment(segment)
	if slot == null:
		return 999999
	var index: int = _active_assembly_slot_ids.find(slot.accepts_segment_id)
	return index if index >= 0 else 999999


func _auto_assemble_slot_for_segment(segment: WorkshopSegment) -> WorkshopAssemblySlot:
	for slot_id in _active_assembly_slot_ids:
		var slot: WorkshopAssemblySlot = _assembly_slots.get(slot_id)
		if slot == null or slot.filled:
			continue
		if not _slot_accepts_segment(slot, segment):
			continue
		if not _head_prerequisites_met(segment.segment_id):
			continue
		return slot
	return null

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
	return _segment_drop_score(segment, slot, release_global_pos) > -1.0e19


func _best_segment_drop_target(segment: WorkshopSegment, release_global_pos: Vector2) -> WorkshopAssemblySlot:
	var best_slot: WorkshopAssemblySlot = null
	var best_score: float = -1.0e20
	for slot_id in _active_assembly_slot_ids:
		var slot: WorkshopAssemblySlot = _assembly_slots.get(slot_id)
		var score: float = _segment_drop_score(segment, slot, release_global_pos)
		if score > best_score:
			best_score = score
			best_slot = slot
	return best_slot


func _segment_drop_score(segment: WorkshopSegment, slot: WorkshopAssemblySlot, release_global_pos: Vector2) -> float:
	if segment == null or slot == null or slot.filled:
		return -1.0e20
	if not _slot_accepts_segment(slot, segment):
		return -1.0e20
	if not _head_prerequisites_met(segment.segment_id):
		return -1.0e20

	var slot_hitbox: Rect2 = slot.get_global_hitbox()
	var segment_hitbox: Rect2 = segment.get_global_hitbox()
	var release_hits_slot: bool = slot_hitbox.has_point(release_global_pos)
	var overlap_area: float = _rect_overlap_area(segment_hitbox, slot_hitbox)
	if not release_hits_slot:
		if _crafted_part_id == "leg":
			return -1.0e20
		if overlap_area <= 0.0:
			return -1.0e20

	var slot_center: Vector2 = slot_hitbox.position + slot_hitbox.size * 0.5
	var score: float = overlap_area - release_global_pos.distance_squared_to(slot_center) * 0.001
	if release_hits_slot:
		score += 1000000.0
	return score


func _segment_overlaps_slot(segment: WorkshopSegment, slot: WorkshopAssemblySlot) -> bool:
	if slot.filled:
		return false
	if not _slot_accepts_segment(slot, segment):
		return false
	return segment.get_global_hitbox().intersects(slot.get_global_hitbox())


func _rect_overlap_area(a: Rect2, b: Rect2) -> float:
	var left: float = maxf(a.position.x, b.position.x)
	var top: float = maxf(a.position.y, b.position.y)
	var right: float = minf(a.end.x, b.end.x)
	var bottom: float = minf(a.end.y, b.end.y)
	if right <= left or bottom <= top:
		return 0.0
	return (right - left) * (bottom - top)


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
	var passengers: Array = _gather_pair_passengers(segment)
	var all_members: Array = [segment]
	for passenger in passengers:
		all_members.append(passenger)
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


## Collects the still-unplaced segments chained to `segment` through their
## slots' paired_with links, so a paired group (an axel and its cap, or the
## toes and their border) is picked up, dragged, and placed as one unit.
func _gather_pair_passengers(segment: WorkshopSegment) -> Array:
	var passengers: Array = []
	var seen: Array = [segment]
	var frontier: Array = [segment]
	while not frontier.is_empty():
		var current: WorkshopSegment = frontier.pop_back()
		for partner in current.pair_partners:
			if not (partner is WorkshopSegment) or not is_instance_valid(partner):
				continue
			if seen.has(partner):
				continue
			seen.append(partner)
			if partner.locked:
				continue
			passengers.append(partner)
			frontier.append(partner)
	return passengers


func _sync_passenger_segments_to_active_drag() -> void:
	if _active_drag_segment == null:
		return
	var master_pos: Vector2 = _active_drag_segment.position
	for passenger in _passenger_segments:
		if passenger is WorkshopSegment and is_instance_valid(passenger):
			passenger.position = master_pos + _passenger_offsets.get(passenger, Vector2.ZERO)


## Ease-in-out glide from the drop point to the settled slot position when a
## segment lands on its assembly goal (crafting-bin drops are handled elsewhere
## and don't get this — they have no settled location).
const SEGMENT_PLACE_DURATION: float = 0.18


func _accept_segment_into_slot(segment: WorkshopSegment, slot: WorkshopAssemblySlot) -> void:
	if segment == null or slot == null:
		return
	_apply_socket_art_for_segment(segment, slot)
	_clear_placed_part_outline(segment, slot)
	# Remember where the piece is at release so we can ease it to its settled spot.
	var from_global: Vector2 = segment.global_position
	slot.accept_segment(segment)
	var target_pos: Vector2 = _placement_offset_for_slot(segment, slot)
	# Re-anchor to the drop location (converted into the slot's space) and tween
	# to the settled offset. Segments carry no per-node scale/rotation here, so
	# only the position needs to glide.
	segment.global_position = from_global
	var tween: Tween = segment.create_tween()
	tween.tween_property(segment, "position", target_pos, SEGMENT_PLACE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _apply_socket_art_for_segment(segment: WorkshopSegment, slot: WorkshopAssemblySlot) -> void:
	if _crafted_part_id != "head":
		return
	if not HEAD_EYE_SEGMENT_IDS.has(segment.segment_id):
		return
	if not HEAD_EYE_SEGMENT_IDS.has(slot.accepts_segment_id):
		return

	var segment_data: Dictionary = _segments.get(slot.accepts_segment_id, {})
	var piece_defs: Array = segment_data.get("pieces", [])
	if piece_defs.is_empty():
		return

	segment.segment_id = slot.accepts_segment_id
	var piece_index: int = 0
	for child in segment.get_children():
		if not _node_is_workshop_piece(child):
			continue
		var piece := child as WorkshopPiece
		if piece == null:
			continue
		var piece_def: Dictionary = piece_defs[mini(piece_index, piece_defs.size() - 1)]
		piece.item_id = StringName(piece_def.get("id", slot.accepts_segment_id))
		piece.segment_id = slot.accepts_segment_id
		piece.texture = piece_def.get("texture")
		piece.outline_texture = piece_def.get("outline")
		piece.shadow_texture = piece_def.get("shadow")
		piece.position = Vector2.ZERO
		if piece.texture != null:
			piece.size = piece.texture.get_size()
		piece.queue_redraw()
		piece_index += 1

	_refit_segment_bounds(segment)


func _refit_segment_bounds(segment: WorkshopSegment) -> void:
	var bounds: Rect2 = Rect2()
	var found_any: bool = false
	for child in segment.get_children():
		if not _node_is_workshop_piece(child):
			continue
		var piece := child as WorkshopPiece
		if piece == null:
			continue
		var tex_rect: Rect2 = _piece_visible_rect(piece)
		if tex_rect.size.x <= 0.0 or tex_rect.size.y <= 0.0:
			continue
		if not found_any:
			bounds = tex_rect
			found_any = true
		else:
			bounds = bounds.merge(tex_rect)

	if not found_any:
		return

	for child in segment.get_children():
		if child is WorkshopPiece:
			var piece := child as WorkshopPiece
			piece.position -= bounds.position
	segment.size = bounds.size
	segment.placement_offset = bounds.position


func _clear_placed_part_outline(segment: WorkshopSegment, slot: WorkshopAssemblySlot) -> void:
	# Unified-outline parts (stomach, chest) keep their outline art after placement
	# — a back layer repaints it behind all bases — so never strip it here. The
	# hand shares the arm art convention: its outlines are pick-up-only hints.
	if _crafted_part_id != "head" and _crafted_part_id != "arm" and _crafted_part_id != "hand":
		return

	for child in segment.get_children():
		if not _node_is_workshop_piece(child):
			continue
		var piece := child as WorkshopPiece
		if piece == null:
			continue
		if piece.persistent_outline:
			continue
		piece.outline_texture = null
		piece.queue_redraw()


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
	if id == "head_segments":
		piece.visual_scale = 1.05
		piece.auto_top_center = true

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


func _refresh_tray_counts(remove_depleted_slots: bool = false) -> void:
	for slot in ingredients_tray.get_children():
		var id: String = String(slot.name).trim_prefix("Tray_")
		var available: int = _available_count(id)
		if remove_depleted_slots and available <= 0:
			slot.visible = false
			ingredients_tray.remove_child(slot)
			slot.queue_free()
			continue
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
	_head_assembly.position = (assembly.size - HEAD_ASSEMBLY_SIZE) * 0.5 + head_assembly_offset
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


func _setup_arm_assembly() -> void:
	_arm_assembly = Control.new()
	_arm_assembly.name = "AssemblyArm"
	_arm_assembly.size = ARM_ASSEMBLY_SIZE
	_arm_assembly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arm_assembly.visible = false

	var content_bounds: Rect2 = Rect2()
	var found_any: bool = false

	for segment_id in ARM_SEGMENT_IDS:
		var tex: Texture2D = _load_arm_layer(segment_id)
		if tex == null:
			push_warning("Workshop: missing arm layer '%s' in %s." % [segment_id, ARM_TEXTURE_DIR])
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
		var placed_callable := Callable(self, "_on_slot_placed")
		if not slot.placed.is_connected(placed_callable):
			slot.placed.connect(placed_callable)
		_arm_assembly.add_child(slot)
		_assembly_slots[segment_id] = slot
		_segments[segment_id] = {
			"pieces": [
				{
					"id": segment_id,
					"texture": tex,
					"outline": _load_arm_outline(segment_id),
					"shadow": null,
				}
			]
		}

	if not found_any:
		content_bounds = Rect2(Vector2.ZERO, ARM_ASSEMBLY_SIZE)
	# Centre the arm's visible art (not the whole 350x350 canvas, whose content
	# sits off-centre) in the assembly area, then apply the editor nudge.
	var content_center: Vector2 = content_bounds.position + content_bounds.size * 0.5
	_arm_assembly.position = assembly.size * 0.5 - content_center + arm_assembly_offset

	assembly.add_child.call_deferred(_arm_assembly)


func _load_arm_layer(segment_id: StringName) -> Texture2D:
	return _load_texture("%s/%s.png" % [ARM_TEXTURE_DIR, segment_id])


func _load_arm_outline(segment_id: StringName) -> Texture2D:
	return _load_texture("%s/%s_outline.png" % [ARM_TEXTURE_DIR, segment_id])


## Builds a procedurally-assembled body part (hand, stomach, chest) from a
## directory of per-segment PNGs, mirroring the arm setup. Each segment is one
## draggable piece
## with its "<id>_outline.png" loaded alongside. When `unified_outline` is true an
## OutlineLayer is inserted behind every slot so placed pieces' outlines render as
## one block behind all the base art (matching the authored Aseprite layering).
func _build_segmented_assembly(
	assembly_name: String,
	texture_dir: String,
	segment_ids: Array[StringName],
	assembly_size: Vector2,
	offset: Vector2,
	unified_outline: bool,
	key_prefix: String,
	out_slot_ids: Array[StringName],
	persistent_outline_ids: Array[StringName] = [],
) -> Control:
	var node := Control.new()
	node.name = assembly_name
	node.size = assembly_size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.visible = false

	if unified_outline:
		var outline_layer := Control.new()
		outline_layer.name = "OutlineLayer"
		outline_layer.size = assembly_size
		outline_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# First child -> drawn behind every slot's base art.
		node.add_child(outline_layer)
		outline_layer.draw.connect(_draw_unified_outline_layer.bind(outline_layer, node))
		_unified_outline_layers.append(outline_layer)

	var content_bounds: Rect2 = Rect2()
	var found_any: bool = false

	for segment_id in segment_ids:
		# Textures load from the bare segment name; the dictionary/slot key is
		# namespaced so shared names (e.g. "neck") don't collide across parts.
		var tex: Texture2D = _load_texture("%s/%s.png" % [texture_dir, segment_id])
		if tex == null:
			push_warning("Workshop: missing %s layer '%s' in %s." % [assembly_name, segment_id, texture_dir])
			continue

		var seg_key: StringName = StringName(key_prefix + String(segment_id)) if key_prefix != "" else segment_id

		var used_rect: Rect2 = _used_rect_for_texture(tex)
		if used_rect.size.x > 0.0 and used_rect.size.y > 0.0:
			if not found_any:
				content_bounds = used_rect
				found_any = true
			else:
				content_bounds = content_bounds.merge(used_rect)

		var slot := WorkshopAssemblySlot.new()
		slot.name = "%sSlot" % String(seg_key).capitalize().replace(" ", "")
		slot.accepts_segment_id = seg_key
		slot.position = Vector2.ZERO
		slot.size = assembly_size
		slot.hitbox_rect = used_rect
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var placed_callable := Callable(self, "_on_slot_placed")
		if not slot.placed.is_connected(placed_callable):
			slot.placed.connect(placed_callable)
		node.add_child(slot)
		_assembly_slots[seg_key] = slot
		out_slot_ids.append(seg_key)
		_segments[seg_key] = {
			"pieces": [
				{
					"id": seg_key,
					"texture": tex,
					"outline": _load_texture("%s/%s_outline.png" % [texture_dir, segment_id]),
					"shadow": null,
					"unified_outline": unified_outline,
					"persistent_outline": persistent_outline_ids.has(segment_id),
				}
			]
		}

	if not found_any:
		content_bounds = Rect2(Vector2.ZERO, assembly_size)
	# Centre the part's visible art (not the whole canvas, whose content may sit
	# off-centre) in the assembly area, then apply the editor nudge.
	var content_center: Vector2 = content_bounds.position + content_bounds.size * 0.5
	node.position = assembly.size * 0.5 - content_center + offset

	assembly.add_child.call_deferred(node)
	return node


## Repaints every placed (locked) unified-outline piece's outline behind all the
## base art. Walks the owning assembly and draws each piece's outline at the
## piece's global transform, so the result matches the authored "all outlines
## below all bases" layering regardless of per-slot nesting.
func _draw_unified_outline_layer(outline_layer: Control, assembly_node: Control) -> void:
	if outline_layer == null or assembly_node == null:
		return
	var inv: Transform2D = outline_layer.get_global_transform().affine_inverse()
	_draw_locked_outlines_recursive(outline_layer, inv, assembly_node)
	outline_layer.draw_set_transform_matrix(Transform2D())


func _draw_locked_outlines_recursive(outline_layer: Control, inv: Transform2D, node: Node) -> void:
	for child in node.get_children():
		if child == outline_layer:
			continue
		if child is WorkshopPiece:
			var piece := child as WorkshopPiece
			if piece.unified_outline and piece.locked and piece.outline_texture != null and piece.is_visible_in_tree():
				outline_layer.draw_set_transform_matrix(inv * piece.get_global_transform())
				outline_layer.draw_texture_rect(
					piece.outline_texture,
					Rect2(
						piece.texture_draw_position(piece.outline_texture),
						piece.texture_draw_size(piece.outline_texture)
					),
					false
				)
		_draw_locked_outlines_recursive(outline_layer, inv, child)


func _queue_unified_outline_redraw() -> void:
	for layer in _unified_outline_layers:
		if layer is Control and is_instance_valid(layer):
			layer.queue_redraw()


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
	if _arm_assembly != null:
		_arm_assembly.visible = part_id == "arm"
	if _hand_assembly != null:
		_hand_assembly.visible = part_id == "hand"
	if _stomach_assembly != null:
		_stomach_assembly.visible = part_id == "stomach"
	if _chest_assembly != null:
		_chest_assembly.visible = part_id == "chest"

	_active_assembly_slot_ids.clear()
	if part_id == "head":
		for id in HEAD_SEGMENT_IDS:
			if _assembly_slots.has(id):
				_active_assembly_slot_ids.append(id)
	elif part_id == "arm":
		for id in ARM_SEGMENT_IDS:
			if _assembly_slots.has(id):
				_active_assembly_slot_ids.append(id)
	elif part_id == "hand":
		_active_assembly_slot_ids.assign(_hand_assembly_slot_ids)
	elif part_id == "stomach":
		_active_assembly_slot_ids.assign(_stomach_assembly_slot_ids)
	elif part_id == "chest":
		_active_assembly_slot_ids.assign(_chest_assembly_slot_ids)
	elif part_id == "leg":
		_active_assembly_slot_ids.assign(_leg_assembly_slot_ids)

	_queue_unified_outline_redraw()


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
	if not forced_part_id.strip_edges().is_empty():
		var forced_data: Dictionary = CRAFTABLE_PARTS.get(forced_part_id, {})
		if forced_data.is_empty():
			return ""
		var forced_recipe: Dictionary = forced_data.get("recipe", {})
		return forced_part_id if _counts_contain_recipe(counts, forced_recipe) else ""
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

	_refresh_tray_counts(true)
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
			piece.visible = false
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

	_enforce_axle_cap_order()
	craft_bin.contents_changed.emit()


## Segments spawn into the bin in a shuffled order, so an "_axel" segment can
## randomly land on top of the cap/joint it pairs with. Godot draws later
## siblings on top, so we push each axel below its paired partner right after
## spawning — the cap then rests on top, matching how it looks while dragged and
## once assembled.
func _enforce_axle_cap_order() -> void:
	var axels: Array[WorkshopSegment] = []
	for child in craft_bin.get_children():
		if child is WorkshopSegment and String(child.segment_id).ends_with("_axel"):
			axels.append(child)
	for axel in axels:
		for partner in axel.pair_partners:
			if not (partner is WorkshopSegment) or not is_instance_valid(partner):
				continue
			if partner.get_parent() != craft_bin:
				continue
			if axel.get_index() > partner.get_index():
				craft_bin.move_child(axel, partner.get_index())


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
	var scale_value: float = max(0.001, piece.visual_scale)
	return Rect2(
		piece.texture_draw_position() + Vector2(used.position) * scale_value,
		Vector2(used.size) * scale_value
	)


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
	piece.persistent_outline = bool(piece_def.get("persistent_outline", false)) \
		or ARM_PERSISTENT_OUTLINE_IDS.has(seg_id)
	piece.unified_outline = bool(piece_def.get("unified_outline", false))

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
	_queue_unified_outline_redraw()
