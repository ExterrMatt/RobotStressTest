extends Control
## Static maintenance robot.
##
## Mirrors the stress test robot's sprite layering using the maintenance/ art set,
## showing only the body parts she's wearing (GameState.equipped_parts, never the
## inventory) and the cosmetics owned. No looping animation - it's a still pose plus a few
## interaction states driven by the host scene:
##   - each leg can swing "out" (its thigh/shin/foot swap to the leg_out art);
##   - with BOTH legs out, the stomach swaps to its crunch art;
##   - a one-shot battery-insert animation, played when a battery is dropped on
##     the pelvis.
##
## Two poses: she SITS upright only with both thighs on (the rest of each leg is
## optional); otherwise she can't hold herself up and LEANS back (the sheet's *_lean
## layers - head, arms, chest, stomach). Both poses share the same leg art. The legs
## only swing out while she sits.
##
## Excluded: HUD and the shadow. The leg-out, stomach-crunch and battery layers exist
## but start hidden (interaction states). The look - shoulder style, smooth skin,
## coconut size, open eyes and eye tracking - is set from the Shift+Tab debug menu
## (debug_cycle_setting); the lean pose has no art for the shoulders, smooth skin or
## open eyes, and wears the medium coconuts whatever the size.
##
## Hair: matches the style the robot last wore in the stress test
## (GameState.robot_hair_style); defaults to hair_front_swing when unknown.
##
## All part art comes from one packed Aseprite sheet (Split Layers + Trim Cels); each
## entry below is an Aseprite layer name, rebuilt as its own full-canvas texture by
## PackedSpriteSheet.layer_textures().

const ART := "res://assets/textures/characters/robot/maintenance/"
const BATTERY_SHEET := ART + "animations/legs/battery_insert/battery_insert.png"
const SHEET_PATH := "res://assets/textures/icons/personality_test_bot.png"
const SHEET_JSON_PATH := "res://assets/textures/icons/personality_test_bot.json"

## Native robot canvas; all part art is authored at this size, drawn in place.
const CANVAS := Vector2(300, 450)

## Hair-front layer per GameState.robot_hair_style index (0 normal, 1 swing,
## 2 bangs). The maintenance set has no "normal" front, so it falls back to swing.
const HAIR_FRONT_BY_STYLE := {
	0: "hair_front_swing",
	1: "hair_front_swing",
	2: "hair_front_bangs",
}
const HAIR_FRONT_SENTINEL := "__hair_front__"

## Resting layer stack, BACK -> FRONT: [sheet layer name, equipped gate].
## A layer is only created when its gate passes, so the robot shows exactly what
## she's wearing. Interaction-state layers (leg-out, crunch, battery) are added
## separately by rebuild() so this stays the plain "at rest" description.
## Sentinels resolved during rebuild() to the per-side shoulder variant stack.
const SHOULDER_SENTINEL := {"right": "__shoulder_right__", "left": "__shoulder_left__"}
## The arm art has the hand drawn on, but the hand is its own part - so each arm is split
## at its wrist into the arm and a hand layer that only shows while that hand is on her
## (and so goes when it comes off). WRIST_ROW is the hand's first row on the canvas.
const HAND_SENTINEL := {"right": "__hand_right__", "left": "__hand_left__"}
const ARM_TEX := {"left": "left_arm", "right": "right_arm"}
const WRIST_ROW := {"left": 238, "right": 238}
## An arm built piece by piece shows its upper arm (with the elbow joint) and forearm
## separately, split here: the forearm's first row on the canvas.
const ELBOW_ROW := {"left": 203, "right": 203}

## The sheet draws the chest stuff in small / medium / big sizes. Coconuts (and their
## pepperonis) show while she owns big or small coconuts, at the size the "Coconuts"
## setting picks; "auto" is small for the small coconuts, else medium (the size the
## robot has always shown). Small has no cover of its own, so it wears the medium one.
## Without coconuts the chest shows its empty sockets.
const STOMACH_LAYER := "stomach"
const COCONUT_SIZES: Array = ["auto", "small", "medium", "big"]
const CHEST_COVER_BY_SIZE := {
	"small": "medium_chest_cover",
	"medium": "medium_chest_cover",
	"big": "big_chest_cover",
}
const COCONUTS_SENTINEL := "__coconuts__"
const PEPPERONIS_SENTINEL := "__pepperonis__"
const CHEST_COVER_SENTINEL := "__chest_cover__"
## The big coconuts' panel lines - the mechanical look, so they go under the smooth skin.
const COCO_LINES_LAYER := "big_coco_lines"
## Smooth skin over the neck and upper chest (and its own back hair).
const SMOOTH_SKIN_LAYER := "neck_smoothskin"

## Open eyes over the closed ones, with one iris layer showing where she looks.
const OPEN_EYES_LAYER := "open_eyes"
const IRIS_SENTINEL := "__iris__"
const IRIS_LAYERS: Array = [
	"iris_forward",
	"iris_forward_left_1", "iris_forward_left_2",
	"iris_forward_right_1", "iris_forward_right_2",
	"iris_up", "iris_down_1", "iris_down_2",
]
## Where her eyes are on the canvas, and how far (canvas pixels) the mouse must be from
## them to turn the eyes a step (inside EYE_DEAD_ZONE she looks forward) and the further
## step (past EYE_FAR_DISTANCE). Vertical wins once it's EYE_VERTICAL_BIAS times the
## horizontal distance.
const EYE_CENTER := Vector2(151, 108)
const EYE_DEAD_ZONE: float = 24.0
const EYE_FAR_DISTANCE: float = 90.0
const EYE_VERTICAL_BIAS: float = 1.3

## Sitting pose stack, BACK -> FRONT.
const LAYERS: Array = [
	["hair_back",                "head"],
	["neck",                     "head"],
	[STOMACH_LAYER,              "stomach"],
	["chest",                    "chest"],
	["chest_holes",              "no_coconuts"],
	# Arms sit in FRONT of the chest but BEHIND the chest stuff (pepperonis /
	# coconuts / cover). Each arm is followed by its toggleable shoulder variant.
	["right_arm",                "arm_right"],
	[HAND_SENTINEL["right"],     "hand_right"],
	[SHOULDER_SENTINEL["right"], "arm_right"],
	["left_arm",                 "arm_left"],
	[HAND_SENTINEL["left"],      "hand_left"],
	[SHOULDER_SENTINEL["left"],  "arm_left"],
	[COCONUTS_SENTINEL,          "coconuts"],
	[COCO_LINES_LAYER,           "coco_lines"],
	[PEPPERONIS_SENTINEL,        "coconuts"],
	[SMOOTH_SKIN_LAYER,          "smooth_skin"],
	[CHEST_COVER_SENTINEL,       "cos_chest_cover"],
	["head",                     "head"],
	[OPEN_EYES_LAYER,            "eyes"],
	[IRIS_SENTINEL,              "eyes"],
	[HAIR_FRONT_SENTINEL,        "head"],
	# Legs draw in FRONT of everything - over the stomach / crunch and over the
	# arms (the thighs sit in front of the hands in the lap).
	["right_thigh",              "leg_right"],
	["right_shin",               "leg_right"],
	["right_foot",               "leg_right"],
	["left_thigh",               "leg_left"],
	["left_shin",                "leg_left"],
	["left_foot",                "leg_left"],
]

## Each side's arm in the lean pose, drawn as its own pieces (the hand only while that
## hand is on her).
const LEAN_ARM_SENTINEL := {"right": "__lean_arm_right__", "left": "__lean_arm_left__"}
const LEAN_ARM_TEX := {
	"right": {"upper_arm": "right_arm_lean", "forearm": "right_forearm_lean", "hand": "right_hand_lean"},
	"left": {"upper_arm": "left_upper_arm_lean", "forearm": "left_forearm_lean", "hand": "left_hand_lean"},
}
const LEAN_STOMACH_LAYER := "stomach_lean"
const LEAN_CHEST_COVER_LAYER := "chest_cover_lean"

## Leaning pose stack, BACK -> FRONT: she's tipped back, so her head (hair and neck drawn
## on) goes behind the chest, and the stomach in front of it.
const LEAN_LAYERS: Array = [
	["head_lean",                    "head"],
	[LEAN_ARM_SENTINEL["right"],     "arm_right"],
	[LEAN_ARM_SENTINEL["left"],      "arm_left"],
	["chest_lean",                   "chest"],
	["medium_coconuts_lean",         "coconuts"],
	[LEAN_CHEST_COVER_LAYER,         "cos_chest_cover"],
	[LEAN_STOMACH_LAYER,             "stomach"],
	["right_thigh",                  "leg_right"],
	["right_shin",                   "leg_right"],
	["right_foot",                   "leg_right"],
	["left_thigh",                   "leg_left"],
	["left_shin",                    "leg_left"],
	["left_foot",                    "leg_left"],
]

## The resting leg parts per side, so a whole leg can be hidden when it swings out.
const LEG_PARTS := {
	"left": ["left_thigh", "left_shin", "left_foot"],
	"right": ["right_thigh", "right_shin", "right_foot"],
}
## Each leg part's swung-out art is its own sheet layer, the part's name plus this
## ("left_thigh_out"), so a leg built only partway still swings out with what it has.
const LEG_OUT_SUFFIX := "_out"

## Per-shoulder appearance variants, cycled by a hover box (or both at once from the
## Shift+Tab "Shoulders" setting). Exactly one shows.
const SHOULDER_VARIANTS: Array = ["pad", "bulky", "alternate", "smooth", "shoulder"]
const SHOULDER_VARIANT_NAMES := {
	"pad": "Pads", "bulky": "Bulky Pads", "alternate": "Alt Pads", "smooth": "Smooth", "shoulder": "Bare",
}
## The alternate pads are one layer for both shoulders, split down this column into each
## side's half so a pad only shows on an arm she has.
const ALT_PADS_LAYER := "alternate_shouder_pads"
const ALT_PADS_SPLIT_COLUMN: int = 151
const SHOULDER_TEX := {
	"left": {
		"pad": "left_shoulder_pad",
		"bulky": "left_shoulder_pad_bulky",
		"smooth": "left_smooth_shoulder",
		"shoulder": "left_shoulder",
	},
	"right": {
		"pad": "right_shoulder_pad",
		"bulky": "right_shoulder_pad_bulky",
		"smooth": "right_smooth_shoulder",
		"shoulder": "right_shoulder",
	},
}
## The variants a shoulder's hover box is sized from - the bulky pads' art reaches far
## down the arm, which would put the box over her legs.
const SHOULDER_HIT_VARIANTS: Array = ["pad", "smooth", "shoulder"]

## The robot's look, set from the Shift+Tab debug menu (debug_cycle_setting). Static so a
## pick holds for the whole session, across visits to the scene.
const DEBUG_SETTINGS: Array = ["shoulders", "smooth_skin", "coconuts", "open_eyes", "eye_tracking"]
static var shoulder_style: String = "pad"
static var smooth_skin: bool = false
static var coconut_size: String = "auto"
static var open_eyes: bool = false
static var eye_tracking: bool = false

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
## Sitting upright (both thighs on) rather than leaning back. Set by rebuild().
var _sitting := true
## Active shoulder variant per side (key into SHOULDER_VARIANTS). Starts at the
## "Shoulders" setting.
var _shoulder_variant := {"left": shoulder_style, "right": shoulder_style}
## Whether the chest cover is worn (only meaningful when the cosmetic is owned).
var _chest_cover_equipped := true

# Node refs used by the interaction states.
var _leg_part_nodes := {"left": [], "right": []}
## The leg parts shown per side (LEG_PARTS names) - all three for a whole leg, fewer
## for one being built - and each one's swung-out layer.
var _leg_part_names := {"left": [], "right": []}
var _leg_out_nodes := {"left": [], "right": []}
var _shoulder_nodes := {"left": {}, "right": {}}
var _chest_cover_node: TextureRect = null
## The chest overlays the cover isn't shaped for, hidden while it's worn (as the stress
## test robot does): sitting, the cover is contoured to the coconuts so only the
## pepperonis go; leaning, the one flat lean cover hides the coconuts too.
var _under_cover_nodes: Array[TextureRect] = []
var _stomach_node: TextureRect = null
var _stomach_crunch_node: TextureRect = null
## Iris layer name -> node (all hidden but the one she looks with), and the one showing.
var _iris_nodes := {}
var _iris_shown := ""
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


## (Re)creates the layer stack from what she's wearing. Public so the host can
## refresh if the player's parts change while the scene is open.
func rebuild() -> void:
	_opaque_mask_dirty = true
	for child in get_children():
		child.queue_free()
	_leg_part_nodes = {"left": [], "right": []}
	_leg_part_names = {"left": [], "right": []}
	_leg_out_nodes = {"left": [], "right": []}
	_shoulder_nodes = {"left": {}, "right": {}}
	_chest_cover_node = null
	_under_cover_nodes = []
	_stomach_node = null
	_stomach_crunch_node = null
	_battery_below_node = null
	_battery_above_node = null
	_battery_below_frames = []
	_battery_above_frames = []
	_iris_nodes = {}
	_iris_shown = ""

	_sitting = _thigh_on("left") and _thigh_on("right")
	for entry in (LAYERS if _sitting else LEAN_LAYERS):
		var rel: String = entry[0]
		var gate: String = entry[1]
		if not _gate_passes(gate):
			_add_part_built_layer(rel, gate)
			continue
		if rel == LEAN_ARM_SENTINEL["right"] or rel == LEAN_ARM_SENTINEL["left"]:
			var lean_side := "right" if rel == LEAN_ARM_SENTINEL["right"] else "left"
			_add_lean_arm(lean_side, ["upper_arm", "forearm"])
			continue
		if rel == IRIS_SENTINEL:
			for iris in IRIS_LAYERS:
				var iris_node := _add_layer(iris, false)
				if iris_node != null:
					_iris_nodes[iris] = iris_node
			_update_eye_direction()
			continue
		match rel:
			COCONUTS_SENTINEL:
				rel = "%s_coconuts" % _coconut_size()
			PEPPERONIS_SENTINEL:
				rel = "%s_pepperonis" % _coconut_size()
			CHEST_COVER_SENTINEL:
				rel = String(CHEST_COVER_BY_SIZE[_coconut_size()])
		# Per-side shoulder variant stack (exactly one shown, cycled by a hover box).
		if rel == SHOULDER_SENTINEL["right"]:
			_build_shoulder_variants("right")
			continue
		if rel == SHOULDER_SENTINEL["left"]:
			_build_shoulder_variants("left")
			continue
		if rel == HAIR_FRONT_SENTINEL:
			rel = String(HAIR_FRONT_BY_STYLE.get(_hair_style(), "hair_front_swing"))
		# The arms are drawn without their hands; each hand is its own layer.
		if rel == HAND_SENTINEL["right"] or rel == HAND_SENTINEL["left"]:
			var hand_side := "right" if rel == HAND_SENTINEL["right"] else "left"
			_add_texture_layer(_arm_piece(hand_side, "hand"), "%s_hand" % hand_side)
			continue
		if rel == ARM_TEX["right"] or rel == ARM_TEX["left"]:
			var arm_side := "right" if rel == ARM_TEX["right"] else "left"
			_add_texture_layer(_arm_piece(arm_side, "arm"), "%s_arm" % arm_side)
			continue
		if rel in LEG_PARTS["left"] or rel in LEG_PARTS["right"]:
			_add_leg_part(rel)
			continue
		var node := _add_layer(rel)
		if node == null:
			continue
		# Track the pieces the interaction states need to hide/show.
		if rel == STOMACH_LAYER:
			_stomach_node = node
			_stomach_crunch_node = _add_layer("stomach_crunch", false)
			# Battery animation column 0 (pelvis/crunch) draws here, BELOW the legs.
			_battery_below_frames = _build_battery_column_frames(0)
			_battery_below_node = _make_battery_node("BatteryInsertBelow", _battery_below_frames)
		elif gate == "cos_chest_cover":
			_chest_cover_node = node
		elif gate == "coconuts" and (not _sitting or rel.ends_with("_pepperonis")):
			_under_cover_nodes.append(node)

	# Battery animation column 1 (the battery itself) draws last, ABOVE the legs.
	_battery_above_frames = _build_battery_column_frames(1)
	_battery_above_node = _make_battery_node("BatteryInsertAbove", _battery_above_frames)
	# A leg that came off (or never got a thigh), or any leg once she leans, can't stay
	# swung out.
	for side in ["left", "right"]:
		if not can_leg_out(side):
			_leg_out[side] = false
	refresh_pose()
	set_process(eye_tracking and not _iris_nodes.is_empty())


## Whether `side`'s thigh is on her (whole leg or part-built) - both are what let her sit.
func _thigh_on(side: String) -> bool:
	if _gate_passes("leg_" + side):
		return true
	var state := get_node_or_null("/root/GameState")
	if state == null or not state.has_method("get_limb_segments"):
		return false
	return (state.call("get_limb_segments", "leg", side) as Array).has("thigh")


## Adds the lean-pose layers for the given pieces of `side`'s arm (upper_arm / forearm),
## then its hand if that hand is on her.
func _add_lean_arm(side: String, pieces: Array) -> void:
	for piece in pieces:
		var layer: String = LEAN_ARM_TEX[side][piece]
		_add_layer(layer)
	if _gate_passes("hand_" + side):
		_add_layer(String(LEAN_ARM_TEX[side]["hand"]))


## The coconut size to draw, resolving "auto" from what she owns.
func _coconut_size() -> String:
	if coconut_size != "auto":
		return coconut_size
	if _has_cosmetic("small_coconuts") and not _has_cosmetic("big_coconuts"):
		return "small"
	return "medium"


## Whether she wears coconuts (owns the big or the small ones).
func _wears_coconuts() -> bool:
	return _has_cosmetic("big_coconuts") or _has_cosmetic("small_coconuts")


## The chest cover's layer in the current pose (and coconut size).
func _chest_cover_layer() -> String:
	return String(CHEST_COVER_BY_SIZE[_coconut_size()]) if _sitting else LEAN_CHEST_COVER_LAYER


## Adds a leg part (whole leg or part-built) and, right after it, its hidden swung-out
## layer, tracked so the leg-out pose can swap one for the other.
func _add_leg_part(rel: String) -> void:
	var side := "left" if rel in LEG_PARTS["left"] else "right"
	var node := _add_layer(rel)
	if node == null:
		return
	_leg_part_nodes[side].append(node)
	_leg_part_names[side].append(rel)
	var out_node := _add_layer(rel + LEG_OUT_SUFFIX, false)
	if out_node != null:
		_leg_out_nodes[side].append(out_node)


## Creates the three shoulder-variant layers for one side (hidden; refresh_pose
## reveals the active one), stored so the host's hover box can cycle them.
func _build_shoulder_variants(side: String) -> void:
	_shoulder_nodes[side] = {}
	for variant in SHOULDER_VARIANTS:
		var node := _add_texture_layer(_shoulder_texture(side, variant), "%s_shoulder_%s" % [side, variant], false)
		if node != null:
			_shoulder_nodes[side][variant] = node


## One side's shoulder art for `variant`; the alternate pads are cut to that side's half.
func _shoulder_texture(side: String, variant: String) -> Texture2D:
	if variant != "alternate":
		return _layer_texture(String(SHOULDER_TEX[side].get(variant, SHOULDER_TEX[side]["pad"])))
	var key := "%s_alt_pad" % side
	if _arm_pieces.has(key):
		return _arm_pieces[key]
	var tex := _layer_texture(ALT_PADS_LAYER)
	if tex == null:
		return null
	var image := tex.get_image()
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	# Clear the other side's half (the left pad is the one at the canvas's left).
	if side == "left":
		image.fill_rect(Rect2i(ALT_PADS_SPLIT_COLUMN, 0, image.get_width() - ALT_PADS_SPLIT_COLUMN, image.get_height()), Color(0, 0, 0, 0))
	else:
		image.fill_rect(Rect2i(0, 0, ALT_PADS_SPLIT_COLUMN, image.get_height()), Color(0, 0, 0, 0))
	var cut := ImageTexture.create_from_image(image)
	_arm_pieces[key] = cut
	return cut


## Adds one full-canvas layer for the given sheet layer, named after it. Returns the
## TextureRect, or null if the sheet has no such layer.
func _add_layer(layer: String, visible_now: bool = true) -> TextureRect:
	return _add_texture_layer(_layer_texture(layer), layer, visible_now)


## One sheet layer as a full-canvas texture, or null if the sheet doesn't have it.
func _layer_texture(layer: String) -> Texture2D:
	return PackedSpriteSheet.layer_textures(SHEET_PATH, SHEET_JSON_PATH).get(layer) as Texture2D


## A piece of one side's arm art, cut out by rows: "arm" (down to WRIST_ROW, no hand),
## "hand" (from WRIST_ROW), or - for an arm built piece by piece - "upper_arm" (down to
## ELBOW_ROW) and "forearm" (ELBOW_ROW to WRIST_ROW). Built once per side and kept (as
## are the alternate shoulder pads' halves).
static var _arm_pieces: Dictionary = {}


func _arm_piece(side: String, piece: String) -> Texture2D:
	var key := "%s_%s" % [side, piece]
	if _arm_pieces.has(key):
		return _arm_pieces[key]
	var tex := _layer_texture(String(ARM_TEX[side]))
	if tex == null:
		return null
	var image := tex.get_image()
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var rows: Vector2i = {
		"arm": Vector2i(0, int(WRIST_ROW[side])),
		"hand": Vector2i(int(WRIST_ROW[side]), image.get_height()),
		"upper_arm": Vector2i(0, int(ELBOW_ROW[side])),
		"forearm": Vector2i(int(ELBOW_ROW[side]), int(WRIST_ROW[side])),
	}.get(piece, Vector2i(0, image.get_height()))
	# Clear everything outside the piece's rows.
	image.fill_rect(Rect2i(0, 0, image.get_width(), rows.x), Color(0, 0, 0, 0))
	image.fill_rect(Rect2i(0, rows.y, image.get_width(), image.get_height() - rows.y), Color(0, 0, 0, 0))
	var cut := ImageTexture.create_from_image(image)
	_arm_pieces[key] = cut
	return cut


## The pieces of a limb built so far (see GameState.limb_segments), drawn where the whole
## limb's layer would be: a leg's thigh / shin / foot layers, an arm's upper arm (with its
## shoulder) and forearm. Called for a layer whose limb isn't on her whole.
func _add_part_built_layer(rel: String, gate: String) -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null or not state.has_method("get_limb_segments"):
		return
	for side in ["left", "right"]:
		if gate == "leg_" + side and rel in LEG_PARTS[side]:
			if (state.call("get_limb_segments", "leg", side) as Array).has(rel.trim_prefix(side + "_")):
				_add_leg_part(rel)
		elif gate == "arm_" + side:
			var built: Array = state.call("get_limb_segments", "arm", side)
			if rel == LEAN_ARM_SENTINEL[side]:
				for piece in ["upper_arm", "forearm"]:
					if built.has(piece):
						_add_layer(String(LEAN_ARM_TEX[side][piece]))
			elif rel == ARM_TEX[side]:
				for piece in ["upper_arm", "forearm"]:
					if built.has(piece):
						_add_texture_layer(_arm_piece(side, piece), "%s_%s" % [side, piece])
			elif rel == SHOULDER_SENTINEL[side] and built.has("upper_arm"):
				_build_shoulder_variants(side)


## Part `id`'s art (on `side`, for an arm / leg / hand) as she wears it, back to front, each a
## full-canvas texture drawn in place - for a part held in the hand before it goes back on
## (Maintenance). An arm brings its hand (if that hand is on her) and its current shoulder;
## the chest its cosmetics; the stomach is just itself. A limb segment (thigh / shin / foot,
## upper_arm / forearm) is just its own piece - the upper arm with its shoulder. Drawn in the
## pose she'll be in once it's on: a thigh can sit her up.
func part_textures(id: String, side: String = "") -> Array[Texture2D]:
	var sits := _sits_with(id, side)
	var layers: Array = []
	match id:
		"arm":
			var hand_on := false
			var state := get_node_or_null("/root/GameState")
			if state != null and bool(state.call("is_part_attached_on", "hand", side)):
				hand_on = true
			if sits:
				layers.append(_arm_piece(side, "arm"))
				if hand_on:
					layers.append(_arm_piece(side, "hand"))
				layers.append(_shoulder_texture(side, _shoulder_variant[side]))
			else:
				for piece in ["upper_arm", "forearm"] + (["hand"] if hand_on else []):
					layers.append(_layer_texture(String(LEAN_ARM_TEX[side][piece])))
		"hand", "forearm":
			layers.append(_arm_piece(side, id) if sits else _layer_texture(String(LEAN_ARM_TEX[side][id])))
		"upper_arm":
			if sits:
				layers.append(_arm_piece(side, "upper_arm"))
				layers.append(_shoulder_texture(side, _shoulder_variant[side]))
			else:
				layers.append(_layer_texture(String(LEAN_ARM_TEX[side]["upper_arm"])))
		"thigh", "shin", "foot":
			layers.append(_layer_texture("%s_%s" % [side, id]))
		"leg":
			for layer in LEG_PARTS[side]:
				layers.append(_layer_texture(layer))
		"head":
			if not sits:
				layers.append(_layer_texture("head_lean"))
			else:
				for layer in ["hair_back", "neck", "head", String(HAIR_FRONT_BY_STYLE.get(_hair_style(), "hair_front_swing"))]:
					layers.append(_layer_texture(layer))
		"chest":
			var size := _coconut_size()
			# What the cover isn't shaped for stays under it (see _under_cover_nodes).
			var cover_worn := _has_cosmetic("big_chest_cover") and _chest_cover_equipped
			if not sits:
				layers.append(_layer_texture("chest_lean"))
				if _wears_coconuts() and not cover_worn:
					layers.append(_layer_texture("medium_coconuts_lean"))
			else:
				layers.append(_layer_texture("chest"))
				if _wears_coconuts():
					layers.append(_layer_texture("%s_coconuts" % size))
					if size == "big" and not smooth_skin:
						layers.append(_layer_texture(COCO_LINES_LAYER))
					if not cover_worn:
						layers.append(_layer_texture("%s_pepperonis" % size))
				else:
					layers.append(_layer_texture("chest_holes"))
			if cover_worn:
				layers.append(_layer_texture(String(CHEST_COVER_BY_SIZE[size]) if sits else LEAN_CHEST_COVER_LAYER))
		"stomach":
			layers.append(_layer_texture(STOMACH_LAYER if sits else LEAN_STOMACH_LAYER))
	var out: Array[Texture2D] = []
	for tex in layers:
		if tex != null:
			out.append(tex)
	return out


## Whether she'll sit once part `id` (on `side`) goes on: a thigh or whole leg sits her up
## if the other thigh is on; the stomach goes on with no legs, so she leans; anything else
## leaves the pose as it is.
func _sits_with(id: String, side: String) -> bool:
	match id:
		"thigh", "leg":
			return _thigh_on("right" if side == "left" else "left")
		"stomach":
			return false
	return _sitting


## Adds one full-canvas layer showing `tex`. Returns the TextureRect, or null without one.
func _add_texture_layer(tex: Texture2D, layer_name: String, visible_now: bool = true) -> TextureRect:
	if tex == null:
		return null
	var layer := TextureRect.new()
	layer.name = layer_name
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

## Whether `side`'s leg is shown with at least its thigh on (whole or part-built).
func has_leg(side: String) -> bool:
	return _leg_part_names.get(side, []).has(side + "_thigh")


## Sitting upright (both thighs on) rather than leaning back.
func is_sitting() -> bool:
	return _sitting


## Whether `side`'s leg can swing out: it has its thigh on and she's sitting up.
func can_leg_out(side: String) -> bool:
	return _sitting and has_leg(side)


func is_leg_out(side: String) -> bool:
	return bool(_leg_out.get(side, false))


func toggle_leg_out(side: String) -> void:
	set_leg_out(side, not is_leg_out(side))


## Swings one leg out (or back). Out swaps each of that side's parts on (thigh / shin /
## foot) for its out art; with both legs out the stomach swaps to its crunch art. Only
## while she sits.
func set_leg_out(side: String, out: bool) -> void:
	if not _leg_out.has(side) or not can_leg_out(side):
		return
	_leg_out[side] = out
	refresh_pose()


func refresh_pose() -> void:
	# A pose change (leg swung out, crunch, cover on/off) changes the silhouette.
	_opaque_mask_dirty = true
	for side in ["left", "right"]:
		var out: bool = _leg_out[side] and not _leg_out_nodes[side].is_empty()
		for part in _leg_part_nodes[side]:
			if is_instance_valid(part):
				part.visible = not out
		for out_node in _leg_out_nodes[side]:
			if is_instance_valid(out_node):
				out_node.visible = out
	var both_out := _both_legs_out()
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

	# Chest cover: worn only while equipped (and owned, i.e. the node exists). What it
	# isn't shaped for hides under it.
	var cover_worn := has_chest_cover() and _chest_cover_equipped
	if has_chest_cover():
		_chest_cover_node.visible = _chest_cover_equipped
	for under in _under_cover_nodes:
		if is_instance_valid(under):
			under.visible = not cover_worn


## Positions each swung-out leg node: the editor horizontal spread (mirrored between the
## two legs) and vertical offset, plus the small crunch lift while both legs are out. Safe
## to call any time - it no-ops until the leg-out nodes exist (so the export setters can
## fire during initialization). Drives the live in-game preview of the offset variables.
func _apply_leg_out_offsets() -> void:
	if typeof(_leg_out_nodes) != TYPE_DICTIONARY or typeof(_leg_out) != TYPE_DICTIONARY:
		return
	var crunch_lift: float = -CRUNCH_LEG_LIFT if _both_legs_out() else 0.0
	# offset_top/bottom are positive-down, so negate the variable: positive lifts up.
	var vertical := crunch_lift - float(leg_out_vertical_offset)
	for side in ["left", "right"]:
		# Left leg: +offset moves right. Right leg mirrors: +offset moves left.
		var horizontal := float(leg_out_horizontal_offset)
		if side == "right":
			horizontal = -horizontal
		for out_node in _leg_out_nodes.get(side, []):
			if not is_instance_valid(out_node):
				continue
			out_node.offset_left = horizontal
			out_node.offset_right = horizontal
			out_node.offset_top = vertical
			out_node.offset_bottom = vertical


## Both legs swung out (with out art to show) - the crunch pose.
func _both_legs_out() -> bool:
	return is_leg_out("left") and is_leg_out("right") \
		and not _leg_out_nodes["left"].is_empty() and not _leg_out_nodes["right"].is_empty()


# --- shoulders / chest cover ---------------------------------------------

func has_shoulder(side: String) -> bool:
	return not _shoulder_nodes.get(side, {}).is_empty()


## Advances one shoulder to the next appearance variant (see SHOULDER_VARIANTS).
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
	return _opaque_rect_for(_leg_part_names.get(side, []))


## Opaque bounding rect of the stomach/pelvis art, for the battery drop target.
func pelvis_rect() -> Rect2:
	return _opaque_rect_for([STOMACH_LAYER if _sitting else LEAN_STOMACH_LAYER])


## Opaque bounding rect covering one shoulder's variants, for its cycle hover box.
func shoulder_rect(side: String) -> Rect2:
	var layers: Array = []
	for variant in SHOULDER_HIT_VARIANTS:
		layers.append(SHOULDER_TEX[side][variant])
	return _opaque_rect_for(layers)


## Opaque bounding rect of the chest cover, for its equip/unequip hover box.
func chest_cover_rect() -> Rect2:
	return _opaque_rect_for([_chest_cover_layer()])


# --- eyes -------------------------------------------------------------------

func _process(_delta: float) -> void:
	_update_eye_direction()


## Shows the one iris layer for where she's looking: at the mouse while eye tracking is
## on, otherwise straight ahead.
func _update_eye_direction() -> void:
	if _iris_nodes.is_empty():
		return
	var iris := "iris_forward"
	if eye_tracking and size.x > 0.0 and size.y > 0.0:
		var to_mouse := get_local_mouse_position() * CANVAS / size - EYE_CENTER
		var far := to_mouse.length() > EYE_FAR_DISTANCE
		if to_mouse.length() <= EYE_DEAD_ZONE:
			iris = "iris_forward"
		elif absf(to_mouse.y) > absf(to_mouse.x) * EYE_VERTICAL_BIAS:
			if to_mouse.y < 0.0:
				iris = "iris_up"
			else:
				iris = "iris_down_2" if far else "iris_down_1"
		else:
			iris = "iris_forward_%s_%d" % ["left" if to_mouse.x < 0.0 else "right", 2 if far else 1]
	if iris == _iris_shown:
		return
	_iris_shown = iris
	for layer in _iris_nodes:
		var node: TextureRect = _iris_nodes[layer]
		if is_instance_valid(node):
			node.visible = layer == iris


# --- look settings (Shift+Tab debug menu) -----------------------------------

func debug_setting_keys() -> Array:
	return DEBUG_SETTINGS


func debug_setting_label(key: String) -> String:
	match key:
		"shoulders":
			return "Shoulders: %s" % SHOULDER_VARIANT_NAMES.get(shoulder_style, shoulder_style)
		"smooth_skin":
			return "Smooth Skin: %s" % ("ON" if smooth_skin else "OFF")
		"coconuts":
			if coconut_size == "auto":
				return "Coconuts: Auto (%s)" % _coconut_size().capitalize()
			return "Coconuts: %s" % coconut_size.capitalize()
		"open_eyes":
			return "Open Eyes: %s" % ("ON" if open_eyes else "OFF")
		"eye_tracking":
			return "Eye Tracking: %s" % ("ON" if eye_tracking else "OFF")
	return key


## Steps one look setting to its next value. The host calls rebuild() after (re-placing its
## hover boxes), which shows the change.
func debug_cycle_setting(key: String) -> void:
	match key:
		"shoulders":
			var i: int = SHOULDER_VARIANTS.find(shoulder_style)
			shoulder_style = SHOULDER_VARIANTS[(i + 1) % SHOULDER_VARIANTS.size()]
			_shoulder_variant = {"left": shoulder_style, "right": shoulder_style}
		"smooth_skin":
			smooth_skin = not smooth_skin
		"coconuts":
			var i: int = COCONUT_SIZES.find(coconut_size)
			coconut_size = COCONUT_SIZES[(i + 1) % COCONUT_SIZES.size()]
		"open_eyes":
			open_eyes = not open_eyes
		"eye_tracking":
			eye_tracking = not eye_tracking
			# Tracking needs the eyes open to show.
			if eye_tracking:
				open_eyes = true


## Unions the opaque pixel bounds of the given sheet layers, scaled from the native
## canvas into this Control's current size.
func _opaque_rect_for(layers: Array) -> Rect2:
	var bounds := Rect2()
	var found := false
	var sx := size.x / CANVAS.x
	var sy := size.y / CANVAS.y
	for layer in layers:
		var tex := _layer_texture(String(layer))
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
	# bald head drawn over the back hair keeps the face allowed. Hair coverage is
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
			return _side_attached("arm", 0)
		"arm_right":
			return _side_attached("arm", 1)
		# A hand needs its arm on the same side.
		"hand_left":
			return _side_attached("arm", 0) and _side_attached("hand", 0)
		"hand_right":
			return _side_attached("arm", 1) and _side_attached("hand", 1)
		"leg_left":
			return _side_attached("leg", 0)
		"leg_right":
			return _side_attached("leg", 1)
		# The chest's cosmetics sit on the chest: none of them without it.
		"coconuts":
			return _part_count("chest") >= 1 and _wears_coconuts()
		"no_coconuts":
			return _part_count("chest") >= 1 and not _wears_coconuts()
		"coco_lines":
			return _gate_passes("coconuts") and _coconut_size() == "big" and not smooth_skin
		"cos_chest_cover":
			return _part_count("chest") >= 1 and _has_cosmetic("big_chest_cover")
		# The smooth skin runs from her neck down her chest.
		"smooth_skin":
			return smooth_skin and _part_count("head") >= 1 and _part_count("chest") >= 1
		"eyes":
			return open_eyes and _part_count("head") >= 1
	return false


func _part_count(id: String) -> int:
	if Engine.is_editor_hint():
		return 2
	var state := get_node_or_null("/root/GameState")
	# What's on her - the parts in her slots (GameState.equipped_parts).
	if state != null and state.has_method("get_attached_part_count"):
		return int(state.call("get_attached_part_count", id))
	if state != null and state.has_method("get_robot_part_count"):
		return int(state.call("get_robot_part_count", id))
	return 0


## Whether paired part `id` (arm / leg / hand) is on her on `side_index` (0 = left,
## 1 = right) - the laptop can take off one particular side.
func _side_attached(id: String, side_index: int) -> bool:
	if Engine.is_editor_hint():
		return true
	var state := get_node_or_null("/root/GameState")
	if state != null and state.has_method("is_part_attached_on"):
		return bool(state.call("is_part_attached_on", id, "left" if side_index == 0 else "right"))
	return _part_count(id) > side_index


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
