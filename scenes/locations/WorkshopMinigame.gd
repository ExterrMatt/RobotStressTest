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
## The opening of the bag in the background art (minigame-local; it sits just above the
## top edge), which tray pages dive into and fly out of when cycled.
@export var bag_mouth_position: Vector2 = Vector2(110, -15)

# Craftable items. Two shapes live here:
#   - SEGMENT parts carry a flat "recipe" of raw ingredients (scrap_metal, nuts_bolts, …).
#   - COMPOSITE limbs (arm / leg / chest / stomach) carry a "segments" list instead (plus, for
#     the stomach, "optional_segments"). Ingredients make components in the craft bin;
#     components make limbs by dragging them from the inventory into the assembly area.
#     See the "limb building" section.
# head stays a single-recipe part (no segment breakdown yet).
const CRAFTABLE_PARTS: Dictionary = {
	"head": {
		"display_name": "Head",
		"recipe": {"head_segments": 1},
	},

	# --- arm + its segments ---
	"upper_arm": {
		"display_name": "Upper Arm",
		"recipe": {"scrap_metal": 3, "nanobots": 1, "electronics": 2, "nuts_bolts": 2, "synth_skin": 1},
	},
	"forearm": {
		"display_name": "Forearm",
		"recipe": {"scrap_metal": 3, "nanobots": 1, "electronics": 1, "nuts_bolts": 3, "synth_skin": 1},
	},
	"hand": {
		"display_name": "Hand",
		"recipe": {"scrap_metal": 2, "nanobots": 1, "electronics": 1, "nuts_bolts": 2, "synth_skin": 1},
	},
	"arm": {
		"display_name": "Arm",
		"segments": ["upper_arm", "forearm"],
	},

	# --- leg + its segments ---
	"thigh": {
		"display_name": "Thigh",
		"recipe": {"scrap_metal": 6, "nanobots": 2, "electronics": 4, "nuts_bolts": 3, "synth_skin": 3},
	},
	"shin": {
		"display_name": "Shin",
		"recipe": {"scrap_metal": 4, "nanobots": 1, "electronics": 2, "nuts_bolts": 2, "synth_skin": 2},
	},
	"foot": {
		"display_name": "Foot",
		"recipe": {"scrap_metal": 2, "nanobots": 1, "electronics": 1, "nuts_bolts": 2, "synth_skin": 1},
	},
	"leg": {
		"display_name": "Leg",
		"segments": ["thigh", "shin", "foot"],
	},

	# --- chest + its segments ---
	"ribcage": {
		"display_name": "Rib Cage",
		"recipe": {"scrap_metal": 5, "electronics": 2, "nuts_bolts": 2},
	},
	"upper_plating": {
		"display_name": "Upper Plating",
		"recipe": {"scrap_metal": 4, "nanobots": 1, "synth_skin": 3},
	},
	"lower_plating": {
		"display_name": "Lower Plating",
		"recipe": {"scrap_metal": 2, "nanobots": 1, "nuts_bolts": 1, "synth_skin": 1},
	},
	"chest": {
		"display_name": "Chest",
		"segments": ["ribcage", "upper_plating", "lower_plating"],
	},

	# --- stomach + its segments ---
	# The pelvis (metal shell) and outer plating are required; the internals are optional
	# extras (see "optional_segments"). The shell and plating are built in one craft — the
	# shell goes down, the outer skin goes over it — which yields both items.
	"outer_plating": {
		"display_name": "Outer Plating",
		"recipe": {"scrap_metal": 7, "synth_skin": 3, "nanobots": 1, "nuts_bolts": 2, "electronics": 1},
		"yields": {"pelvis": 1, "outer_plating": 1},
	},
	"external": {
		"display_name": "External",
		"recipe": {"scrap_metal": 1, "electronics": 1, "nuts_bolts": 1},
	},
	"tank": {
		"display_name": "Tank",
		"recipe": {"scrap_metal": 3, "nuts_bolts": 2, "synth_skin": 1},
	},
	"pump": {
		"display_name": "Pump",
		"recipe": {"scrap_metal": 1, "electronics": 2, "nuts_bolts": 2, "nanobots": 1},
	},
	"huge_battery": {
		"display_name": "Huge Battery",
		"recipe": {"scrap_metal": 2, "electronics": 3, "nanobots": 1},
	},
	"stomach": {
		"display_name": "Stomach",
		"segments": ["pelvis", "outer_plating"],
		"optional_segments": ["tank", "pump", "huge_battery", "external"],
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
	"battery":       "res://assets/textures/icons/battery.png",
	"shoulder_pad":  "res://assets/textures/icons/shoulder_pad.png",
	# Craftable segment items — a limb is crafted by dropping these into the bin, so the
	# tray needs their icons (note: thigh art is thighs.png).
	"upper_arm":     "res://assets/textures/icons/upper_arm.png",
	"forearm":       "res://assets/textures/icons/forearm.png",
	"hand":          "res://assets/textures/icons/hand.png",
	"thigh":         "res://assets/textures/icons/thighs.png",
	"shin":          "res://assets/textures/icons/shin.png",
	"foot":          "res://assets/textures/icons/foot.png",
	"ribcage":       "res://assets/textures/icons/ribcage.png",
	"upper_plating": "res://assets/textures/icons/upper_plating.png",
	"lower_plating": "res://assets/textures/icons/lower_plating.png",
	"tank":          "res://assets/textures/icons/tank.png",
	"pump":          "res://assets/textures/icons/pump.png",
	"huge_battery":  "res://assets/textures/icons/huge_battery.png",
	"pelvis":        "res://assets/textures/icons/pelvis.png",
	"outer_plating": "res://assets/textures/icons/outer_plating.png",
	"external":      "res://assets/textures/icons/external.png",
	# Finished limbs (robot parts) — shown in the tray too, so a finished limb can be
	# dragged back in to be disassembled (the stomach's art is the legacy torso.png).
	"arm":           "res://assets/textures/icons/arm_no_hand.png",
	"leg":           "res://assets/textures/icons/leg.png",
	"stomach":       "res://assets/textures/icons/torso.png",
	"chest":         "res://assets/textures/icons/chest.png",
	"head":          "res://assets/textures/icons/head.png",
}

## Tray / bin pieces draw at their art's native size, but no icon's visible art may be
## bigger than the nuts & bolts': anything larger is scaled down until its longest side
## matches (see _ingredient_visual_scale). Smaller icons stay as they are.
const INGREDIENT_SIZE_REFERENCE_ID: String = "nuts_bolts"
## Per-item scale overrides, still capped at the nuts & bolts' size.
const INGREDIENT_VISUAL_SCALES: Dictionary = {
	"head_segments": 1.05,
}

## The tray shows the inventory a page at a time; the arrow buttons in its top-left corner
## cycle the pages, the old page diving into the bag as the new one flies out of it.
const TRAY_PAGE_SIZE: int = 8
const TRAY_SLOT_SIZE: Vector2 = Vector2(40, 40)
## Slot centres (tray-local) for one page, in item order — a loose pile under the arrows,
## hand-placed so the tiles overlap like they've been tipped out of the bag.
const TRAY_SLOT_CENTERS: Array[Vector2] = [
	Vector2(120, 45), Vector2(195, 45),
	Vector2(29, 73), Vector2(120, 95), Vector2(195, 95),
	Vector2(83, 91), Vector2(158, 145),
	Vector2(28, 141),
]
const TRAY_PAGE_BUTTON_SIZE: Vector2 = Vector2(22, 22)
const TRAY_PAGE_BUTTON_GAP: float = 6.0
const TRAY_PAGE_TURN_DURATION: float = 0.35
## How long each tile waits after the one before it sets off.
const TRAY_PAGE_TURN_STAGGER: float = 0.035
## How far a tile's flight time may stray from TRAY_PAGE_TURN_DURATION (0.4 = ±40%).
const TRAY_PAGE_TURN_TIME_VARIATION: float = 0.4
## How small a tile is at the bag's opening.
const TRAY_BAG_SCALE: float = 0.1
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
## The upper-arm sub-assembly: shoulder + upper arm + elbow — exactly the segments
## the work-scene arm minigame builds. When an arm is crafted with an `upper_arm`
## item in the recipe, these spawn pre-assembled as ONE bundle (paired so they
## drag and drop together, filling all their slots at once) rather than as loose
## pieces; the forearm (wrist / forearm / forearm_lower) still spawns loose.
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
## The forearm sub-assembly: the arm slots NOT in the upper-arm subset (wrist / forearm /
## forearm_lower). Crafting a standalone `forearm` reuses the arm assembly with just these
## active, mirroring how `upper_arm` reuses it with UPPER_ARM_SEGMENT_IDS.
const FOREARM_SEGMENT_IDS: Array[StringName] = [
	&"wrist",
	&"forearm_lower",
	&"forearm",
]
## The leg assembly (AssemblyLeg in the scene) is harvested whole into
## _leg_assembly_slot_ids. Crafting a standalone thigh / shin / foot reuses that assembly
## with only its own slot subset active — the same slot-subset trick as upper_arm/forearm.
## Together these three partition the full leg (top → mid → foot).
const LEG_THIGH_SEGMENT_IDS: Array[StringName] = [
	&"upper_thigh", &"mid_thigh", &"side_thigh", &"butt",
	&"knee", &"knee_joint", &"knee_joint_axel",
]
## The ankle axle and its cap ("ankle") stay together on the shin, as the knee's do on the
## thigh and the elbow's on the upper arm.
const LEG_SHIN_SEGMENT_IDS: Array[StringName] = [
	&"calf", &"lower_leg", &"shin", &"ankle_axel", &"ankle",
]
const LEG_FOOT_SEGMENT_IDS: Array[StringName] = [
	&"heel", &"upper_foot", &"middle_foot", &"toes", &"toes_border",
]
## The chest's three components: the rib cage is the ribs under everything, the upper
## plating the front plate with its two holes plus the upper sides, collar, shoulders and
## neck, and the lower plating the bottom curve (the five lower pieces). (Slot keys carry
## the chest's "chest_" prefix.)
const CHEST_RIBCAGE_SLOT_IDS: Array[StringName] = [&"chest_ribs"]
const CHEST_UPPER_PLATING_SLOT_IDS: Array[StringName] = [
	&"chest_left_upper_chest", &"chest_right_upper_chest", &"chest_left_collar",
	&"chest_right_collar", &"chest_mid_chest", &"chest_left_hole", &"chest_right_hole",
	&"chest_left_shoulder", &"chest_right_shoulder", &"chest_turtle", &"chest_neck",
]
const CHEST_LOWER_PLATING_SLOT_IDS: Array[StringName] = [
	&"chest_left_lower_chest", &"chest_right_lower_chest", &"chest_lower_mid_chest",
	&"chest_lower_left_mid_chest", &"chest_lower_right_mid_chest",
]
## Maps a limb's component id to the assembly slots that make it up: dragging the finished
## component into the assembly area fills them all at once.
const COMPONENT_SLOT_GROUPS: Dictionary = {
	&"upper_arm": UPPER_ARM_SEGMENT_IDS,
	&"forearm": FOREARM_SEGMENT_IDS,
	&"thigh": LEG_THIGH_SEGMENT_IDS,
	&"shin": LEG_SHIN_SEGMENT_IDS,
	&"foot": LEG_FOOT_SEGMENT_IDS,
	&"ribcage": CHEST_RIBCAGE_SLOT_IDS,
	&"upper_plating": CHEST_UPPER_PLATING_SLOT_IDS,
	&"lower_plating": CHEST_LOWER_PLATING_SLOT_IDS,
}
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

## The outer plating and chest are built with `unified_outline` enabled: their
## "_outline" layers are authored as one contiguous block *behind* every base
## layer, so a placed piece keeps its outline (repainted behind all bases by a
## unified outline layer) instead of the arm/head behaviour where a placed
## outline is dropped.
##
## (The outer plating and chest art comes from the packed torso sheet - see
## TORSO_SHEET_PATH; the segment names below are its layer names.)
const STOMACH_TEXTURE_DIR: String = "res://assets/textures/characters/robot/workshop/workshop robot body/torso"
## The outer plating craft: the metal shell goes down first, then the stomach's outer-skin
## pieces over it; collecting it yields both the pelvis and the outer plating. Back-to-front
## draw order (the Aseprite layer stack, bottom-to-top). The "_outline" layers are not listed
## here — each is loaded as its base piece's outline, kept visible behind all bases once
## placed. The shell comes from the stomach sheet, re-centred under the skin (see
## _outer_plating_layers).
const OUTER_PLATING_ASSEMBLY_SIZE: Vector2 = Vector2(337, 337)
const OUTER_PLATING_SHELL_SLOT: StringName = &"skin_metal_shell"
## The chest's neck sits inside its turtle-neck collar, so the collar goes on first.
const CHEST_TURTLE_SLOT: StringName = &"chest_turtle"
const CHEST_NECK_SLOT: StringName = &"chest_neck"
const OUTER_PLATING_SEGMENT_IDS: Array[StringName] = [
	&"metal_shell",
	&"top_torso",
	&"belly_button",
	&"gut",
	&"pelvis",
	&"left_torso",
	&"right_torso",
	&"left_socket",
	&"right_socket",
]

## The stomach itself, from its own packed sheet: the metal shell goes down first, the
## internals sit inside it, and the outer plating covers everything. Each internal's
## "<id>_internals" layer is how it looks once installed inside the shell; a placed piece
## swaps to it (see _apply_installed_art).
const STOMACH_SHEET_PATH: String = "res://assets/textures/characters/robot/workshop/workshop robot body/torso/stomach_internals.png"
const STOMACH_SHEET_JSON_PATH: String = "res://assets/textures/characters/robot/workshop/workshop robot body/torso/stomach_internals.json"
const STOMACH_ASSEMBLY_SIZE: Vector2 = Vector2(170, 170)
## Back-to-front draw order (the sheet's layer stack, bottom-to-top, minus "_internals").
const STOMACH_SEGMENT_IDS: Array[StringName] = [
	&"metal_shell",
	&"huge_battery",
	&"internal",
	&"bottom_socket",
	&"right_tank",
	&"left_tank",
	&"right_wire",
	&"left_wire",
	&"external",
	&"outer_plating",
]
## Slots only used while a component is crafted on its own. Installed in the stomach, the
## pump and external are just their "_internals" art (which already shows the wires and the
## socket), so these layers stay hidden there, as they are in the sheet.
const STOMACH_UNINSTALLED_ONLY_SLOTS: Array[StringName] = [
	&"stomach_bottom_socket", &"stomach_right_wire", &"stomach_left_wire",
]
const STOMACH_SLOT_PREFIX: String = "stomach_"
## Which stomach slots each stomach component fills. The pelvis (shell) and outer plating
## are required; the rest are optional internals. The components of the other limbs that
## fill slots are in COMPONENT_SLOT_GROUPS.
const STOMACH_COMPONENT_SLOTS: Dictionary = {
	&"pelvis": [&"stomach_metal_shell"],
	&"outer_plating": [&"stomach_outer_plating"],
	# Crafting a tank in the bin builds just the one.
	&"tank": [&"stomach_left_tank"],
	&"left_tank": [&"stomach_left_tank"],
	&"right_tank": [&"stomach_right_tank"],
	&"pump": [&"stomach_internal", &"stomach_right_wire", &"stomach_left_wire"],
	&"huge_battery": [&"stomach_huge_battery"],
	&"external": [&"stomach_bottom_socket", &"stomach_external"],
}
## A stomach holds two tanks, one per side: each "tank" item goes into whichever side it's
## dropped nearer (see _stomach_tank_side) and is tracked as that side's component.
const STOMACH_TANK_SIDES: Array[StringName] = [&"left_tank", &"right_tank"]

const CHEST_TEXTURE_DIR: String = STOMACH_TEXTURE_DIR
## The chest and outer-plating layers (and their outlines) packed into one sheet by
## Aseprite. Each layer is rebuilt at its full 337x337 canvas from it (see
## PackedSpriteSheet.layer_textures). A layer missing from the sheet would fall
## back to a loose "<layer>.png" in the torso folder, but none ship there now.
const TORSO_SHEET_PATH: String = "res://assets/textures/characters/robot/workshop/workshop robot body/torso/workshop_torso.png"
const TORSO_SHEET_JSON_PATH: String = "res://assets/textures/characters/robot/workshop/workshop robot body/torso/workshop_torso.json"
const CHEST_ASSEMBLY_SIZE: Vector2 = Vector2(337, 337)
## Back-to-front draw order for the assembled chest: the ribs at the back, then the chest
## group's Aseprite layer stack, bottom-to-top. Each plating piece gets its own outline cut
## from CHEST_OUTLINE_LAYERS — see _chest_layers.
const CHEST_SEGMENT_IDS: Array[StringName] = [
	&"ribs",
	&"left_lower_chest",
	&"left_upper_chest",
	&"right_lower_chest",
	&"right_upper_chest",
	&"right_collar",
	&"left_collar",
	&"mid_chest",
	&"lower_mid_chest",
	&"lower_left_mid_chest",
	&"lower_right_mid_chest",
	&"left_hole",
	&"right_hole",
	&"left_shoulder",
	&"right_shoulder",
	&"turtle",
	&"neck",
]
## The chest's authored outline layers. They trace the plating as it was before it was split
## into components (one outline round each whole side piece, one round the centre plate and
## its bottom curve), so each piece takes just the slice of them within this many pixels of
## its own art.
const CHEST_OUTLINE_LAYERS: Array[String] = [
	"left_hole_outline", "right_hole_outline", "left_chest_outline",
	"right_chest_outline", "mid_chest_outline", "turtle_outline",
]
const CHEST_OUTLINE_REACH: int = 3
## The authored outlines only run round the finished plating, so where a piece meets another
## plating piece (lower plating's top edge against the upper plating) it gets this many pixels
## of black outline of its own. In the finished chest the neighbour's art covers it.
const CHEST_SEAM_OUTLINE_WIDTH: int = 2
const CHEST_SEAM_OUTLINE_COLOR: Color = Color.BLACK
## The chest export has no ribs, so the rib cage's own art stands in, centred on the plating.
const CHEST_RIBS_TEXTURE_PATH: String = "res://assets/textures/icons/ribcage.png"
## Nudge from that centred spot (positive y = lower).
const CHEST_RIBS_OFFSET: Vector2i = Vector2i(0, 7)
const INGREDIENT_SHADOW_PATHS: Dictionary = {
	"scrap_metal":   "res://assets/textures/icons/scrap_metal_shadow.png",
	"nuts_bolts":    "res://assets/textures/icons/nuts_bolts_shadow.png",
	"electronics":   "res://assets/textures/icons/electronics_shadow.png",
	"synth_skin":    "res://assets/textures/icons/synth_skin_shadow.png",
	"head_segments": "res://assets/textures/icons/head_segments.png",
	"oil":           "res://assets/textures/icons/oil_shadow.png",
}
const UI_SOUND := preload("res://scenes/ui/UiSound.gd")
## Single-pulse reveal shown once when a part is crafted, so the player gets one
## glimpse of every segment's target — regardless of the Easy Workshop setting.
const HINT_PULSE_DURATION: float = 0.65
const HINT_PULSE_PEAK_ALPHA: float = 0.85
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
var _outer_plating_assembly: Control = null
var _chest_assembly: Control = null
## Slot ids actually built for the procedural hand/stomach/chest assemblies.
## Chest keys are namespaced (see the key_prefix in _build_segmented_assembly) so
## a shared segment name like "neck" can't collide with the head's slot.
var _hand_assembly_slot_ids: Array[StringName] = []
var _stomach_assembly_slot_ids: Array[StringName] = []
var _outer_plating_assembly_slot_ids: Array[StringName] = []
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
## Limb building: finished components dragged from the inventory into the assembly area.
## The first one picks the limb (_crafted_part_id, with _crafted still false); after that
## only that limb's components fit, until every one is dragged back out.
var _limb_components: Array[StringName] = []
## Placed component -> Array of its placed segments.
var _limb_component_nodes: Dictionary = {}
## The tray-sized tile being carried out of the assembly area: a component lifted back out,
## or (with _carrying_limb) the finished part being dragged to the inventory to collect it.
var _carry_piece: WorkshopPiece = null
var _carrying_limb: bool = false

var _tray_page: int = 0
var _tray_animating: bool = false
var _tray_prev_button: Button = null
var _tray_next_button: Button = null
## True only while a multi-segment bundle is being dropped, so the leg drop scoring relaxes
## its "release point must be inside the slot" rule and lets each bundle member settle into
## its own slot by overlap (each segment only ever accepts its own slot anyway).
var _placing_bundle: bool = false

var _shadow_group: CanvasGroup = null
var _shadow_drawer: Control = null
var _spawn_rng := RandomNumberGenerator.new()
var _assembly_templates_collected: bool = false
var _placement_hint_layer: Control = null
var _placement_hint_sprite: TextureRect = null
var _pending_hint_entries: Array = []
var _placement_hint_elapsed: float = 0.0

# Placement sound: the same metal thunk the work-scene arm assembly plays when a
# limb segment lands in its slot (random heavy/light clip, ±10% pitch).
const PLACE_SOUND_PATHS: Array[String] = [
	"res://assets/sounds/metal_thunk/heavy_metal_thunk.mp3",
	"res://assets/sounds/metal_thunk/light_metal_thunk.mp3",
]
const PLACE_PITCH_VARIATION_PERCENT: int = 10
var _place_rng := RandomNumberGenerator.new()
var _place_sounds: Array[AudioStream] = []
var _place_audio_player: AudioStreamPlayer = null
## When true the hint layer plays a single in-out pulse (the on-craft "here's
## where everything goes" reveal) and then clears itself, instead of the
## continuous drag-time flash.
var _hint_pulse_once: bool = false
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
	var torso_layers := PackedSpriteSheet.layer_textures(TORSO_SHEET_PATH, TORSO_SHEET_JSON_PATH)
	var stomach_layers := PackedSpriteSheet.layer_textures(STOMACH_SHEET_PATH, STOMACH_SHEET_JSON_PATH)
	# Each stomach piece carries its "_internals" art, swapped in once it's installed.
	_stomach_assembly = _build_segmented_assembly(
		"AssemblyStomach", STOMACH_TEXTURE_DIR, STOMACH_SEGMENT_IDS, STOMACH_ASSEMBLY_SIZE,
		stomach_assembly_offset, false, STOMACH_SLOT_PREFIX, _stomach_assembly_slot_ids, [],
		stomach_layers, "_internals")
	# The skin's unified outlines paint above the shell, which sits under everything.
	_outer_plating_assembly = _build_segmented_assembly(
		"AssemblyOuterPlating", STOMACH_TEXTURE_DIR, OUTER_PLATING_SEGMENT_IDS,
		OUTER_PLATING_ASSEMBLY_SIZE, stomach_assembly_offset, true, "skin_",
		_outer_plating_assembly_slot_ids, [], _outer_plating_layers(torso_layers, stomach_layers),
		"", &"metal_shell")
	_chest_assembly = _build_segmented_assembly(
		"AssemblyChest", CHEST_TEXTURE_DIR, CHEST_SEGMENT_IDS, CHEST_ASSEMBLY_SIZE,
		chest_assembly_offset, true, "chest_", _chest_assembly_slot_ids, [],
		_chest_layers(torso_layers))
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
	_setup_place_audio()
	_setup_tray_page_buttons()
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
	# A finished limb (all slots filled, just not collected yet) doesn't need any
	# placement help — don't pop the offer.
	if _is_assembly_complete():
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
	var color := _placement_hint_sprite.modulate
	if _hint_pulse_once:
		# One rise-and-fall over HINT_PULSE_DURATION, then clear.
		var t: float = _placement_hint_elapsed / HINT_PULSE_DURATION
		if t >= 1.0:
			_clear_placement_hints()
			return
		color.a = sin(t * PI) * HINT_PULSE_PEAK_ALPHA
		_placement_hint_sprite.modulate = color
		return
	var wave := (sin(_placement_hint_elapsed * TAU * 1.45) + 1.0) * 0.5
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
	_hint_pulse_once = false


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
		if not _segment_prerequisites_met(segment.segment_id):
			continue
		for slot in _hint_slots_for_segment(segment):
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


## One-shot reveal fired the moment a part is crafted: flash every freshly-spawned
## segment at its target slot a single time, so the player sees the whole layout
## once even with Easy Workshop off. Iterates the canonical slot order so the
## baked preview overlaps back-to-front like the finished part.
func _flash_all_placement_hints_once() -> void:
	_clear_placement_hints()
	var used: Dictionary = {}
	for slot_id in _active_assembly_slot_ids:
		var slot: WorkshopAssemblySlot = _assembly_slots.get(slot_id)
		if slot == null or slot.filled:
			continue
		var segment: WorkshopSegment = _find_bin_segment_for_slot(slot, used)
		if segment == null:
			continue
		used[segment] = true
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
	if _placement_hint_sprite != null and is_instance_valid(_placement_hint_sprite):
		# Start dark so the single pulse rises from nothing rather than popping in.
		_placement_hint_sprite.modulate.a = 0.0
		move_child(_placement_hint_layer, get_child_count() - 1)
	_hint_pulse_once = true
	_placement_hint_elapsed = 0.0


## Find an as-yet-unused segment sitting in the craft bin that this slot accepts.
## Prefer an exact segment-id match so each eye socket previews its own-side eye art
## (eyes accept either socket); fall back to any accepted segment if none matches.
func _find_bin_segment_for_slot(slot: WorkshopAssemblySlot, used: Dictionary) -> WorkshopSegment:
	var fallback: WorkshopSegment = null
	for child in craft_bin.get_children():
		if not (child is WorkshopSegment):
			continue
		var segment := child as WorkshopSegment
		if used.has(segment) or segment.locked:
			continue
		if not _slot_accepts_segment(slot, segment):
			continue
		if segment.segment_id == slot.accepts_segment_id:
			return segment
		if fallback == null:
			fallback = segment
	return fallback


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
		elif _carry_piece:
			_carry_piece.update_drag(event.global_position)
			get_viewport().set_input_as_handled()


func _handle_left_press(global_pos: Vector2) -> void:
	if _active_drag_segment or _active_drag_piece or _carry_piece:
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

	for btn in [_tray_prev_button, _tray_next_button]:
		if _hit_button(btn, global_pos):
			if btn.disabled or _tray_animating:
				UI_SOUND.play_inaccessible_button(self)
			else:
				_turn_tray_page(-1 if btn == _tray_prev_button else 1)
			get_viewport().set_input_as_handled()
			return

	var seg: WorkshopSegment = _find_topmost_segment_at(global_pos)
	if seg != null:
		_pick_up_segment(seg, global_pos)
		get_viewport().set_input_as_handled()
		return

	if not _hit_button(collect_button, global_pos) and _try_pick_up_from_assembly(global_pos):
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
	if _carry_piece != null:
		_finish_carry(global_pos)
		get_viewport().set_input_as_handled()
		return

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

		# A pre-assembled bundle drops as one: let each member settle into its own slot by
		# overlap even for legs (which otherwise demand the release point land in the slot).
		_placing_bundle = group.size() > 1
		var drops: Array = []
		var all_valid: bool = true
		for seg in group:
			seg.end_drag()
			var target: WorkshopAssemblySlot = _best_segment_drop_target(seg, global_pos)
			if target == null:
				all_valid = false
			drops.append([seg, target])
		_placing_bundle = false

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

		# A finished component dropped on the assembly area joins the limb being built
		# there (the first one picks which limb it is).
		if assembly.get_global_rect().has_point(global_pos):
			var key := _limb_component_key(String(piece.item_id), global_pos)
			if key != &"":
				_remove_and_free(piece)
				_add_limb_component(key)
				craft_bin.contents_changed.emit()
				get_viewport().set_input_as_handled()
				return
			UI_SOUND.play_inaccessible_button(self)

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
		if not _segment_prerequisites_met(segment.segment_id):
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


## Slots to flash while dragging a segment. For every normal part this is the one
## slot it fits. Eyes are the exception: they accept both sockets, so hinting both
## would ghost a second eye at the far socket while you only hold one (the "eye too
## far right" the head tutorial showed). For an eye we return a single target: its
## own-side socket if open, otherwise the first other open eye socket.
func _hint_slots_for_segment(segment: WorkshopSegment) -> Array[WorkshopAssemblySlot]:
	var slots: Array[WorkshopAssemblySlot] = _slots_for_segment(segment)
	if not (_crafted_part_id == "head" and HEAD_EYE_SEGMENT_IDS.has(segment.segment_id)):
		return slots
	var own_side: Array[WorkshopAssemblySlot] = []
	var fallback: Array[WorkshopAssemblySlot] = []
	for slot in slots:
		if slot == null or slot.filled:
			continue
		if slot.accepts_segment_id == segment.segment_id:
			own_side.append(slot)
		elif fallback.is_empty():
			fallback.append(slot)
	if not own_side.is_empty():
		return own_side
	return fallback


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
	if not _segment_prerequisites_met(segment.segment_id):
		return -1.0e20

	var slot_hitbox: Rect2 = slot.get_global_hitbox()
	var segment_hitbox: Rect2 = segment.get_global_hitbox()
	var release_hits_slot: bool = slot_hitbox.has_point(release_global_pos)
	var overlap_area: float = _rect_overlap_area(segment_hitbox, slot_hitbox)
	if not release_hits_slot:
		# Legs normally demand the release point land inside the slot, but a pre-assembled
		# bundle drops with a single release point far from most of its members, so let those
		# members settle by overlap instead (each segment only accepts its own slot anyway).
		if _crafted_part_id == "leg" and not _placing_bundle:
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


func _segment_prerequisites_met(segment_id: StringName) -> bool:
	if _crafted_part_id == "outer_plating":
		# The metal shell goes down before the outer skin.
		return segment_id == OUTER_PLATING_SHELL_SLOT or _slot_filled(OUTER_PLATING_SHELL_SLOT)
	if segment_id == CHEST_NECK_SLOT:
		return _slot_filled(CHEST_TURTLE_SLOT)
	if _crafted_part_id != "head":
		return true
	if segment_id == &"metal_head":
		return true
	var metal_slot: WorkshopAssemblySlot = _assembly_slots.get(&"metal_head")
	if metal_slot == null or not metal_slot.filled:
		return false
	if HEAD_EYELID_SEGMENT_IDS.has(segment_id):
		return _slot_filled(&"left_eye") and _slot_filled(&"right_eye")
	if segment_id == &"hair":
		return _slot_filled(&"left_ear") and _slot_filled(&"right_ear")
	return true


func _slot_filled(segment_id: StringName) -> bool:
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
const SEGMENT_PLACE_DURATION: float = 0.1


func _accept_segment_into_slot(segment: WorkshopSegment, slot: WorkshopAssemblySlot) -> void:
	if segment == null or slot == null:
		return
	_play_place_sound()
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
	# Unified-outline parts (stomach, chest and its segments) keep their outline art after
	# placement — a back layer repaints it behind all bases — so never strip it here. The
	# hand and the standalone upper arm / forearm share the arm art convention: their
	# outlines are pick-up-only hints, cleared once a piece is placed.
	if _crafted_part_id != "head" and _crafted_part_id != "arm" \
			and _crafted_part_id != "hand" and _crafted_part_id != "upper_arm" \
			and _crafted_part_id != "forearm":
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

## Rebuilds the inventory tray's current page: every ingredient and component the player
## owns, plus their finished limbs (robot parts), which can be dragged back in to be
## disassembled — TRAY_PAGE_SIZE at a time. With `page_turn` the old page dives into the
## bag while the new one flies out of it.
func _populate_ingredients_tray(page_turn: bool = false) -> void:
	var leaving: Array = []
	for child in ingredients_tray.get_children():
		if page_turn and String(child.name).begins_with("Tray_"):
			# Renamed so nothing looks it up as a live tray slot while it animates away.
			child.name = "Leaving_" + String(child.name).trim_prefix("Tray_")
			leaving.append(child)
		elif not String(child.name).begins_with("Leaving_"):
			_remove_and_free(child)

	var ids: Array = _tray_ids()
	var pages: int = maxi(1, ceili(float(ids.size()) / float(TRAY_PAGE_SIZE)))
	_tray_page = posmod(_tray_page, pages)
	var page_ids: Array = ids.slice(_tray_page * TRAY_PAGE_SIZE, (_tray_page + 1) * TRAY_PAGE_SIZE)
	var arriving: Array = []
	for i in page_ids.size():
		var id: String = String(page_ids[i])
		var count: int = _available_count(id)

		var slot := Control.new()
		slot.name = "Tray_" + id
		slot.custom_minimum_size = TRAY_SLOT_SIZE
		slot.size = TRAY_SLOT_SIZE
		slot.position = TRAY_SLOT_CENTERS[i] - TRAY_SLOT_SIZE * 0.5
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ingredients_tray.add_child(slot)
		arriving.append(slot)

		var tile: WorkshopPiece = _make_ingredient_piece(id) if count > 0 else null
		if tile:
			tile.size = TRAY_SLOT_SIZE
			tile.home_parent = slot
			slot.add_child(tile)
			tile.position = Vector2.ZERO

		var badge := Label.new()
		badge.name = "Count"
		badge.text = "x%d" % max(count, 0)
		badge.add_theme_font_size_override("font_size", 10)
		badge.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 3)
		badge.position = Vector2(TRAY_SLOT_SIZE.x - 22, TRAY_SLOT_SIZE.y - 14)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(badge)

	var multi_page: bool = pages > 1
	for btn in [_tray_prev_button, _tray_next_button]:
		if btn != null:
			btn.disabled = not multi_page
			btn.modulate.a = 1.0 if multi_page else 0.4

	# Pieces sitting in the bin go home to their tile (if it's on this page).
	for piece in craft_bin.all_pieces():
		piece.home_parent = ingredients_tray.get_node_or_null("Tray_" + String(piece.item_id)) as Control

	if page_turn:
		_animate_tray_page_turn(leaving, arriving)


## Everything the tray can show, in inventory order: raw ingredients first, then the
## components and finished limbs (the same split as the inventory screen's sections).
func _tray_ids() -> Array:
	var ingredients: Array = []
	var parts: Array = []
	var ids: Array = GameState.ingredients.keys()
	for part_id in GameState.ROBOT_PART_IDS:
		if not ids.has(part_id):
			ids.append(part_id)
	for id_key in ids:
		var id: String = String(id_key)
		if _inventory_count(id) <= 0:
			continue
		if id in InventoryOverlay.INGREDIENT_IDS:
			ingredients.append(id)
		else:
			parts.append(id)
	return ingredients + parts


func _setup_tray_page_buttons() -> void:
	_tray_prev_button = _make_tray_page_button("TrayPrevButton", "<", Vector2.ZERO)
	_tray_next_button = _make_tray_page_button("TrayNextButton", ">", Vector2(TRAY_PAGE_BUTTON_SIZE.x + TRAY_PAGE_BUTTON_GAP, 0.0))


## A small arrow button in the tray's top-left corner. Clicks reach it through the same
## manual hit test as the other workshop buttons (see _handle_left_press).
func _make_tray_page_button(button_name: String, text: String, offset: Vector2) -> Button:
	var btn := Button.new()
	btn.name = button_name
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Same look as the CRAFT / COLLECT buttons.
	btn.theme_type_variation = &"GoldHudButton"
	btn.add_theme_font_size_override("font_size", 11)
	btn.custom_minimum_size = TRAY_PAGE_BUTTON_SIZE
	btn.position = ingredients_tray.position + offset
	add_child(btn)
	# The theme's padding is sized for word buttons; drop it so the arrows stay small squares.
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style: StyleBox = btn.get_theme_stylebox(state)
		if style == null:
			continue
		style = style.duplicate()
		style.set_content_margin_all(0)
		btn.add_theme_stylebox_override(state, style)
	btn.size = TRAY_PAGE_BUTTON_SIZE
	return btn


func _turn_tray_page(step: int) -> void:
	UI_SOUND.play_button_click(self)
	_tray_page += step
	_populate_ingredients_tray(true)


## The old page's slots shrink into the bag's opening while the new page's slots grow out
## of it into place — small at the bag, full size in their slots, eased in and out.
func _animate_tray_page_turn(leaving: Array, arriving: Array) -> void:
	_tray_animating = true
	var mouth: Vector2 = bag_mouth_position - ingredients_tray.position
	var tw: Tween = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var at_bag := Vector2.ONE * TRAY_BAG_SCALE
	# Each tile sets off a beat after the one before, and takes its own time getting there,
	# so the page moves as a scatter of tiles rather than one block.
	for i in leaving.size():
		var slot: Control = leaving[i]
		_lock_tray_slot(slot, true)
		slot.pivot_offset = slot.size * 0.5
		var delay: float = i * TRAY_PAGE_TURN_STAGGER
		var duration: float = _tray_tile_flight_time()
		tw.tween_property(slot, "position", mouth - slot.size * 0.5, duration).set_delay(delay)
		tw.tween_property(slot, "scale", at_bag, duration).set_delay(delay)
	for i in arriving.size():
		var slot: Control = arriving[i]
		var target: Vector2 = slot.position
		_lock_tray_slot(slot, true)
		slot.pivot_offset = slot.size * 0.5
		slot.position = mouth - slot.size * 0.5
		slot.scale = at_bag
		var delay: float = i * TRAY_PAGE_TURN_STAGGER
		var duration: float = _tray_tile_flight_time()
		tw.tween_property(slot, "position", target, duration).set_delay(delay)
		tw.tween_property(slot, "scale", Vector2.ONE, duration).set_delay(delay)
	tw.chain().tween_callback(_finish_tray_page_turn.bind(leaving, arriving))


## One tile's flight time: TRAY_PAGE_TURN_DURATION, varied by up to
## TRAY_PAGE_TURN_TIME_VARIATION either way.
func _tray_tile_flight_time() -> float:
	return TRAY_PAGE_TURN_DURATION * (1.0 + _spawn_rng.randf_range(-TRAY_PAGE_TURN_TIME_VARIATION, TRAY_PAGE_TURN_TIME_VARIATION))


func _finish_tray_page_turn(leaving: Array, arriving: Array) -> void:
	for slot in leaving:
		_remove_and_free(slot)
	for slot in arriving:
		if is_instance_valid(slot):
			_lock_tray_slot(slot, false)
	_tray_animating = false


## Tiles can't be picked up while their slot is flying to or from the bag.
func _lock_tray_slot(slot: Node, locked: bool) -> void:
	if not is_instance_valid(slot):
		return
	for child in slot.get_children():
		if child is WorkshopPiece:
			child.locked = locked


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
	piece.visual_scale = _ingredient_visual_scale(id, piece.texture)
	if id == "head_segments":
		piece.auto_top_center = true

	var shadow_path: String = String(INGREDIENT_SHADOW_PATHS.get(id, ""))
	if shadow_path != "" and ResourceLoader.exists(shadow_path):
		piece.shadow_texture = load(shadow_path)

	return piece


## Id -> visual scale, worked out once per icon.
var _ingredient_scale_cache: Dictionary = {}


func _ingredient_visual_scale(id: String, tex: Texture2D) -> float:
	if _ingredient_scale_cache.has(id):
		return _ingredient_scale_cache[id]
	var cap: float = _icon_longest_side(String(INGREDIENT_PATHS.get(INGREDIENT_SIZE_REFERENCE_ID, "")))
	var used: Vector2 = _used_rect_for_texture(tex).size
	var longest: float = maxf(used.x, used.y)
	var scale_value: float = float(INGREDIENT_VISUAL_SCALES.get(id, 1.0))
	if cap > 0.0 and longest * scale_value > cap:
		scale_value = cap / longest
	_ingredient_scale_cache[id] = scale_value
	return scale_value


func _icon_longest_side(path: String) -> float:
	if path == "" or not ResourceLoader.exists(path):
		return 0.0
	var used: Vector2 = _used_rect_for_texture(load(path)).size
	return maxf(used.x, used.y)


func _maybe_replace_tray_tile(id: String, source_slot: Control) -> void:
	if source_slot == null or not is_instance_valid(source_slot):
		return
	if not String(source_slot.name).begins_with("Tray_"):
		return  # a page that's diving into the bag
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


## What's left of `id` in the inventory once the pieces out of it are counted: in the bin,
## in the limb being built, or in hand being dragged.
func _available_count(id: String) -> int:
	var total: int = _inventory_count(id)
	for piece in craft_bin.all_pieces():
		if String(piece.item_id) == id:
			total -= 1
	if _limb_mode():
		for key in _limb_components:
			if _component_item_id(key) == id:
				total -= 1
	for held in [_active_drag_piece, _carry_piece]:
		if held == null or not is_instance_valid(held) or String(held.item_id) != id:
			continue
		if not (held == _carry_piece and _carrying_limb):
			total -= 1
	return total


func _refresh_tray_counts(remove_depleted_slots: bool = false) -> void:
	for slot in ingredients_tray.get_children():
		if not String(slot.name).begins_with("Tray_"):
			continue
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
		var tile: WorkshopPiece = null
		for child in slot.get_children():
			if child is WorkshopPiece:
				tile = child
				break
		if tile == null and available > 0:
			_maybe_replace_tray_tile(id, slot)
		elif tile != null and available <= 0:
			# Everything of this item is out of the inventory now (in the bin or the limb).
			_remove_and_free(tile)


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
## directory of per-segment PNGs, mirroring the arm setup - or, when
## `packed_layers` is given, from a packed sheet's layers (layer name -> texture),
## falling back to the directory for any layer the sheet lacks. Each segment is
## one draggable piece with its "<id>_outline" loaded alongside (and, with `installed_suffix`,
## its "<id><installed_suffix>" art for once it's installed). When `unified_outline` is
## true an OutlineLayer is inserted behind every slot so placed pieces' outlines render as
## one block behind all the base art (matching the authored Aseprite layering) — or, when
## `outline_layer_above` names a segment, just above that segment's slot instead.
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
	packed_layers: Dictionary = {},
	installed_suffix: String = "",
	outline_layer_above: StringName = &"",
) -> Control:
	var node := Control.new()
	node.name = assembly_name
	node.size = assembly_size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.visible = false

	var outline_layer: Control = null
	if unified_outline:
		outline_layer = Control.new()
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
		var tex: Texture2D = _segment_layer_texture(texture_dir, packed_layers, String(segment_id))
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
		if outline_layer != null and segment_id == outline_layer_above:
			node.move_child(outline_layer, node.get_child_count() - 1)
		_assembly_slots[seg_key] = slot
		out_slot_ids.append(seg_key)
		var installed: Texture2D = null
		if installed_suffix != "":
			installed = _segment_layer_texture(texture_dir, packed_layers, String(segment_id) + installed_suffix)
		_segments[seg_key] = {
			"pieces": [
				{
					"id": seg_key,
					"texture": tex,
					"outline": _segment_layer_texture(texture_dir, packed_layers, "%s_outline" % segment_id),
					"installed": installed,
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


## One assembly layer: from the packed sheet's layers when it has it, otherwise
## the per-segment PNG in `texture_dir` (null when neither exists).
func _segment_layer_texture(texture_dir: String, packed_layers: Dictionary, layer_name: String) -> Texture2D:
	if packed_layers.has(layer_name):
		return packed_layers[layer_name]
	return _load_texture("%s/%s.png" % [texture_dir, layer_name])


## The torso sheet's layers plus the chest's ribs (see _chest_ribs_layer), with every
## plating piece given its own "<id>_outline": the part of the authored chest outlines
## (CHEST_OUTLINE_LAYERS) within CHEST_OUTLINE_REACH pixels of that piece. So a component
## placed on its own is outlined round just its pieces, and the finished plating looks
## exactly as authored.
func _chest_layers(torso_layers: Dictionary) -> Dictionary:
	var layers := torso_layers.duplicate()
	var size := Vector2i(CHEST_ASSEMBLY_SIZE)
	var ribs := _chest_ribs_layer(torso_layers)
	if ribs != null:
		layers["ribs"] = ribs
	var outlines := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for layer_name in CHEST_OUTLINE_LAYERS:
		var tex: Texture2D = torso_layers.get(layer_name)
		if tex != null:
			var src: Image = tex.get_image()
			outlines.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i.ZERO)
	# Every plating piece's art together, to find where one piece meets another.
	var plating := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for segment_id in CHEST_SEGMENT_IDS:
		var tex: Texture2D = torso_layers.get(String(segment_id))
		if tex != null:
			var src: Image = tex.get_image()
			plating.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i.ZERO)
	for segment_id in CHEST_SEGMENT_IDS:
		var tex: Texture2D = torso_layers.get(String(segment_id))
		if tex == null:
			continue  # (the ribs aren't in the sheet and bring their own outline)
		var img: Image = tex.get_image()
		var used: Rect2i = img.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var reach: Rect2i = used.grow(CHEST_OUTLINE_REACH).intersection(Rect2i(Vector2i.ZERO, size))
		var near := BitMap.new()
		near.create_from_image_alpha(img, 0.1)
		near.grow_mask(CHEST_OUTLINE_REACH, reach)
		var seam := BitMap.new()
		seam.create_from_image_alpha(img, 0.1)
		seam.grow_mask(CHEST_SEAM_OUTLINE_WIDTH, reach)
		var own := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
		for y in range(reach.position.y, reach.end.y):
			for x in range(reach.position.x, reach.end.x):
				if not near.get_bit(x, y):
					continue
				var c: Color = outlines.get_pixel(x, y)
				if c.a > 0.0:
					own.set_pixel(x, y, c)
				elif seam.get_bit(x, y) and img.get_pixel(x, y).a <= 0.1 \
						and plating.get_pixel(x, y).a > 0.1:
					own.set_pixel(x, y, CHEST_SEAM_OUTLINE_COLOR)
		layers["%s_outline" % segment_id] = ImageTexture.create_from_image(own)
	return layers


## The rib cage's art on the chest's canvas, centred on the chest plating so the plating
## closes over it. Null if either is missing.
func _chest_ribs_layer(torso_layers: Dictionary) -> Texture2D:
	if not ResourceLoader.exists(CHEST_RIBS_TEXTURE_PATH):
		return null
	var ribs: Image = (load(CHEST_RIBS_TEXTURE_PATH) as Texture2D).get_image()
	if ribs.is_compressed():
		ribs.decompress()
	ribs.convert(Image.FORMAT_RGBA8)
	var plating := Rect2()
	for segment_id in CHEST_SEGMENT_IDS:
		var tex: Texture2D = torso_layers.get(String(segment_id))
		if tex == null:
			continue
		var used: Rect2 = _used_rect_for_texture(tex)
		plating = used if plating.size == Vector2.ZERO else plating.merge(used)
	if plating.size == Vector2.ZERO:
		return null
	var ribs_used := Rect2(ribs.get_used_rect())
	var offset := Vector2i((plating.get_center() - ribs_used.get_center()).round()) + CHEST_RIBS_OFFSET
	var size := Vector2i(CHEST_ASSEMBLY_SIZE)
	var canvas := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(ribs, Rect2i(Vector2i.ZERO, ribs.get_size()), offset)
	return ImageTexture.create_from_image(canvas)


## The torso sheet's layers plus the stomach's metal shell, re-centred (and bottom-aligned)
## under the outer-skin pieces on their larger canvas, so the outer plating craft can lay the
## shell down first and the skin over it.
func _outer_plating_layers(torso_layers: Dictionary, stomach_layers: Dictionary) -> Dictionary:
	var layers := torso_layers.duplicate()
	var shell: Texture2D = stomach_layers.get("metal_shell")
	if shell == null:
		return layers
	var skin_bounds := Rect2()
	for segment_id in OUTER_PLATING_SEGMENT_IDS:
		var tex: Texture2D = torso_layers.get(String(segment_id))
		if tex == null:
			continue
		var used: Rect2 = _used_rect_for_texture(tex)
		skin_bounds = used if skin_bounds.size == Vector2.ZERO else skin_bounds.merge(used)
	var shell_used: Rect2 = _used_rect_for_texture(shell)
	var offset := Vector2i(
		roundi(skin_bounds.get_center().x - shell_used.get_center().x),
		roundi(skin_bounds.end.y - shell_used.end.y))
	var canvas := Image.create_empty(int(OUTER_PLATING_ASSEMBLY_SIZE.x), int(OUTER_PLATING_ASSEMBLY_SIZE.y), false, Image.FORMAT_RGBA8)
	var src: Image = shell.get_image()
	canvas.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), offset)
	layers["metal_shell"] = ImageTexture.create_from_image(canvas)
	return layers


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
	# The leg / arm / chest assemblies are reused by their segment crafts (a segment just
	# activates a subset of the parent's slots), so those parts share the parent's visibility.
	var leg_parts := ["leg", "thigh", "shin", "foot"]
	var arm_parts := ["arm", "upper_arm", "forearm"]
	var chest_parts := ["chest", "ribcage", "upper_plating", "lower_plating"]
	var stomach_parts := ["stomach", "tank", "pump", "huge_battery", "external"]
	var leg_node := assembly.get_node_or_null("AssemblyLeg") as CanvasItem
	if leg_node != null:
		leg_node.visible = part_id == "" or part_id in leg_parts
	if _head_assembly != null:
		_head_assembly.visible = part_id == "head"
	if _arm_assembly != null:
		_arm_assembly.visible = part_id in arm_parts
	if _hand_assembly != null:
		_hand_assembly.visible = part_id == "hand"
	if _stomach_assembly != null:
		_stomach_assembly.visible = part_id in stomach_parts
	if _outer_plating_assembly != null:
		_outer_plating_assembly.visible = part_id == "outer_plating"
	if _chest_assembly != null:
		_chest_assembly.visible = part_id in chest_parts

	_active_assembly_slot_ids.clear()
	if part_id == "head":
		_append_active_slots(HEAD_SEGMENT_IDS)
	elif part_id == "arm":
		_append_active_slots(ARM_SEGMENT_IDS)
	elif part_id == "upper_arm":
		# Only the upper-arm segments (shoulder, bicep, tricep, upper-arm plates,
		# elbow) — the forearm slots stay inactive, so they neither spawn nor gate
		# completion.
		_append_active_slots(UPPER_ARM_SEGMENT_IDS)
	elif part_id == "forearm":
		# The complementary subset: only the wrist / forearm slots.
		_append_active_slots(FOREARM_SEGMENT_IDS)
	elif part_id == "hand":
		_active_assembly_slot_ids.assign(_hand_assembly_slot_ids)
	elif part_id == "stomach":
		_active_assembly_slot_ids.assign(_stomach_assembly_slot_ids)
	elif part_id in stomach_parts:
		# A stomach component on its own: just its slice of the stomach assembly.
		var ids: Array[StringName] = []
		ids.assign(STOMACH_COMPONENT_SLOTS.get(StringName(part_id), []))
		_append_active_slots(ids)
	elif part_id == "outer_plating":
		_active_assembly_slot_ids.assign(_outer_plating_assembly_slot_ids)
	elif part_id == "chest":
		_active_assembly_slot_ids.assign(_chest_assembly_slot_ids)
	elif part_id in chest_parts:
		# A chest component on its own: just its share of the chest's plating.
		var ids: Array[StringName] = []
		ids.assign(COMPONENT_SLOT_GROUPS.get(StringName(part_id), []))
		_append_active_slots(ids)
	elif part_id == "leg":
		_active_assembly_slot_ids.assign(_leg_assembly_slot_ids)
	elif part_id == "thigh":
		_append_active_slots(LEG_THIGH_SEGMENT_IDS)
	elif part_id == "shin":
		_append_active_slots(LEG_SHIN_SEGMENT_IDS)
	elif part_id == "foot":
		_append_active_slots(LEG_FOOT_SEGMENT_IDS)

	_queue_unified_outline_redraw()


## Appends whichever of `ids` actually have a harvested assembly slot to the active set.
func _append_active_slots(ids: Array[StringName]) -> void:
	for id in ids:
		if _assembly_slots.has(id):
			_active_assembly_slot_ids.append(id)


# --- craft ---

func _refresh_craft_button() -> void:
	if _crafted:
		craft_button.disabled = true
		return
	var limb_id := _disassemble_target()
	if limb_id != "":
		craft_button.disabled = false
		craft_button.text = "DISASSEMBLE %s" % _part_display_name(limb_id).to_upper()
		return
	# A limb being built holds the assembly area, so nothing else can be crafted into it.
	var part_id := "" if _limb_mode() else _matching_recipe_part_id()
	craft_button.disabled = part_id == ""
	craft_button.text = "CRAFT" if part_id == "" else "CRAFT %s" % _part_display_name(part_id).to_upper()


func _bin_has_recipe() -> bool:
	return _matching_recipe_part_id() != ""


func _matching_recipe_part_id() -> String:
	var counts: Dictionary = craft_bin.count_items()
	if not forced_part_id.strip_edges().is_empty():
		if CRAFTABLE_PARTS.get(forced_part_id, {}).is_empty():
			return ""
		return forced_part_id if not _part_consumption(counts, forced_part_id).is_empty() else ""
	# The bin only crafts flat recipes (components, the head, the hand) — limbs are built
	# in the assembly area. If several are satisfied, the biggest recipe wins.
	var best_id: String = ""
	var best_weight: int = -1
	for part_id in CRAFTABLE_PARTS:
		if _part_consumption(counts, String(part_id)).is_empty():
			continue
		var weight: int = _recipe_weight(CRAFTABLE_PARTS[part_id].get("recipe", {}))
		if weight > best_weight:
			best_weight = weight
			best_id = String(part_id)
	return best_id


## True when `counts` holds at least every quantity in `recipe`.
func _counts_contain_recipe(counts: Dictionary, recipe: Dictionary) -> bool:
	for id_key in recipe:
		if int(counts.get(String(id_key), 0)) < int(recipe[id_key]):
			return false
	return true


## What crafting `part_id` in the bin would consume from `counts` (its flat recipe), or an
## empty dict if the bin can't satisfy it. Composite limbs never craft in the bin.
func _part_consumption(counts: Dictionary, part_id: String) -> Dictionary:
	var data: Dictionary = CRAFTABLE_PARTS.get(part_id, {})
	if data.is_empty() or data.has("segments"):
		return {}
	var recipe: Dictionary = data.get("recipe", {})
	if recipe.is_empty() or not _counts_contain_recipe(counts, recipe):
		return {}
	return recipe.duplicate()


## Total number of ingredients a flat recipe requires (sum of its quantities).
func _recipe_weight(recipe: Dictionary) -> int:
	var total: int = 0
	for id_key in recipe:
		total += int(recipe[id_key])
	return total


func _part_display_name(part_id: String) -> String:
	var part_data: Dictionary = CRAFTABLE_PARTS.get(part_id, {})
	return String(part_data.get("display_name", part_id))


func _on_craft_pressed() -> void:
	if _crafted:
		return
	var limb_id := _disassemble_target()
	if limb_id != "":
		_disassemble_limb(limb_id)
		return
	if _limb_mode():
		return
	var part_id := _matching_recipe_part_id()
	if part_id == "":
		return
	_crafted = true
	_crafted_part_id = part_id

	var consumption: Dictionary = _part_consumption(craft_bin.count_items(), _crafted_part_id)
	_consume_recipe_pieces(consumption)
	craft_bin.output_mode = true
	_configure_assembly_for_part(_crafted_part_id)

	# A one-piece part (rib cage, tank, huge battery) has nothing to assemble: it goes
	# straight into the inventory, ready to drop into the assembly with the rest of its limb.
	if _active_assembly_slot_ids.size() == 1 and not _is_tutorial_workshop():
		var yields: Dictionary = CRAFTABLE_PARTS.get(part_id, {}).get("yields", {part_id: 1})
		for id in yields:
			_add_to_inventory(String(id), int(yields[id]))
		_play_place_sound()
		_reset_workshop()
		collected.emit(part_id)
		return

	_spawn_segments_stacked_at_bin_center()

	_refresh_tray_counts(true)
	craft_button.disabled = true
	craft_button.text = "CRAFTED %s" % _part_display_name(_crafted_part_id).to_upper()
	collect_button.visible = true
	collect_button.text = "COLLECT %s" % _part_display_name(_crafted_part_id).to_upper()

	# Flash every segment's target once so the player isn't placing blind — a
	# single pulse regardless of the Easy Workshop setting. Deferred so the
	# freshly-spawned segments have settled into the bin (and their global
	# transforms are valid) before we read them.
	call_deferred("_flash_all_placement_hints_once")


func _consume_recipe_pieces(recipe: Dictionary) -> void:
	var consumed_pieces: Array[WorkshopPiece] = []
	for id_key in recipe:
		var id: String = String(id_key)
		var need: int = int(recipe[id_key])
		_add_to_inventory(id, -need)

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
	if piece.home_parent == null or not is_instance_valid(piece.home_parent):
		piece.queue_free()
		return
	# If the home bag slot is empty, glide the piece back into it (snap_home animates and it
	# stays). If the slot already holds a restamped tile, still fly the leftover back to that
	# slot for the visual, then remove it — the stamped tile already represents the stack.
	for child in piece.home_parent.get_children():
		if child is WorkshopPiece and child != piece:
			_slide_piece_to_bag_and_free(piece)
			return
	piece.snap_home()


## Fly an unused piece from wherever it sits back to its bag (tray) slot, then free it. Runs
## on a high layer so it glides over the rest of the UI instead of clipping inside the bin.
func _slide_piece_to_bag_and_free(piece: WorkshopPiece) -> void:
	var home: Control = piece.home_parent
	var target_global: Vector2 = home.get_global_transform().origin + (home.size - piece.size) * 0.5
	var gpos: Vector2 = piece.global_position
	var parent: Node = piece.get_parent()
	if parent != null:
		parent.remove_child(piece)
	add_child(piece)
	piece.global_position = gpos
	piece.z_index = 300
	var tw: Tween = piece.create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(piece, "global_position", target_global, 0.2)
	tw.tween_callback(piece.queue_free)


## A fresh draggable segment for `seg_id` (one piece per authored layer), sized to its
## visible art; null when none of its pieces has a texture.
func _build_segment(seg_id: StringName) -> WorkshopSegment:
	var pieces_defs: Array = _segments.get(seg_id, {}).get("pieces", [])
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
		return null

	for child in segment.get_children():
		if child is WorkshopPiece:
			child.position -= bounds.position
	segment.size = bounds.size
	segment.placement_offset = bounds.position
	return segment


func _spawn_segments_stacked_at_bin_center() -> void:
	var segments_by_id: Dictionary = {} 
	var output_parent: Control = craft_bin

	var spawn_order: Array[StringName] = _spawn_segment_order()
	for seg_id in spawn_order:
		if not _active_assembly_slot_ids.has(seg_id):
			continue
		var segment := _build_segment(seg_id)
		if segment == null:
			continue
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


func _setup_place_audio() -> void:
	_place_rng.randomize()
	_place_sounds.clear()
	for path in PLACE_SOUND_PATHS:
		var stream := load(path) as AudioStream
		if stream != null:
			_place_sounds.append(stream)
	if _place_sounds.is_empty():
		return
	_place_audio_player = AudioStreamPlayer.new()
	_place_audio_player.name = "PlaceAudioPlayer"
	_place_audio_player.volume_db = linear_to_db(GameState.DEFAULT_SFX_VOLUME_SCALE)
	add_child(_place_audio_player)


## Random metal thunk (±PLACE_PITCH_VARIATION_PERCENT pitch) when a segment lands
## in its slot — the same cue the work-scene arm assembly plays.
func _play_place_sound() -> void:
	if _place_audio_player == null or _place_sounds.is_empty():
		return
	_place_audio_player.stream = _place_sounds[_place_rng.randi_range(0, _place_sounds.size() - 1)]
	var percent := _place_rng.randi_range(-PLACE_PITCH_VARIATION_PERCENT, PLACE_PITCH_VARIATION_PERCENT)
	_place_audio_player.pitch_scale = 1.0 + float(percent) / 100.0
	_place_audio_player.play()


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
	elif _crafted_part_id == "outer_plating":
		order.erase(OUTER_PLATING_SHELL_SLOT)
		order.append(OUTER_PLATING_SHELL_SLOT)
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
	if piece_def.get("installed") != null:
		piece.set_meta(&"installed_texture", piece_def.get("installed"))

	piece.piece_offset = Vector2.ZERO
	piece.visual_offset = Vector2.ZERO
	piece.shadow_offset = Vector2.ZERO
	piece.auto_center = false

	piece.size = tex.get_size()

	return piece


# --- collect ---

func _refresh_collect_button() -> void:
	collect_button.disabled = not _is_assembly_complete()


## True once the part is fully built and just waiting on COLLECT: every active slot filled
## for a crafted part, or every required component in for a limb being built.
func _is_assembly_complete() -> bool:
	if _limb_mode():
		for seg_id in CRAFTABLE_PARTS[_crafted_part_id].get("segments", []):
			if not _limb_components.has(StringName(seg_id)):
				return false
		return true
	if _active_assembly_slot_ids.is_empty():
		return false
	for slot_id in _active_assembly_slot_ids:
		var slot: WorkshopAssemblySlot = _assembly_slots.get(slot_id)
		if slot == null or not slot.filled:
			return false
	return true


## Puts the finished part in the inventory and stays in the workshop, ready for the next
## build. (The guided intro instead hands the head to the location, which ends it.)
func _on_collect_pressed() -> void:
	if _crafted_part_id == "" or not _is_assembly_complete():
		return
	var part_id := _crafted_part_id
	if _is_tutorial_workshop():
		collected.emit(part_id)
		return
	if _limb_mode():
		# Noted so disassembling it gives back exactly these (see _disassemble_limb).
		var components: Array[String] = []
		for key in _limb_components:
			var item_id := _component_item_id(key)
			_add_to_inventory(item_id, -1)
			components.append(item_id)
		GameState.record_limb_build(part_id, components)
		_add_to_inventory(part_id, 1)
	else:
		var yields: Dictionary = CRAFTABLE_PARTS.get(part_id, {}).get("yields", {part_id: 1})
		for id in yields:
			_add_to_inventory(String(id), int(yields[id]))
	_play_place_sound()
	_reset_workshop()
	collected.emit(part_id)


## Clears the assembly area and the craft output so the next part can be built.
func _reset_workshop() -> void:
	_clear_placement_hints()
	for slot_id in _assembly_slots:
		var slot: WorkshopAssemblySlot = _assembly_slots[slot_id]
		if slot.filled:
			slot.filled = false
			slot.queue_redraw()
	var segments: Array = []
	_collect_segments(self, segments)
	for segment in segments:
		_remove_and_free(segment)
	_limb_components.clear()
	_limb_component_nodes.clear()
	_crafted = false
	_crafted_part_id = ""
	craft_bin.output_mode = false
	_configure_assembly_for_part("")
	collect_button.visible = false
	collect_button.disabled = true
	_rebuild_tray()


func _remove_and_free(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()


# --- inventory ---

## How many of `id` the player owns: limbs are robot parts, everything else an ingredient.
func _inventory_count(id: String) -> int:
	if GameState.is_robot_part_id(id):
		return GameState.get_robot_part_count(id)
	return int(GameState.ingredients.get(id, 0))


func _add_to_inventory(id: String, amount: int) -> void:
	if GameState.is_robot_part_id(id):
		GameState.add_robot_part(id, amount)
		return
	# Older saves lack the newer component ids; add_ingredient only takes known ones.
	if not GameState.ingredients.has(id):
		GameState.ingredients[id] = 0
	GameState.add_ingredient(id, amount)


func _rebuild_tray() -> void:
	_populate_ingredients_tray()
	_refresh_craft_button()


# --- limb building ---

## True while a limb is being built from components in the assembly area.
func _limb_mode() -> bool:
	return not _crafted and _crafted_part_id != ""


## The limb a finished component belongs to ("" if it isn't one).
func _limb_for_component(id: String) -> String:
	for part_id in CRAFTABLE_PARTS:
		var data: Dictionary = CRAFTABLE_PARTS[part_id]
		if (data.get("segments", []) as Array).has(id) or (data.get("optional_segments", []) as Array).has(id):
			return String(part_id)
	return ""


## The component a finished item dropped on the assembly area at `global_pos` would become
## (&"" if it can't go in right now): only when nothing is being crafted there, only into the
## limb already started (or any limb if it's empty), and only into a spot still free. Most
## items are their own component; a tank becomes the stomach side it was dropped on.
func _limb_component_key(id: String, global_pos: Vector2) -> StringName:
	if _crafted or _is_tutorial_workshop():
		return &""
	var limb := _limb_for_component(id)
	if limb == "" or (_crafted_part_id != "" and _crafted_part_id != limb):
		return &""
	var key := StringName(id)
	if limb == "stomach" and key == &"tank":
		key = _stomach_tank_side(global_pos)
	if key == &"" or _limb_components.has(key):
		return &""
	if limb == "stomach" and not _stomach_component_fits(key):
		return &""
	return key


## The stomach tank side (left_tank / right_tank) whose slot is nearest `global_pos`.
func _stomach_tank_side(global_pos: Vector2) -> StringName:
	var best: StringName = &""
	var best_distance: float = INF
	for side in STOMACH_TANK_SIDES:
		var slot: WorkshopAssemblySlot = _assembly_slots.get(StringName(STOMACH_SLOT_PREFIX + String(side)))
		if slot == null:
			continue
		var center: Vector2 = slot.get_global_transform() * slot.hitbox_rect.get_center()
		var distance: float = global_pos.distance_squared_to(center)
		if distance < best_distance:
			best_distance = distance
			best = side
	return best


## The inventory item a placed component stands for (a stomach tank side is a "tank").
func _component_item_id(key: StringName) -> String:
	return "tank" if STOMACH_TANK_SIDES.has(key) else String(key)


## The pelvis (metal shell) goes in first. After it the outer plating can go on at any time,
## and the internals fit only while the plating is still off (it would hide them).
func _stomach_component_fits(id: StringName) -> bool:
	if id == &"pelvis":
		return true
	if not _limb_components.has(&"pelvis"):
		return false
	return id == &"outer_plating" or not _limb_components.has(&"outer_plating")


## Can this placed component be lifted back out? A stomach comes apart in reverse: the
## plating first, then the internals, and the shell last.
func _can_remove_limb_component(id: StringName) -> bool:
	if _crafted_part_id != "stomach" or id == &"outer_plating":
		return true
	if _limb_components.has(&"outer_plating"):
		return false
	return id != &"pelvis" or _limb_components.size() == 1


func _add_limb_component(id: StringName) -> void:
	if _crafted_part_id == "":
		_crafted_part_id = _limb_for_component(_component_item_id(id))
		_configure_assembly_for_part(_crafted_part_id)
		collect_button.visible = true
		collect_button.text = "COLLECT %s" % _part_display_name(_crafted_part_id).to_upper()
	_limb_components.append(id)
	var nodes: Array = []
	for slot_id in _component_slot_ids(id):
		var segment := _place_segment_for_slot(StringName(slot_id))
		if segment != null:
			nodes.append(segment)
	_limb_component_nodes[id] = nodes
	_play_place_sound()
	_after_limb_change()


func _remove_limb_component(id: StringName) -> void:
	for node in _limb_component_nodes.get(id, []):
		_unplace(node)
	_limb_component_nodes.erase(id)
	_limb_components.erase(id)
	if _limb_components.is_empty():
		_crafted_part_id = ""
		_configure_assembly_for_part("")
		collect_button.visible = false
	_after_limb_change()


func _after_limb_change() -> void:
	_refresh_collect_button()
	_refresh_tray_counts()
	_refresh_craft_button()
	_queue_unified_outline_redraw()


func _component_slot_ids(id: StringName) -> Array:
	if _crafted_part_id == "stomach":
		return (STOMACH_COMPONENT_SLOTS.get(id, []) as Array).filter(
			func(slot_id): return not STOMACH_UNINSTALLED_ONLY_SLOTS.has(slot_id))
	return COMPONENT_SLOT_GROUPS.get(id, [])


## Builds the segment for `slot_id` and drops it straight into its slot, showing its
## installed art where it has some (the stomach internals).
func _place_segment_for_slot(slot_id: StringName) -> WorkshopSegment:
	var slot: WorkshopAssemblySlot = _assembly_slots.get(slot_id)
	if slot == null or slot.filled:
		return null
	var segment := _build_segment(slot_id)
	if segment == null:
		return null
	slot.accept_segment(segment)
	_clear_placed_part_outline(segment, slot)
	_apply_installed_art(segment)
	return segment


## Swaps each piece to how it looks installed (its "_internals" layer), when it has one.
func _apply_installed_art(segment: WorkshopSegment) -> void:
	for child in segment.get_children():
		var piece := child as WorkshopPiece
		if piece != null and piece.has_meta(&"installed_texture"):
			piece.texture = piece.get_meta(&"installed_texture")
			piece.queue_redraw()


## Takes a placed segment back out of the assembly area.
func _unplace(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var slot := node.get_parent() as WorkshopAssemblySlot
	if slot != null:
		slot.filled = false
		slot.queue_redraw()
	_remove_and_free(node)


## The topmost placed component under `global_pos` (&"" if none) — checked newest first,
## so a stomach's plating wins over what it covers.
func _limb_component_at(global_pos: Vector2) -> StringName:
	for i in range(_limb_components.size() - 1, -1, -1):
		var id: StringName = _limb_components[i]
		for node in _limb_component_nodes.get(id, []):
			if node is WorkshopSegment and _segment_opaque_at(node, global_pos):
				return id
	return &""


## True when any placed piece of the part being built has visible art under `global_pos`.
func _assembly_opaque_at(global_pos: Vector2) -> bool:
	if _limb_mode():
		return _limb_component_at(global_pos) != &""
	for slot_id in _active_assembly_slot_ids:
		var slot: WorkshopAssemblySlot = _assembly_slots.get(slot_id)
		if slot == null:
			continue
		for child in slot.get_children():
			if child is WorkshopSegment and _segment_opaque_at(child, global_pos):
				return true
	return false


func _segment_opaque_at(segment: WorkshopSegment, global_pos: Vector2) -> bool:
	for child in segment.get_children():
		var piece := child as WorkshopPiece
		if piece == null or piece.texture == null or not piece.is_visible_in_tree():
			continue
		var local: Vector2 = piece.get_global_transform().affine_inverse() * global_pos
		var tex_pos: Vector2 = (local - piece.texture_draw_position()) / maxf(0.001, piece.visual_scale)
		var img: Image = piece.texture.get_image()
		if img == null:
			continue
		if img.is_compressed():
			img.decompress()
		var px := Vector2i(tex_pos.floor())
		if px.x < 0 or px.y < 0 or px.x >= img.get_width() or px.y >= img.get_height():
			continue
		if img.get_pixelv(px).a > 0.1:
			return true
	return false


## Press in the assembly area: a finished part is lifted whole (drop it on the inventory to
## collect it); while a limb is being built, the component under the cursor is lifted back
## out instead.
func _try_pick_up_from_assembly(global_pos: Vector2) -> bool:
	if _is_tutorial_workshop() or _crafted_part_id == "":
		return false
	if not assembly.get_global_rect().has_point(global_pos):
		return false
	if _is_assembly_complete():
		if not _assembly_opaque_at(global_pos):
			return false
		_start_carry(_crafted_part_id, global_pos, true)
		return true
	if not _limb_mode():
		return false
	var id := _limb_component_at(global_pos)
	if id == &"":
		return false
	if not _can_remove_limb_component(id):
		UI_SOUND.play_inaccessible_button(self)
		return true
	_remove_limb_component(id)
	_start_carry(_component_item_id(id), global_pos, false)
	return true


func _start_carry(id: String, global_pos: Vector2, whole_part: bool) -> void:
	var piece := _make_ingredient_piece(id)
	if piece == null:
		return
	piece.size = Vector2(40, 40)
	add_child(piece)
	piece.global_position = global_pos - piece.size * 0.5
	_carry_piece = piece
	_carrying_limb = whole_part
	piece.start_drag(global_pos)
	if whole_part:
		# The finished part fades while it's being carried off.
		assembly.modulate.a = 0.45
	_refresh_tray_counts()


## Drop what's being carried out of the assembly area. A finished part collects when it
## lands on the inventory. A lifted component goes back into the limb, into the craft bin,
## or (anywhere else) back to the inventory.
func _finish_carry(global_pos: Vector2) -> void:
	var piece := _carry_piece
	var id: String = String(piece.item_id)
	var was_limb := _carrying_limb
	_carry_piece = null
	_carrying_limb = false
	piece.end_drag()
	assembly.modulate.a = 1.0
	if was_limb:
		_remove_and_free(piece)
		if ingredients_tray.get_global_rect().has_point(global_pos):
			_on_collect_pressed()
		return
	var key: StringName = &""
	if assembly.get_global_rect().has_point(global_pos):
		key = _limb_component_key(id, global_pos)
	if key != &"":
		_remove_and_free(piece)
		_add_limb_component(key)
		return
	if craft_bin.accepts_point(global_pos):
		piece.home_parent = ingredients_tray.get_node_or_null("Tray_" + id) as Control
		_drop_into_bin(piece, global_pos)
		_refresh_tray_counts()
		return
	_remove_and_free(piece)
	_refresh_tray_counts()


# --- disassembly ---

## Finished limbs that can be taken apart in the craft bin (not the head, yet).
const DISASSEMBLABLE_PARTS: Array[String] = ["arm", "leg", "chest", "stomach"]
## How far the parts of a disassembled limb spread out from the middle of the bin.
const DISASSEMBLE_SPREAD_RADIUS: float = 52.0
const DISASSEMBLE_POP_DURATION: float = 0.18


## The limb in the craft bin waiting to be disassembled ("" if none).
func _disassemble_target() -> String:
	if _crafted or _is_tutorial_workshop():
		return ""
	var counts: Dictionary = craft_bin.count_items()
	for id in DISASSEMBLABLE_PARTS:
		if int(counts.get(id, 0)) >= 1:
			return id
	return ""


## Breaks a finished limb in the bin back into the components it was built from, which pop
## out into the bin ready to rebuild in the assembly area (or drag back to the inventory).
## What comes back is the limb's build list (see GameState.limb_builds), so a stomach only
## returns the tanks / pump / battery / external that were really in it. A limb with no
## list (bought, rewarded, or built before lists were kept) returns its required segments.
func _disassemble_limb(limb_id: String) -> void:
	var pieces: Array = craft_bin.pieces_with_id(StringName(limb_id))
	if pieces.is_empty():
		return
	var limb_piece: WorkshopPiece = pieces[0]
	var origin: Vector2 = limb_piece.position + limb_piece.size * 0.5
	var components: Array[String] = GameState.take_limb_build(limb_id)
	if components.is_empty():
		components.assign(CRAFTABLE_PARTS[limb_id].get("segments", []))
	_remove_and_free(limb_piece)
	_add_to_inventory(limb_id, -1)
	for i in components.size():
		_add_to_inventory(components[i], 1)
		_spawn_disassembled_piece(components[i], origin, i, components.size())
	_play_place_sound()
	craft_bin.contents_changed.emit()
	_rebuild_tray()


## One component of a disassembled limb, popping out of where the limb sat (`origin`, bin
## local) to its place in a ring around the middle of the bin.
func _spawn_disassembled_piece(id: String, origin: Vector2, index: int, total: int) -> void:
	var piece := _make_ingredient_piece(id)
	if piece == null:
		return
	piece.size = TRAY_SLOT_SIZE
	craft_bin.add_child(piece)
	var target: Vector2 = craft_bin.local_center()
	if total > 1:
		target += Vector2.UP.rotated(TAU * float(index) / float(total)) * DISASSEMBLE_SPREAD_RADIUS
	target -= piece.size * 0.5
	target.x = clampf(target.x, 0.0, maxf(0.0, craft_bin.size.x - piece.size.x))
	target.y = clampf(target.y, 0.0, maxf(0.0, craft_bin.size.y - piece.size.y))
	piece.position = origin - piece.size * 0.5
	var tw: Tween = piece.create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(piece, "position", target, DISASSEMBLE_POP_DURATION)


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
