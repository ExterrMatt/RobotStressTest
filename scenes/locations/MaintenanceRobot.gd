extends Control
## Static maintenance robot.
##
## Mirrors the stress test robot's sprite layering using the maintenance/ art set,
## showing only the body parts the player currently owns (robot part counts and
## cosmetics from GameState). No looping animation - it's a still pose plus a few
## interaction states driven by the host scene:
##   - each leg can swing "out" (its thigh/shin/foot swap to the leg_out art);
##   - with BOTH legs out, the stomach swaps to its crunch art;
##   - a one-shot battery-insert animation, played when a battery is dropped on
##     the pelvis.
##
## Excluded from the resting pose: HUD, bulky / alternate shoulder pads, the plain
## head (head_2 is the shown head), neck smooth-skin, and the shadow. The leg-out,
## stomach-crunch and battery layers exist but start hidden (interaction states).
## The human-skin "smooth" variants are left off (mechanical default look).
##
## Hair: matches the style the robot last wore in the stress test
## (GameState.robot_hair_style); defaults to hair_front_swing when unknown.

const ART := "res://assets/textures/characters/robot/maintenance/"
const BATTERY_SHEET := ART + "animations/legs/battery_insert/battery_insert.png"

## Native robot canvas; all part art is authored at this size, drawn in place.
const CANVAS := Vector2(300, 450)

## Hair-front texture per GameState.robot_hair_style index (0 normal, 1 swing,
## 2 bangs). The maintenance set has no "normal" front, so it falls back to swing.
const HAIR_FRONT_BY_STYLE := {
	0: "head/hair_front_swing.png",
	1: "head/hair_front_swing.png",
	2: "head/hair_front_bangs.png",
}
const HAIR_FRONT_SENTINEL := "__hair_front__"

## Resting layer stack, BACK -> FRONT: [texture-relative-path, inventory gate].
## A layer is only created when its gate passes, so the robot shows exactly what
## the player owns. Interaction-state layers (leg-out, crunch, battery) are added
## separately by rebuild() so this stays the plain "at rest" description.
## Sentinels resolved during rebuild() to the per-side shoulder variant stack.
const SHOULDER_SENTINEL := {"right": "__shoulder_right__", "left": "__shoulder_left__"}

const LAYERS: Array = [
	["head/hair_back.png",           "head"],
	["head/neck.png",                "head"],
	["torso/stomach.png",            "stomach"],
	["torso/chest.png",              "chest"],
	# Arms sit in FRONT of the chest but BEHIND the chest stuff (pepperonis /
	# coconuts / cover). Each arm is followed by its toggleable shoulder variant.
	["arms/right_arm.png",           "arm_right"],
	[SHOULDER_SENTINEL["right"],     "arm_right"],
	["arms/left_arm.png",            "arm_left"],
	[SHOULDER_SENTINEL["left"],      "arm_left"],
	["chest_stuff/pepperonis.png",   "chest"],
	["chest_stuff/big_coconuts.png", "cos_big_coconuts"],
	["chest_stuff/chest_cover.png",  "cos_chest_cover"],
	["head/head_2.png",              "head"],
	[HAIR_FRONT_SENTINEL,            "head"],
	# Legs draw in FRONT of everything - over the stomach / crunch and over the
	# arms (the thighs sit in front of the hands in the lap).
	["legs/right_thigh.png",         "leg_right"],
	["legs/right_shin.png",          "leg_right"],
	["legs/right_foot.png",          "leg_right"],
	["legs/left_thigh.png",          "leg_left"],
	["legs/left_shin.png",           "leg_left"],
	["legs/left_foot.png",           "leg_left"],
]

## The resting leg parts per side, so a whole leg can be hidden when it swings out.
const LEG_PARTS := {
	"left": ["legs/left_thigh.png", "legs/left_shin.png", "legs/left_foot.png"],
	"right": ["legs/right_thigh.png", "legs/right_shin.png", "legs/right_foot.png"],
}
const LEG_OUT_TEX := {"left": "legs/left_leg_out.png", "right": "legs/right_leg_out.png"}

## Per-shoulder appearance variants, cycled by a hover box. Exactly one shows.
const SHOULDER_VARIANTS: Array = ["pad", "smooth", "shoulder"]
const SHOULDER_TEX := {
	"left": {
		"pad": "arms/left_shoulder_pad.png",
		"smooth": "arms/left_smooth_shoulder.png",
		"shoulder": "arms/left_shoulder.png",
	},
	"right": {
		"pad": "arms/right_shoulder_pad.png",
		"smooth": "arms/right_smooth_shoulder.png",
		"shoulder": "arms/right_shoulder.png",
	},
}

## One-shot battery animation timing.
@export var battery_anim_seconds: float = 1.2

@export_group("Leg Out Offset")
## Horizontal spread of the swung-out legs, in canvas pixels (only affects the leg-out
## pose). The two legs mirror: for the LEFT leg, negative moves it left and positive
## moves it right; for the RIGHT leg, negative moves it right and positive moves it left.
## Updates live in-game so you can set and check it.
@export_range(-15, 15, 1) var leg_out_horizontal_offset: int = 0:
	set(value):
		leg_out_horizontal_offset = value
		_apply_leg_out_offsets()
## Vertical offset of the swung-out legs, in canvas pixels. Both legs move together:
## positive moves them up, negative moves them down. Defaults to 2 to match the couple
## of pixels the legs rise during the stomach crunch. Updates live in-game.
@export_range(-15, 15, 1) var leg_out_vertical_offset: int = 2:
	set(value):
		leg_out_vertical_offset = value
		_apply_leg_out_offsets()

## Pixels the out-legs rise while the stomach crunch is active.
const CRUNCH_LEG_LIFT: float = 3.0

var _leg_out := {"left": false, "right": false}
## Active shoulder variant per side (key into SHOULDER_VARIANTS). Default: pad.
var _shoulder_variant := {"left": "pad", "right": "pad"}
## Whether the chest cover is worn (only meaningful when the cosmetic is owned).
var _chest_cover_equipped := true

# Node refs used by the interaction states.
var _leg_part_nodes := {"left": [], "right": []}
var _leg_out_nodes := {"left": null, "right": null}
var _shoulder_nodes := {"left": {}, "right": {}}
var _chest_cover_node: TextureRect = null
var _stomach_node: TextureRect = null
var _stomach_crunch_node: TextureRect = null
## The battery-insert sheet has two 300-wide columns: column 0 (the pelvis/crunch
## part) plays BELOW the legs, column 1 (the battery) plays ABOVE the legs. Both
## columns advance together.
var _battery_below_node: TextureRect = null
var _battery_below_frames: Array[AtlasTexture] = []
var _battery_above_node: TextureRect = null
var _battery_above_frames: Array[AtlasTexture] = []
var _battery_tween: Tween = null

## Alpha threshold that counts a pixel as "part of the robot" for the opaque mask.
const OPAQUE_MASK_THRESHOLD: float = 0.05
## Pixels of forbidden margin grown around visible hair in the opaque mask, so a nanobot's
## small footprint can't bleed onto the hairline. 0 disables the margin.
const HAIR_MASK_MARGIN: int = 2
## Cached CANVAS-sized silhouette mask (white = robot pixel) unioned from the
## currently-visible layers, rebuilt lazily. Effects (e.g. the nanobot spread) sample
## it so they can be clipped to the robot's actual shape. Invalidated whenever the
## visible layers change (rebuild / pose change).
var _opaque_mask: Image = null
var _opaque_mask_dirty: bool = true


func _ready() -> void:
	custom_minimum_size = CANVAS
	rebuild()


## (Re)creates the layer stack from the current inventory. Public so the host can
## refresh if the player's parts change while the scene is open.
func rebuild() -> void:
	_opaque_mask_dirty = true
	for child in get_children():
		child.queue_free()
	_leg_part_nodes = {"left": [], "right": []}
	_leg_out_nodes = {"left": null, "right": null}
	_shoulder_nodes = {"left": {}, "right": {}}
	_chest_cover_node = null
	_stomach_node = null
	_stomach_crunch_node = null
	_battery_below_node = null
	_battery_above_node = null
	_battery_below_frames = []
	_battery_above_frames = []

	for entry in LAYERS:
		var rel: String = entry[0]
		var gate: String = entry[1]
		if not _gate_passes(gate):
			continue
		# Per-side shoulder variant stack (exactly one shown, cycled by a hover box).
		if rel == SHOULDER_SENTINEL["right"]:
			_build_shoulder_variants("right")
			continue
		if rel == SHOULDER_SENTINEL["left"]:
			_build_shoulder_variants("left")
			continue
		if rel == HAIR_FRONT_SENTINEL:
			rel = String(HAIR_FRONT_BY_STYLE.get(_hair_style(), "head/hair_front_swing.png"))
		var node := _add_layer(rel)
		if node == null:
			continue
		# Track the pieces the interaction states need to hide/show.
		if rel in LEG_PARTS["left"]:
			_leg_part_nodes["left"].append(node)
			# Insert this side's leg-out overlay right after its last part.
			if rel == LEG_PARTS["left"][-1]:
				_leg_out_nodes["left"] = _add_layer(LEG_OUT_TEX["left"], false)
		elif rel in LEG_PARTS["right"]:
			_leg_part_nodes["right"].append(node)
			if rel == LEG_PARTS["right"][-1]:
				_leg_out_nodes["right"] = _add_layer(LEG_OUT_TEX["right"], false)
		elif rel == "torso/stomach.png":
			_stomach_node = node
			_stomach_crunch_node = _add_layer("torso/stomach_crunch.png", false)
			# Battery animation column 0 (pelvis/crunch) draws here, BELOW the legs.
			_battery_below_frames = _build_battery_column_frames(0)
			_battery_below_node = _make_battery_node("BatteryInsertBelow", _battery_below_frames)
		elif rel == "chest_stuff/chest_cover.png":
			_chest_cover_node = node

	# Battery animation column 1 (the battery itself) draws last, ABOVE the legs.
	_battery_above_frames = _build_battery_column_frames(1)
	_battery_above_node = _make_battery_node("BatteryInsertAbove", _battery_above_frames)
	refresh_pose()


## Creates the three shoulder-variant layers for one side (hidden; refresh_pose
## reveals the active one), stored so the host's hover box can cycle them.
func _build_shoulder_variants(side: String) -> void:
	_shoulder_nodes[side] = {}
	for variant in SHOULDER_VARIANTS:
		var node := _add_layer(SHOULDER_TEX[side][variant], false)
		if node != null:
			_shoulder_nodes[side][variant] = node


## Adds one full-canvas layer for the given art path (relative to ART). Returns the
## TextureRect, or null if the texture is missing.
func _add_layer(rel: String, visible_now: bool = true) -> TextureRect:
	var path := ART + rel
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var layer := TextureRect.new()
	layer.name = rel.get_file().get_basename()
	layer.texture = tex
	layer.visible = visible_now
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	return layer


## Frames for one 300-wide column of the battery-insert sheet (top-to-bottom).
## Column 0 is the pelvis/crunch part, column 1 is the battery.
func _build_battery_column_frames(col: int) -> Array[AtlasTexture]:
	var out: Array[AtlasTexture] = []
	if _stomach_node == null or not ResourceLoader.exists(BATTERY_SHEET, "Texture2D"):
		return out
	var sheet := load(BATTERY_SHEET) as Texture2D
	if sheet == null:
		return out
	var fw := int(CANVAS.x)
	var fh := int(CANVAS.y)
	if sheet.get_width() < (col + 1) * fw:
		return out  # this column doesn't exist on the sheet
	var rows := int(sheet.get_height() / maxi(1, fh))
	for i in rows:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(col * fw, i * fh, fw, fh)
		out.append(atlas)
	return out


## Creates a hidden full-canvas TextureRect showing the first frame of `frames`,
## appended at the current stacking position. Returns null if there are no frames.
func _make_battery_node(node_name: String, frames: Array[AtlasTexture]) -> TextureRect:
	if frames.is_empty():
		return null
	var n := TextureRect.new()
	n.name = node_name
	n.texture = frames[0]
	n.visible = false
	n.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	n.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(n)
	return n


# --- interaction states ---------------------------------------------------

func has_leg(side: String) -> bool:
	return not _leg_part_nodes.get(side, []).is_empty()


func is_leg_out(side: String) -> bool:
	return bool(_leg_out.get(side, false))


func toggle_leg_out(side: String) -> void:
	set_leg_out(side, not is_leg_out(side))


## Swings one leg out (or back). Out hides that side's thigh/shin/foot and shows
## the leg-out art; with both legs out the stomach swaps to its crunch art.
func set_leg_out(side: String, out: bool) -> void:
	if not _leg_out.has(side) or not has_leg(side):
		return
	_leg_out[side] = out
	refresh_pose()


func refresh_pose() -> void:
	# A pose change (leg swung out, crunch, cover on/off) changes the silhouette.
	_opaque_mask_dirty = true
	for side in ["left", "right"]:
		var out: bool = _leg_out[side] and _leg_out_nodes[side] != null
		for part in _leg_part_nodes[side]:
			if is_instance_valid(part):
				part.visible = not out
		if _leg_out_nodes[side] != null and is_instance_valid(_leg_out_nodes[side]):
			_leg_out_nodes[side].visible = out
	var both_out: bool = is_leg_out("left") and is_leg_out("right") \
		and _leg_out_nodes["left"] != null and _leg_out_nodes["right"] != null
	if _stomach_crunch_node != null and is_instance_valid(_stomach_crunch_node):
		_stomach_crunch_node.visible = both_out
	if _stomach_node != null and is_instance_valid(_stomach_node):
		_stomach_node.visible = not both_out
	# Position the out-legs: the editor spread/vertical offsets plus the small crunch lift.
	_apply_leg_out_offsets()

	# Shoulders: exactly the active variant shows on each side.
	for side in ["left", "right"]:
		var active: String = _shoulder_variant[side]
		for variant in SHOULDER_VARIANTS:
			var sn = _shoulder_nodes[side].get(variant)
			if sn != null and is_instance_valid(sn):
				sn.visible = (variant == active)

	# Chest cover: worn only while equipped (and owned, i.e. the node exists).
	if _chest_cover_node != null and is_instance_valid(_chest_cover_node):
		_chest_cover_node.visible = _chest_cover_equipped


## Positions each swung-out leg node: the editor horizontal spread (mirrored between the
## two legs) and vertical offset, plus the small crunch lift while both legs are out. Safe
## to call any time - it no-ops until the leg-out nodes exist (so the export setters can
## fire during initialization). Drives the live in-game preview of the offset variables.
func _apply_leg_out_offsets() -> void:
	if typeof(_leg_out_nodes) != TYPE_DICTIONARY or typeof(_leg_out) != TYPE_DICTIONARY:
		return
	var both_out: bool = is_leg_out("left") and is_leg_out("right") \
		and _leg_out_nodes["left"] != null and _leg_out_nodes["right"] != null
	var crunch_lift: float = -CRUNCH_LEG_LIFT if both_out else 0.0
	# offset_top/bottom are positive-down, so negate the variable: positive lifts up.
	var vertical := crunch_lift - float(leg_out_vertical_offset)
	for side in ["left", "right"]:
		var out_node = _leg_out_nodes.get(side)
		if out_node == null or not is_instance_valid(out_node):
			continue
		# Left leg: +offset moves right. Right leg mirrors: +offset moves left.
		var horizontal := float(leg_out_horizontal_offset)
		if side == "right":
			horizontal = -horizontal
		out_node.offset_left = horizontal
		out_node.offset_right = horizontal
		out_node.offset_top = vertical
		out_node.offset_bottom = vertical


# --- shoulders / chest cover ---------------------------------------------

func has_shoulder(side: String) -> bool:
	return not _shoulder_nodes.get(side, {}).is_empty()


## Advances one shoulder to the next appearance variant (pad -> smooth -> shoulder).
func cycle_shoulder(side: String) -> void:
	if not has_shoulder(side):
		return
	var i: int = SHOULDER_VARIANTS.find(_shoulder_variant[side])
	_shoulder_variant[side] = SHOULDER_VARIANTS[(i + 1) % SHOULDER_VARIANTS.size()]
	refresh_pose()


func has_chest_cover() -> bool:
	return _chest_cover_node != null and is_instance_valid(_chest_cover_node)


## Equips / unequips the chest cover (only does anything when the cosmetic is owned).
func toggle_chest_cover() -> void:
	if not has_chest_cover():
		return
	_chest_cover_equipped = not _chest_cover_equipped
	refresh_pose()


func can_play_battery_animation() -> bool:
	return not _battery_below_frames.is_empty() or not _battery_above_frames.is_empty()


## Plays the battery-insert animation once (both columns in sync), then hides it.
func play_battery_animation() -> void:
	if not can_play_battery_animation():
		return
	if _battery_tween != null and _battery_tween.is_valid():
		_battery_tween.kill()
	var frame_count := maxi(_battery_below_frames.size(), _battery_above_frames.size())
	if frame_count <= 0:
		return
	_show_battery_node(_battery_below_node, _battery_below_frames, 0)
	_show_battery_node(_battery_above_node, _battery_above_frames, 0)
	_battery_tween = create_tween()
	_battery_tween.tween_method(_set_battery_frame, 0.0, float(frame_count - 1),
		maxf(0.05, battery_anim_seconds))
	_battery_tween.tween_callback(func() -> void:
		if _battery_below_node != null and is_instance_valid(_battery_below_node):
			_battery_below_node.visible = false
		if _battery_above_node != null and is_instance_valid(_battery_above_node):
			_battery_above_node.visible = false
	)


func _show_battery_node(node: TextureRect, frames: Array[AtlasTexture], frame: int) -> void:
	if node == null or not is_instance_valid(node) or frames.is_empty():
		return
	node.texture = frames[clampi(frame, 0, frames.size() - 1)]
	node.visible = true


func _set_battery_frame(value: float) -> void:
	var i := int(round(value))
	if _battery_below_node != null and is_instance_valid(_battery_below_node) and not _battery_below_frames.is_empty():
		_battery_below_node.texture = _battery_below_frames[clampi(i, 0, _battery_below_frames.size() - 1)]
	if _battery_above_node != null and is_instance_valid(_battery_above_node) and not _battery_above_frames.is_empty():
		_battery_above_node.texture = _battery_above_frames[clampi(i, 0, _battery_above_frames.size() - 1)]


# --- hit rects (robot-local, for the host to place hover boxes) -----------

## Opaque bounding rect (in this Control's local space) of one side's resting leg
## parts, or an empty rect if that leg isn't shown.
func leg_rect(side: String) -> Rect2:
	return _opaque_rect_for(LEG_PARTS.get(side, []))


## Opaque bounding rect of the stomach/pelvis art, for the battery drop target.
func pelvis_rect() -> Rect2:
	return _opaque_rect_for(["torso/stomach.png"])


## Opaque bounding rect covering one shoulder's variants, for its cycle hover box.
func shoulder_rect(side: String) -> Rect2:
	var variants: Dictionary = SHOULDER_TEX.get(side, {})
	return _opaque_rect_for(variants.values())


## Opaque bounding rect of the chest cover, for its equip/unequip hover box.
func chest_cover_rect() -> Rect2:
	return _opaque_rect_for(["chest_stuff/chest_cover.png"])


## Unions the opaque pixel bounds of the given art paths, scaled from the native
## canvas into this Control's current size.
func _opaque_rect_for(rels: Array) -> Rect2:
	var bounds := Rect2()
	var found := false
	var sx := size.x / CANVAS.x
	var sy := size.y / CANVAS.y
	for rel in rels:
		var path := ART + String(rel)
		if not ResourceLoader.exists(path, "Texture2D"):
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			continue
		var img := tex.get_image()
		if img == null:
			continue
		var used := img.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var mapped := Rect2(
			Vector2(used.position.x * sx, used.position.y * sy),
			Vector2(used.size.x * sx, used.size.y * sy)
		)
		if not found:
			bounds = mapped
			found = true
		else:
			bounds = bounds.merge(mapped)
	return bounds


# --- silhouette mask (for effects clipped to the robot's shape) -----------

## The native art canvas size (all layer art is authored at this resolution). The
## opaque mask is this size; sample it with a point scaled from local space by
## get_size() / CANVAS.
func art_canvas_size() -> Vector2:
	return CANVAS


## A CANVAS-sized silhouette mask (white where any currently-visible layer is opaque),
## built lazily and cached until the visible layers change. Effects sample it to stay
## inside the robot's shape. Returns null only if there is nothing to draw.
func get_opaque_mask() -> Image:
	if _opaque_mask_dirty or _opaque_mask == null:
		_opaque_mask = _build_opaque_mask()
		_opaque_mask_dirty = false
	return _opaque_mask


func _build_opaque_mask() -> Image:
	var w := int(CANVAS.x)
	var h := int(CANVAS.y)
	# Work on raw byte buffers instead of per-pixel get_pixel/set_pixel (which alloc a Color
	# and do a call each), so this stays cheap even over every layer of the full canvas.
	var mask_bytes := PackedByteArray()
	mask_bytes.resize(w * h)  # L8, zero-filled = fully transparent
	# Where any hair layer (front or back) is opaque - used in pass 3 to grow a forbidden
	# margin around the hair that actually shows.
	var hair_bytes := PackedByteArray()
	hair_bytes.resize(w * h)
	# Pass 1: mark every NON-hair robot layer as robot (255). Hair is left out entirely, so
	# hair that shows on its own - the exposed back-hair fluff - stays forbidden, while the
	# bald head (head_2) drawn over the back hair keeps the face allowed. Hair coverage is
	# recorded separately in hair_bytes.
	for child in get_children():
		if not (child is TextureRect):
			continue
		var tr := child as TextureRect
		if not tr.visible or tr.name == "Shadow" or tr.texture == null:
			continue
		if _is_hair_layer(tr.name):
			hair_bytes = _stamp_layer_alpha(tr, hair_bytes, w, h, 1)
			continue
		mask_bytes = _stamp_layer_alpha(tr, mask_bytes, w, h, 255)
	# Pass 2: carve out the FRONT hair (bangs). It draws OVER the face, so a nanobot there
	# would sit on the hair - forbid it. The back hair needs no cut (it was never added).
	for child in get_children():
		if not (child is TextureRect):
			continue
		var tr := child as TextureRect
		if not tr.visible or tr.texture == null or not _is_front_hair_layer(tr.name):
			continue
		mask_bytes = _stamp_layer_alpha(tr, mask_bytes, w, h, 0)
	# Pass 3: grow a forbidden margin around VISIBLE hair so a nanobot's small footprint
	# can't bleed a pixel onto the hairline. Hair hidden under the bald head stays allowed.
	if HAIR_MASK_MARGIN > 0:
		mask_bytes = _grow_hair_margin(mask_bytes, hair_bytes, w, h)
	return Image.create_from_data(w, h, false, Image.FORMAT_L8, mask_bytes)


## Forbids (0) every pixel within HAIR_MASK_MARGIN of a *visible* hair pixel. Visible hair =
## a pixel where a hair layer is opaque (hair_bytes) AND the built mask is already forbidden
## there (mask 0) - i.e. the hair shows rather than being covered by the face/head. Seeds are
## read from the input and the margin is written to a copy, so a grown pixel never seeds more
## growth: the forbidden band is exactly HAIR_MASK_MARGIN wide, never a runaway flood.
func _grow_hair_margin(mask_bytes: PackedByteArray, hair_bytes: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var out := mask_bytes.duplicate()
	var m := HAIR_MASK_MARGIN
	for y in h:
		var row := y * w
		for x in w:
			var idx := row + x
			# Seed only on visible hair (hair here, and not covered by a later opaque layer).
			if hair_bytes[idx] == 0 or mask_bytes[idx] != 0:
				continue
			var x0 := maxi(0, x - m)
			var x1 := mini(w - 1, x + m)
			var y0 := maxi(0, y - m)
			var y1 := mini(h - 1, y + m)
			for yy in range(y0, y1 + 1):
				var orow := yy * w
				for xx in range(x0, x1 + 1):
					out[orow + xx] = 0
	return out


## Any hair layer (front bangs or the back fluff) - kept out of the robot silhouette so
## nanobots stay off the hair. Layer nodes are named after their art file's basename.
func _is_hair_layer(layer_name: String) -> bool:
	return layer_name.to_lower().begins_with("hair")


## Only the front hair (e.g. "hair_front_swing" / "hair_front_bangs"), which draws over the
## face and so must be cut back out of the mask.
func _is_front_hair_layer(layer_name: String) -> bool:
	return layer_name.to_lower().begins_with("hair_front")


## Writes `value` (255 = robot, 0 = forbidden) into the mask at every pixel where this
## layer's art is opaque, scaling from the layer's art into the CANVAS-sized mask. Returns
## the updated buffer (PackedByteArray is copy-on-write, so it must be passed back).
func _stamp_layer_alpha(tr: TextureRect, mask_bytes: PackedByteArray, w: int, h: int, value: int) -> PackedByteArray:
	var img := tr.texture.get_image()
	if img == null:
		return mask_bytes
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)  # 4 bytes/pixel, alpha at byte offset 3
	var iw := img.get_width()
	var ih := img.get_height()
	if iw <= 0 or ih <= 0:
		return mask_bytes
	var data := img.get_data()
	var threshold_byte := int(OPAQUE_MASK_THRESHOLD * 255.0)
	var same_size := iw == w and ih == h
	for y in h:
		var sy := y if same_size else clampi(int(float(y) * ih / h), 0, ih - 1)
		var src_row := sy * iw
		var mask_row := y * w
		for x in w:
			var sx := x if same_size else clampi(int(float(x) * iw / w), 0, iw - 1)
			if data[(src_row + sx) * 4 + 3] > threshold_byte:
				mask_bytes[mask_row + x] = value
	return mask_bytes


# --- inventory ------------------------------------------------------------

func _gate_passes(gate: String) -> bool:
	match gate:
		"":
			return true
		"head":
			return _part_count("head") >= 1
		"chest":
			return _part_count("chest") >= 1
		"stomach":
			return _part_count("stomach") >= 1
		"arm_left":
			return _part_count("arm") >= 1
		"arm_right":
			return _part_count("arm") >= 2
		"leg_left":
			return _part_count("leg") >= 1
		"leg_right":
			return _part_count("leg") >= 2
		"cos_big_coconuts":
			return _has_cosmetic("big_coconuts")
		"cos_chest_cover":
			return _has_cosmetic("big_chest_cover")
	return false


func _part_count(id: String) -> int:
	if Engine.is_editor_hint():
		return 2
	var state := get_node_or_null("/root/GameState")
	if state != null and state.has_method("get_robot_part_count"):
		return int(state.call("get_robot_part_count", id))
	return 0


func _has_cosmetic(id: String) -> bool:
	if Engine.is_editor_hint():
		return false
	var state := get_node_or_null("/root/GameState")
	if state != null and state.has_method("has_cosmetic_item"):
		return bool(state.call("has_cosmetic_item", id))
	return false


func _hair_style() -> int:
	var state := get_node_or_null("/root/GameState")
	if state != null:
		return int(state.get("robot_hair_style"))
	return 1
