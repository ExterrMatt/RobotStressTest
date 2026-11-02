extends LocationBase

const RobotHoverBox: GDScript = preload("res://scenes/locations/RobotHoverBox.gd")
const LAPTOP_SCENE: PackedScene = preload("res://scenes/locations/Laptop.tscn")

const PAN_DURATION: float = 0.35
const PAN_TRANS: int = Tween.TRANS_SINE
const PAN_EASE: int = Tween.EASE_IN_OUT
const BASE_SCENE_SIZE: Vector2 = Vector2(500.0, 400.0)
## The room art is a packed Aseprite sheet (Split Layers + Trim); Background shows its
## layers flattened back into the 500x400 room.
const BACKGROUND_SHEET_PATH: String = "res://assets/textures/backgrounds/maintenance.png"
const BACKGROUND_SHEET_JSON_PATH: String = "res://assets/textures/backgrounds/maintenance.json"
## Layers left out of the flattened room: the white outline around the hazard door
## reads as a highlight, not part of the room.
const BACKGROUND_SKIPPED_LAYERS: Array[String] = ["white_exit_door"]
const ZOOM_MULTIPLIER: float = 2.0
const SCROLL_STEP_VIEW_FRACTION: float = 0.5
## The oil (motor oil can) item. Held over the robot it pours, draining a reservoir.
const OIL_ITEM_ID: StringName = &"buff_shine"
## Oil reservoir: starts full at OIL_TOTAL and drains OIL_POUR_RATE per second while pouring.
const OIL_TOTAL: float = 100.0
const OIL_POUR_RATE: float = 25.0
## The can pours when the mouse is over the robot, or the robot is within this many pixels
## directly below the mouse (holding the can just above the robot still pours onto it).
const OIL_POUR_PROXIMITY_PX: float = 25.0
const OIL_IDLE_TEXTURE_PATH: String = "res://assets/textures/icons/oil.png"
const OIL_POUR_SHEET_PATH: String = "res://assets/textures/icons/oil_pour.png"
## The pour sheet is a vertical strip of frames (96x384 = three 96x128 frames); this cycles
## through them while pouring.
const OIL_POUR_FRAME_COUNT: int = 3
const OIL_POUR_FRAME_SECONDS: float = 0.1
## When the can runs dry it tips 90° counter-clockwise (top pointing west) instead of
## reverting to the upright idle can, then falls when released.
const OIL_EMPTY_ROTATION: float = -PI / 2.0
## Seconds the emptied can takes to fall off-screen once the player lets go.
const OIL_FALL_SECONDS: float = 0.8
## The oil readout matches the stress-test HUD labels (28px), in the same red as its
## Awareness label.
const OIL_LABEL_COLOR: Color = Color(1, 0.42, 0.42, 1)
const OIL_LABEL_FONT_SIZE: int = 28
## Dock items that glide into a full-robot drop slot when let go over her (none at the
## moment - the taser has its own handling, below).
const MAINTENANCE_ITEM_IDS: Array[StringName] = []
## The taser is single-use: let go over the robot, it zaps her (TaserZapEffect plus a zap
## sound), is used up and leaves the dock, and her anger rises by TASER_ANGER. It does
## nothing for her (yet). Let go anywhere else, it just goes back to the dock.
const TASER_ITEM_ID: StringName = &"taser"
const TASER_ANGER: int = 20
const TASER_ZAP_SOUND_PATH: String = "res://assets/sounds/zap/zap_1.mp3"
## Suspicion / anger / fatigue under the oil readout, in the colours the rest of the
## game's HUD gives them.
const STAT_LABEL_FONT_SIZE: int = 24
const STAT_LABEL_HEIGHT: float = 30.0
const STAT_LABEL_COLORS: Dictionary = {
	"suspicion": Color("e8c878"),
	"anger": Color("e0906a"),
	"fatigue": Color("9ab4d8"),
}
## The battery is not a generic full-robot drop; it targets the pelvis hover box
## and plays the battery-insert animation (see _spawn_pose_boxes / _on_battery_released).
const BATTERY_ITEM_ID: StringName = &"battery"
## The nanobots (quick_patch) are not a slot drop either: releasing them over the robot
## makes them vanish at the drop point and spawns the spreading NanobotEffect there
## (see _connect_nanobot_item / _on_nanobots_released).
const NANOBOT_ITEM_ID: StringName = &"quick_patch"
## The four items are taken out of the inventory into the player's hand (see
## grab_inventory_item): inventory id -> the dock item that does the work. Any other item
## can be held too, but does nothing when let go.
const INVENTORY_DOCK_ITEM_IDS: Dictionary = {
	"oil": OIL_ITEM_ID,
	"battery": BATTERY_ITEM_ID,
	"nanobots": NANOBOT_ITEM_ID,
	"taser": TASER_ITEM_ID,
}
## A held item is drawn the size those four are in hand: their icons are 96px, drawn at the
## background's pixel ratio (see _match_item_to_background). Any other icon is sized as if it
## were 96px too, whatever its own resolution, inside the dock items' 56px rect.
const HELD_ITEM_TEXELS: float = 96.0
const HELD_ITEM_RECT_SIZE: Vector2 = Vector2(56, 56)
## A robot part in the inventory (one taken off her on the laptop, or any spare) can be taken
## out of the inventory too: it's held as its own art (see MaintenanceRobot.part_textures),
## snaps into a free slot once it's within LIMB_SNAP_DISTANCE robot pixels of where it
## belongs, and goes on - used up from the inventory - if let go there (see
## _place_or_drop_held_limb).
const LIMB_SNAP_DISTANCE: float = 28.0
## A leg (or a leg piece) also snaps when held up to this much higher (robot pixels) than
## its hold point - its middle sits low, mostly off the bottom of the view, so this lets it
## be dropped in up by her hips.
const LEG_SNAP_EXTRA_UP: float = 40.0
## A held piece is held by its middle, or (for one partly off screen, like her feet) by the
## nearest point to it at least this far (robot pixels) inside the screen's edge.
const LIMB_HOLD_SCREEN_MARGIN: float = 16.0
## Putting a part on plays a place thunk with a decompress hiss at the same time: the heavy
## ones for whole limbs and body parts, the small ones for a hand or a limb segment (a limb
## can also be built up on her piece by piece - see GameState.LIMB_SEGMENTS).
const LIMB_PLACE_SOUND_DIR: String = "res://assets/sounds/maintenance_place/"
const LIMB_PLACE_SOUNDS: Array[String] = ["heavy_limb_place_1.mp3", "heavy_limb_place_2.mp3"]
const LIMB_DECOMPRESS_SOUNDS: Array[String] = ["decompress.mp3"]
const SMALL_PLACE_SOUNDS: Array[String] = ["small_limb_place_1.mp3", "small_limb_place_2.mp3"]
const SMALL_DECOMPRESS_SOUNDS: Array[String] = ["small_decompress.mp3", "small_decompress_2.mp3"]
const SMALL_PLACE_PART_IDS: Array[String] = ["hand"]
## The hiss follows the thunk by this many seconds; both play pitched up or down by a random
## whole percent, up to this much.
const LIMB_DECOMPRESS_DELAY: float = 0.05
const LIMB_PLACE_PITCH_VARIATION_PERCENT: int = 10

@export var robot_border_buffer: int = 10
@export_range(0.0, 1.0, 0.01) var robot_alpha_threshold: float = 0.05
@export var force_show_hover_border: bool = false
## Click-the-robot zoom: zooms the camera into the robot's bounding box (with wheel
## scroll to pan the zoomed view). Disabled in maintenance - the camera stays on the
## whole-scene mouse-follow view - but kept behind a flag so it can be re-enabled.
@export var robot_box_zoom_enabled: bool = false

@export_group("Camera Mouse Follow")
## The resting camera view (the whole-scene view, before the robot-box zoom) zooms in by
## this factor so there is a margin to drift into as the view tracks the mouse, instead of
## revealing the scene's edges. 1.0 = no zoom (and, with the strengths at 0, no sway).
@export_range(1.0, 1.5, 0.01) var mouse_follow_zoom_scale: float = 1.08
## How far (screen pixels) the view drifts toward the mouse at full pull. 0 disables it.
@export var mouse_follow_strength: float = 24.0
## Individual multiplier on the horizontal (left-right) drift, on top of the strength
## above. 1 = same as vertical; below 1 damps it; 0 makes the sway vertical-only; above 1
## exaggerates it.
@export_range(0.0, 3.0, 0.05) var mouse_follow_horizontal_strength: float = 1.0
## Individual multiplier on the vertical (up-down) drift, on top of the strength above.
## 1 = same as horizontal; below 1 damps it; 0 makes the sway horizontal-only; above 1
## exaggerates it.
@export_range(0.0, 3.0, 0.05) var mouse_follow_vertical_strength: float = 1.0
## Edge softness: higher makes the pull toward the mouse saturate sooner, so it tapers off
## (exponentially) as the cursor nears the screen edge - the view never lurches at the
## border.
@export_range(0.5, 8.0, 0.1) var mouse_follow_edge_falloff: float = 2.5
## How quickly the view eases toward the mouse-follow target, per second. Higher is
## snappier, lower is floatier.
@export_range(1.0, 30.0, 0.5) var mouse_follow_smoothing: float = 8.0

@onready var camera_window: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow
@onready var scene_canvas: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas
@onready var background: TextureRect = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/Background
@onready var robot: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/RobotLayer/MaintenanceRobot
@onready var end_button: Button = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/EndButton
## The (hidden) dock the four items rest in between uses; held items are dragged in its space.
@onready var item_dock: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/ItemDock
## Idle template of the nanobot spread effect. Its exported variables are tuned in the
## editor; each nanobot drop duplicates it so the copy carries those settings.
@onready var _nanobot_effect_template: NanobotEffect = $NanobotEffectTemplate

## The laptop overlay while it is open (assembly app); null when closed.
var _laptop_overlay: Node = null
## The swipe-down laptop bar (same as the stress test's left view), its invisible
## placement anchor in the camera window, and whether it can trigger (false after a
## flip until the cursor leaves the bar).
var _laptop_bar: LaptopDragBar = null
var _laptop_bar_anchor: Control = null
var _laptop_bar_armed: bool = true
## The INVENTORY button in the bottom-left corner, and the anchor it copies (like the bar).
var _inventory_button: InventoryButton = null
var _inventory_button_anchor: Control = null
## The bar draws just above the laptop overlay (canvas layer 40).
const LAPTOP_BAR_CANVAS_LAYER: int = 41
## Just above the inventory overlay (InventoryOverlay, layer 100).
const INVENTORY_BUTTON_CANVAS_LAYER: int = 101
## While the laptop is open the camera sway is damped to a fifth so it barely drifts.
const LAPTOP_CAMERA_SWAY_FACTOR: float = 0.2
var _camera_sway_factor: float = 1.0

var _robot_bbox_local: Rect2 = Rect2()
var _hover_box: Control = null
var _drop_slots: Array[DropSlot] = []
## Per-leg hover boxes (click to swing that leg out) and the pelvis battery-drop
## box, keyed "left"/"right"/"pelvis". Created in _spawn_pose_boxes().
var _pose_boxes: Dictionary = {}
## True from a click on a leg until the mouse button is let go (closed-hand cursor).
var _leg_grip: bool = false
## The item in the player's hand, taken out of the inventory (null when empty-handed), and
## whether it's one of the others (a plain sprite that does nothing) rather than a dock item.
var _held_item: DraggableItem = null
var _held_generic: bool = false
## A limb in the hand, taken out of the inventory to go back on her (null when not), drawn in
## the robot's own space: which part, which side (paired parts), the robot-canvas point the
## cursor holds it by (its art's middle), and whether it has snapped into its place.
var _held_limb: Control = null
var _held_limb_id: String = ""
var _held_limb_side: String = ""
var _held_limb_centre: Vector2 = Vector2.ZERO
var _held_limb_snapped: bool = false
## Side -> [its art (full-canvas textures, back to front), the rect that art covers on her].
var _held_limb_art: Dictionary = {}
var _battery_item: DraggableItem = null
var _nanobot_item: DraggableItem = null
var _taser_item: DraggableItem = null
var _oil_item: DraggableItem = null
var _oil_label: Label = null
## The suspicion / anger / fatigue readouts, keyed by stat.
var _stat_labels: Dictionary = {}
var _oil_remaining: float = OIL_TOTAL
## True once the can has run dry: it tips over (top west) and, on release, falls away.
var _oil_empty: bool = false
## Idle can texture and the cycled pour-animation frames, built once.
var _oil_idle_texture: Texture2D = null
var _oil_pour_frames: Array[AtlasTexture] = []
var _oil_pour_anim_time: float = 0.0
var _zoomed: bool = false
var _zoom_tween: Tween = null
var _canvas_base_scale: float = 1.0
var _zoom_scale: float = 1.0
var _view_left: float = 0.0
var _view_top: float = 0.0
## Current smoothed mouse-follow (sway) offset added on top of the resting default view;
## eased toward the mouse each frame and back to zero while robot-box zoomed.
var _mouse_follow_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_apply_background()
	if camera_window != null and not camera_window.resized.is_connected(_on_camera_window_resized):
		camera_window.resized.connect(_on_camera_window_resized)
	_apply_default_canvas_transform()
	call_deferred("_apply_default_canvas_transform")
	_robot_bbox_local = _compute_robot_pixel_bbox()
	_spawn_hover_box()
	_spawn_drop_slots()
	_spawn_pose_boxes()
	_connect_battery_item()
	_connect_nanobot_item()
	_connect_taser_item()
	_connect_item_grab_scaling()
	_hide_item_dock()
	add_to_group(InventoryOverlay.GRABBER_GROUP)
	_spawn_oil_label()
	_spawn_stat_labels()
	style_corner_button(end_button)
	_create_laptop_bar()
	_connect_inventory_signals()
	call_deferred("_cache_oil_item")
	# Pre-build the robot silhouette mask now (off the drop) so the first nanobot drop,
	# which needs it, doesn't pay the one-time build cost as a visible hitch.
	call_deferred("_warm_nanobot_mask")


func _apply_background() -> void:
	if background == null:
		return
	var texture := PackedSpriteSheet.flattened_texture(
		BACKGROUND_SHEET_PATH, BACKGROUND_SHEET_JSON_PATH, BACKGROUND_SKIPPED_LAYERS
	)
	if texture != null:
		background.texture = texture


## Keep the robot in sync with the player's inventory while the scene is open: the
## laptop assembly overlay (and anything else) changes robot parts / cosmetics through
## GameState, which fires these signals - so the maintenance robot rebuilds to show
## exactly what the player now owns instead of staying frozen on its _ready() snapshot.
func _connect_inventory_signals() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	if state.has_signal("robot_parts_changed") \
			and not state.robot_parts_changed.is_connected(_on_robot_inventory_changed):
		state.robot_parts_changed.connect(_on_robot_inventory_changed)
	if state.has_signal("cosmetic_items_changed") \
			and not state.cosmetic_items_changed.is_connected(_on_robot_inventory_changed):
		state.cosmetic_items_changed.connect(_on_robot_inventory_changed)


func _on_robot_inventory_changed(_data: Dictionary = {}) -> void:
	_refresh_robot_parts()


## Rebuilds the robot's layer stack from what she's wearing and re-derives every
## interaction region that depends on which parts are shown (the hover box, item drop
## slots, and the leg / shoulder / chest-cover / pelvis pose boxes), so clicks and drops
## keep tracking the robot after its parts change.
func _refresh_robot_parts() -> void:
	if robot == null or not is_instance_valid(robot):
		return
	if robot.has_method("rebuild"):
		robot.call("rebuild")
	_robot_bbox_local = _compute_robot_pixel_bbox()
	_spawn_hover_box()
	_spawn_drop_slots()
	_spawn_pose_boxes()
	# The rebuild invalidated the silhouette mask; re-warm it off the drop.
	call_deferred("_warm_nanobot_mask")


## The robot's look settings, for the Shift+Tab debug menu (see MaintenanceRobot.DEBUG_SETTINGS).
func debug_setting_keys() -> Array:
	if robot == null or not is_instance_valid(robot) or not robot.has_method("debug_setting_keys"):
		return []
	return robot.call("debug_setting_keys")


func debug_setting_label(key: String) -> String:
	if robot == null or not is_instance_valid(robot) or not robot.has_method("debug_setting_label"):
		return key
	return String(robot.call("debug_setting_label", key))


## Steps one look setting, then rebuilds her so it shows (and the hover boxes follow).
func debug_cycle_setting(key: String) -> void:
	if robot == null or not is_instance_valid(robot) or not robot.has_method("debug_cycle_setting"):
		return
	robot.call("debug_cycle_setting", key)
	_refresh_robot_parts()


## Pre-builds (and caches) the robot's silhouette mask so a later nanobot drop reads it
## instead of building it mid-effect. Cheap when the cache is already warm.
func _warm_nanobot_mask() -> void:
	if robot != null and is_instance_valid(robot) and robot.has_method("get_opaque_mask"):
		robot.call("get_opaque_mask")


# --- laptop -------------------------------------------------------------------

## The stress test's laptop bar: a wide strip along the bottom of the screen. Swiping
## the mouse down onto it flips the laptop (assembly app) up, and - since it stays on
## screen over the open laptop - swiping down onto it again puts the laptop away. After
## each flip the cursor has to leave the bar before it can trigger again, so one swipe
## never opens and closes it in one go.
##
## The bar lives on its own canvas layer just above the laptop's, and each frame copies
## the placement of an invisible anchor laid out along the bottom of the full-screen root
## (not the camera window, which overflows the screen here), so it stays on screen.
func _create_laptop_bar() -> void:
	var hud_root := get_node_or_null(^"FullscreenLayer/FullscreenRoot") as Control
	if hud_root == null:
		return
	_laptop_bar_anchor = Control.new()
	_laptop_bar_anchor.name = "LaptopBarAnchor"
	_laptop_bar_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_laptop_bar_anchor.anchor_left = 0.22
	_laptop_bar_anchor.anchor_right = 0.78
	_laptop_bar_anchor.anchor_top = 1.0
	_laptop_bar_anchor.anchor_bottom = 1.0
	# The bar art at 3x (600 x 60) fits this slot (see LaptopDragBar). Sits 7px off the
	# bottom, the same spot the stress test's bar lands on screen.
	_laptop_bar_anchor.offset_top = -67.0
	_laptop_bar_anchor.offset_bottom = -7.0
	_laptop_bar_anchor.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud_root.add_child(_laptop_bar_anchor)

	var layer := CanvasLayer.new()
	layer.name = "LaptopBarLayer"
	layer.layer = LAPTOP_BAR_CANVAS_LAYER
	add_child(layer)
	_laptop_bar = LaptopDragBar.new()
	_laptop_bar.name = "LaptopBar"
	_laptop_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_laptop_bar.gui_input.connect(_on_laptop_bar_input)
	layer.add_child(_laptop_bar)

	# The inventory button in the bottom-left corner, placed like the bar (copying an
	# anchor laid out in the full-screen root, 7px off the edges). Its layer sits just above
	# the inventory overlay's, as the bar's sits above the laptop's, so it can be swiped
	# again to put the inventory away.
	var inventory_layer := CanvasLayer.new()
	inventory_layer.name = "InventoryButtonLayer"
	inventory_layer.layer = INVENTORY_BUTTON_CANVAS_LAYER
	add_child(inventory_layer)
	_inventory_button = InventoryButton.new()
	_inventory_button.name = "InventoryButton"
	_inventory_button.pressed.connect(_on_inventory_button_pressed)
	inventory_layer.add_child(_inventory_button)
	_inventory_button_anchor = Control.new()
	_inventory_button_anchor.name = "InventoryButtonAnchor"
	_inventory_button_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var button_size := _inventory_button.canvas_size() * InventoryButton.ART_SCALE
	_inventory_button_anchor.anchor_top = 1.0
	_inventory_button_anchor.anchor_bottom = 1.0
	_inventory_button_anchor.offset_left = 7.0
	_inventory_button_anchor.offset_right = 7.0 + button_size.x
	_inventory_button_anchor.offset_top = -7.0 - button_size.y
	_inventory_button_anchor.offset_bottom = -7.0
	hud_root.add_child(_inventory_button_anchor)


## The inventory button (click or swipe down): opens or puts away the inventory, like
## pressing Space.
func _on_inventory_button_pressed() -> void:
	var node := get_parent()
	while node != null and not node.has_method("toggle_inventory"):
		node = node.get_parent()
	if node != null:
		node.call("toggle_inventory")


## Swipe down onto the bar: open the laptop, or close it if it's already open.
func _on_laptop_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.relative.y > 0.0 and _laptop_bar_armed:
		_laptop_bar_armed = false
		if _laptop_open():
			_close_laptop()
		else:
			_open_laptop_overlay()


func _laptop_open() -> bool:
	return _laptop_overlay != null and is_instance_valid(_laptop_overlay)


## Keeps the bar on its anchor's spot, redraws its pulse, and re-arms it once the
## cursor is off it.
func _update_laptop_bar() -> void:
	if _laptop_bar == null:
		return
	if _laptop_bar_anchor != null:
		_laptop_bar.position = _laptop_bar_anchor.global_position
		_laptop_bar.size = _laptop_bar_anchor.size
		_laptop_bar.scale = _laptop_bar_anchor.get_global_transform().get_scale()
	if _inventory_button != null and _inventory_button_anchor != null:
		_inventory_button.position = _inventory_button_anchor.global_position
		_inventory_button.scale = _inventory_button_anchor.get_global_transform().get_scale()
	_laptop_bar.queue_redraw()
	if not _laptop_bar.contains_global_point(_laptop_bar.get_global_mouse_position()):
		_laptop_bar_armed = true


## Opens the laptop (assembly app) as an overlay on top of maintenance. The open
## animation plays every time; a click on the transparent background shuts it on the
## spot (no close animation), as in the stress test. While it is up, maintenance's own
## robot input is paused so clicks belong to the laptop.
func _open_laptop_overlay() -> void:
	if _laptop_open():
		return
	# Whatever's in hand goes back in the inventory first.
	if _held_limb != null:
		_cancel_held_limb()
	if _held_item != null:
		_cancel_held_item()
	var laptop: Node = LAPTOP_SCENE.instantiate()
	# Laptop.gd has no class_name, so drive it dynamically.
	laptop.set("overlay_mode", true)
	laptop.set("instant", true)
	laptop.set("app_mode", "assembly")
	# Restricted desktop: maintenance app + settings only.
	laptop.set("desktop_context", "maintenance")
	_laptop_overlay = laptop
	set_process_input(false)
	# Barely drift the camera while reading the laptop.
	_camera_sway_factor = LAPTOP_CAMERA_SWAY_FACTOR
	if laptop.has_signal("closed"):
		laptop.connect("closed", _on_laptop_overlay_closed)
	add_child(laptop)


func _on_laptop_overlay_closed() -> void:
	_laptop_overlay = null
	set_process_input(true)
	_camera_sway_factor = 1.0


## Shuts the laptop through its own close path (which emits `closed`).
func _close_laptop() -> void:
	if not _laptop_open():
		return
	var laptop := _laptop_overlay
	if laptop.has_method("_on_leave_pressed"):
		laptop.call("_on_leave_pressed")
	else:
		laptop.queue_free()
		_on_laptop_overlay_closed()


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	# A limb in hand: a right-click puts it back; letting go puts it on her if it's in place.
	if _held_limb != null:
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_cancel_held_limb()
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_place_or_drop_held_limb()
		get_viewport().set_input_as_handled()
		return
	# An item in hand: a right-click puts it back; letting go uses it (a dock item's release
	# is caught by the dock, ItemDock, before it gets here). Nothing else takes clicks.
	if _held_item != null:
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_cancel_held_item()
		elif _held_generic and mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			var item := _held_item
			_held_item = null
			item.end_drag(mouse_event.global_position)
		get_viewport().set_input_as_handled()
		return
	if not mouse_event.pressed:
		if _leg_grip and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_leg_grip = false
			_update_leg_cursor()
		return

	if robot_box_zoom_enabled and _zoomed \
			and mouse_event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_scroll_zoomed_view(mouse_event.button_index)
		get_viewport().set_input_as_handled()
		return

	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	# The hand closes on the click on a leg itself, before it swings.
	if _leg_box_under(mouse_event.global_position):
		_leg_grip = true
		_update_leg_cursor()
	# Pose hover boxes (shoulders / chest cover / legs) take clicks before the robot
	# zoom, so their toggles aren't swallowed by it.
	if _handle_pose_box_click(mouse_event.global_position):
		get_viewport().set_input_as_handled()
		return

	# Robot-box zoom is disabled in maintenance; a click on the robot falls through
	# (it does nothing and isn't consumed) unless the flag is re-enabled.
	if not robot_box_zoom_enabled:
		return
	if _hover_box == null or not is_instance_valid(_hover_box):
		return
	if not _hover_box.visible or not _hover_box.is_visible_in_tree():
		return
	if not _hover_box.get_global_rect().has_point(mouse_event.global_position):
		return

	_toggle_robot_box_zoom()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_update_camera_mouse_follow(delta)
	_update_laptop_bar()
	_update_held_limb()
	_update_leg_cursor()
	_update_oil_pour(delta)
	if _hover_box == null or not is_instance_valid(_hover_box):
		return
	if force_show_hover_border:
		_hover_box.force_visible = true
		_hover_box.set_hovered(true)
		return
	_hover_box.force_visible = false
	_hover_box.set_hovered(_hover_box.get_global_rect().has_point(get_global_mouse_position()))


func _compute_robot_pixel_bbox() -> Rect2:
	var bounds: Rect2 = Rect2()
	var found_any: bool = false
	for tr in _collect_texture_rects(robot):
		if tr.name == "Shadow":
			continue
		var tex: Texture2D = tr.texture
		if tex == null:
			continue
		var img: Image = tex.get_image()
		if img == null:
			continue
		var used: Rect2i = _opaque_bounds(img, robot_alpha_threshold)
		if used.size == Vector2i.ZERO:
			continue
		var sx: float = robot.size.x / float(img.get_width())
		var sy: float = robot.size.y / float(img.get_height())
		var mapped := Rect2(
			Vector2(used.position.x * sx, used.position.y * sy),
			Vector2(used.size.x * sx, used.size.y * sy)
		)
		if not found_any:
			bounds = mapped
			found_any = true
		else:
			bounds = bounds.merge(mapped)
	return bounds


func _collect_texture_rects(node: Node) -> Array[TextureRect]:
	var out: Array[TextureRect] = []
	# Skip nodes being torn down: a robot rebuild queue_free()s its old layers (which
	# survive until frame end), and this runs right after, so ignoring them keeps a
	# post-rebuild bbox from merging in stale, soon-to-vanish art.
	if node.is_queued_for_deletion():
		return out
	if node is TextureRect:
		out.append(node)
	for child in node.get_children():
		out.append_array(_collect_texture_rects(child))
	return out


func _opaque_bounds(img: Image, threshold: float) -> Rect2i:
	var initial: Rect2i = img.get_used_rect()
	if initial.size == Vector2i.ZERO or threshold <= 0.0:
		return initial

	var min_x: int = initial.position.x + initial.size.x
	var min_y: int = initial.position.y + initial.size.y
	var max_x: int = initial.position.x - 1
	var max_y: int = initial.position.y - 1
	var x_end: int = initial.position.x + initial.size.x
	var y_end: int = initial.position.y + initial.size.y
	for y in range(initial.position.y, y_end):
		for x in range(initial.position.x, x_end):
			if img.get_pixel(x, y).a > threshold:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _spawn_hover_box() -> void:
	if _hover_box and is_instance_valid(_hover_box):
		_hover_box.queue_free()
		_hover_box = null
	if _robot_bbox_local.size == Vector2.ZERO:
		return

	var box: Control = RobotHoverBox.new()
	var buffer := float(robot_border_buffer)
	box.position = _robot_bbox_local.position - Vector2(buffer, buffer)
	box.size = _robot_bbox_local.size + Vector2(buffer * 2.0, buffer * 2.0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.force_visible = force_show_hover_border
	box.z_index = 100
	robot.add_child(box)
	_hover_box = box


func _spawn_drop_slots() -> void:
	for slot in _drop_slots:
		if slot != null and is_instance_valid(slot):
			slot.queue_free()
	_drop_slots.clear()

	if _robot_bbox_local.size == Vector2.ZERO:
		return

	var buffer := float(robot_border_buffer)
	var slot_rect := Rect2(
		_robot_bbox_local.position - Vector2(buffer, buffer),
		_robot_bbox_local.size + Vector2(buffer * 2.0, buffer * 2.0)
	)
	for item_id in MAINTENANCE_ITEM_IDS:
		var slot := DropSlot.new()
		slot.name = "MaintenanceDropSlot%d" % _drop_slots.size()
		slot.accepts_item_id = item_id
		slot.position = slot_rect.position
		slot.size = slot_rect.size
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.z_index = 99
		robot.add_child(slot)
		_drop_slots.append(slot)


## Interaction hover boxes on the robot: one per leg (click to swing that leg out;
## both out -> the stomach swaps to its crunch art) and one over the pelvis (the
## battery drop target). Each is positioned from the robot's own art via
## leg_rect() / pelvis_rect(), so they track whatever parts the player owns.
func _spawn_pose_boxes() -> void:
	for box in _pose_boxes.values():
		if box != null and is_instance_valid(box):
			box.queue_free()
	_pose_boxes.clear()
	if robot == null or not is_instance_valid(robot):
		return

	# Leg boxes: click to swing that leg out (only while she sits up - leaning back on
	# fewer than two thighs, her legs stay put).
	if robot.has_method("leg_rect") and robot.has_method("can_leg_out"):
		for side in ["left", "right"]:
			if not bool(robot.call("can_leg_out", side)):
				continue
			var rect: Rect2 = robot.call("leg_rect", side)
			if rect.size != Vector2.ZERO:
				_pose_boxes["leg_" + side] = _make_pose_box("LegBox_" + side, rect)

	# Shoulder boxes: click to cycle that shoulder's variant (pad / smooth / bare).
	if robot.has_method("shoulder_rect") and robot.has_method("has_shoulder"):
		for side in ["left", "right"]:
			if not bool(robot.call("has_shoulder", side)):
				continue
			var rect: Rect2 = robot.call("shoulder_rect", side)
			if rect.size != Vector2.ZERO:
				_pose_boxes["shoulder_" + side] = _make_pose_box("ShoulderBox_" + side, rect)

	# Chest cover box: click to equip / unequip it.
	if robot.has_method("chest_cover_rect") and robot.has_method("has_chest_cover") \
			and bool(robot.call("has_chest_cover")):
		var cover: Rect2 = robot.call("chest_cover_rect")
		if cover.size != Vector2.ZERO:
			_pose_boxes["chest_cover"] = _make_pose_box("ChestCoverBox", cover)

	# Pelvis box: the battery drop target (handled on release, not click).
	if robot.has_method("pelvis_rect") and robot.has_method("can_play_battery_animation") \
			and bool(robot.call("can_play_battery_animation")):
		var pelvis: Rect2 = robot.call("pelvis_rect")
		if pelvis.size != Vector2.ZERO:
			_pose_boxes["pelvis"] = _make_pose_box("PelvisBox", pelvis)


func _make_pose_box(box_name: String, rect: Rect2) -> Control:
	# Invisible interaction region only - it hit-tests clicks/drops but never draws
	# a border (show_border stays false).
	var box: Control = RobotHoverBox.new()
	box.name = box_name
	box.position = rect.position
	box.size = rect.size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.z_index = 101
	robot.add_child(box)
	return box


## Connects the dock's battery draggable so releasing it over the pelvis box plays
## the battery-insert animation. (The battery isn't in MAINTENANCE_ITEM_IDS, so
## WorkInventory just snaps it home afterwards.)
## Routes a left click to whichever pose box it landed on. Returns true if one
## handled it. Shoulders / chest cover (upper, centre) are tested before legs.
func _handle_pose_box_click(global_pos: Vector2) -> bool:
	if robot == null or not is_instance_valid(robot):
		return false
	var handled := false
	for side in ["left", "right"]:
		if _pose_box_hit("shoulder_" + side, global_pos):
			if robot.has_method("cycle_shoulder"):
				robot.call("cycle_shoulder", side)
			handled = true
			break
	if not handled and _pose_box_hit("chest_cover", global_pos):
		if robot.has_method("toggle_chest_cover"):
			robot.call("toggle_chest_cover")
		handled = true
	if not handled:
		for side in ["left", "right"]:
			if _pose_box_hit("leg_" + side, global_pos):
				if robot.has_method("toggle_leg_out"):
					robot.call("toggle_leg_out", side)
				handled = true
				break
	if handled:
		# The pose change invalidated the silhouette mask; re-warm it off the drop.
		call_deferred("_warm_nanobot_mask")
	return handled


## Whether a leg (the limbs that move here) is under `global_pos`.
func _leg_box_under(global_pos: Vector2) -> bool:
	return _pose_box_hit("leg_left", global_pos) or _pose_box_hit("leg_right", global_pos)


## The grab cursor for her legs: a closed hand from the click on a leg until the mouse
## button is let go, an open hand while a leg is under the mouse. Off while the laptop
## is up (it owns the mouse then).
func _update_leg_cursor() -> void:
	# A release something else took (an overlay up over the scene) still lets go of the leg.
	if _laptop_open() or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_leg_grip = false
	var state: int = CursorTheme.Grab.NONE
	# The hand grips whatever it's holding from the inventory.
	if _leg_grip or _held_item != null or _held_limb != null:
		state = CursorTheme.Grab.CLOSED
	elif not _laptop_open() and _leg_box_under(get_global_mouse_position()):
		state = CursorTheme.Grab.OPEN
	CursorTheme.set_grab(self, state)


func _exit_tree() -> void:
	CursorTheme.set_grab(self, CursorTheme.Grab.NONE)


func _pose_box_hit(key: String, global_pos: Vector2) -> bool:
	var box: Control = _pose_boxes.get(key)
	return box != null and is_instance_valid(box) and box.is_visible_in_tree() \
		and box.get_global_rect().has_point(global_pos)


func _connect_battery_item() -> void:
	_battery_item = _find_draggable_item_by_id(self, BATTERY_ITEM_ID)
	if _battery_item != null and not _battery_item.drag_released.is_connected(_on_battery_released):
		_battery_item.drag_released.connect(_on_battery_released)
	_update_battery_item_availability()


## The spare batteries the player currently owns (capped at one in GameState).
func _battery_count() -> int:
	return int(GameState.ingredients.get("battery", 0))


## Show / enable the dock battery only while the player owns one. It is single-use and
## consumed on a successful insert, so with none owned it is hidden and can't be dragged.
func _update_battery_item_availability() -> void:
	if _battery_item == null or not is_instance_valid(_battery_item):
		return
	var owned := _battery_count() >= 1
	_battery_item.visible = owned
	_battery_item.mouse_filter = Control.MOUSE_FILTER_PASS if owned else Control.MOUSE_FILTER_IGNORE


func _on_battery_released(_item: DraggableItem, release_global_pos: Vector2) -> void:
	var pelvis: Control = _pose_boxes.get("pelvis")
	if pelvis == null or not is_instance_valid(pelvis) or not pelvis.is_visible_in_tree():
		return
	if not pelvis.get_global_rect().has_point(release_global_pos):
		return
	# The battery only seats in the crunch pose - both legs swung out to their "out"
	# version. With either leg still in its default pose, dropping it on the pelvis
	# box does nothing.
	if not _both_legs_out():
		return
	# It is single-use: the player must actually own one, and using it consumes it.
	if _battery_count() < 1:
		return
	if robot != null and is_instance_valid(robot) and robot.has_method("play_battery_animation"):
		robot.call("play_battery_animation")
		GameState.add_ingredient("battery", -1)
		_update_battery_item_availability()


## True only when both legs are present and swung out (the crunch pose). The battery
## can be seated only in this pose.
func _both_legs_out() -> bool:
	if robot == null or not is_instance_valid(robot) or not robot.has_method("is_leg_out"):
		return false
	return bool(robot.call("is_leg_out", "left")) and bool(robot.call("is_leg_out", "right"))


## Wire the dock's taser: let go over the robot, it zaps her (see TASER_ITEM_ID).
func _connect_taser_item() -> void:
	_taser_item = _find_draggable_item_by_id(self, TASER_ITEM_ID)
	if _taser_item != null and not _taser_item.drag_released.is_connected(_on_taser_released):
		_taser_item.drag_released.connect(_on_taser_released)
	_update_taser_item_availability()


## The dock taser shows (and can be grabbed) only while the player owns one.
func _update_taser_item_availability() -> void:
	if _taser_item == null or not is_instance_valid(_taser_item):
		return
	var owned := GameState.has_tool(String(TASER_ITEM_ID))
	_taser_item.visible = owned
	_taser_item.mouse_filter = Control.MOUSE_FILTER_PASS if owned else Control.MOUSE_FILTER_IGNORE


func _on_taser_released(item: DraggableItem, release_global_pos: Vector2) -> void:
	# Only over the robot; anywhere else WorkInventory flies it back to the dock.
	if _hover_box == null or not is_instance_valid(_hover_box) or not _hover_box.is_visible_in_tree():
		return
	if not _hover_box.get_global_rect().has_point(release_global_pos):
		return
	if not GameState.has_tool(String(TASER_ITEM_ID)):
		return
	_spawn_taser_zap(release_global_pos)
	_play_one_shot(TASER_ZAP_SOUND_PATH)
	GameState.add_anger(TASER_ANGER)
	GameState.use_up_tool(String(TASER_ITEM_ID))
	# Gone from the spot it was let go - straight back to its dock slot (no glide home),
	# where it stays hidden unless there's another.
	if item.home_slot != null and is_instance_valid(item.home_slot):
		item.place_in(item.home_slot)
	_update_taser_item_availability()


## The taser's bolts and flicker, laid over the robot like the nanobot effect so its
## local space is her pixel space.
func _spawn_taser_zap(release_global_pos: Vector2) -> void:
	if robot == null or not is_instance_valid(robot) or robot.get_parent() == null:
		return
	var effect := TaserZapEffect.new()
	effect.robot = robot
	robot.get_parent().add_child(effect)
	effect.position = robot.position
	effect.scale = robot.scale
	effect.rotation = robot.rotation
	effect.pivot_offset = robot.pivot_offset
	effect.size = robot.size
	effect.start(robot.get_global_transform().affine_inverse() * release_global_pos)


## Plays `path` once (at `pitch`) on a throwaway player that frees itself when done.
func _play_one_shot(path: String, pitch: float = 1.0) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = pitch
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## Wire the dock's nanobot (quick_patch) draggable so releasing it over the robot spawns
## the spreading NanobotEffect at the drop point instead of gliding into a slot.
func _connect_nanobot_item() -> void:
	_nanobot_item = _find_draggable_item_by_id(self, NANOBOT_ITEM_ID)
	if _nanobot_item != null and not _nanobot_item.drag_released.is_connected(_on_nanobots_released):
		_nanobot_item.drag_released.connect(_on_nanobots_released)


func _on_nanobots_released(item: DraggableItem, release_global_pos: Vector2) -> void:
	# Only when dropped over the robot. Otherwise leave it for WorkInventory to snap home.
	if _hover_box == null or not is_instance_valid(_hover_box) or not _hover_box.is_visible_in_tree():
		return
	if not _hover_box.get_global_rect().has_point(release_global_pos):
		return
	_spawn_nanobot_effect(release_global_pos)
	# Vanish from the drop point and reappear in the dock immediately (reusable stamp),
	# overriding WorkInventory's glide-home so it doesn't drift back across the screen.
	if item.home_slot != null and is_instance_valid(item.home_slot):
		item.place_in(item.home_slot)


## Spawns a NanobotEffect as a sibling of the robot, matched to the robot's transform so
## its local space is the robot's pixel space, and starts it at the drop point.
func _spawn_nanobot_effect(release_global_pos: Vector2) -> void:
	if robot == null or not is_instance_valid(robot):
		return
	var parent := robot.get_parent()
	if parent == null:
		return
	# Duplicate the editor-tuned template so this spawn carries its inspector settings.
	var effect: NanobotEffect
	if _nanobot_effect_template != null and is_instance_valid(_nanobot_effect_template):
		effect = _nanobot_effect_template.duplicate() as NanobotEffect
	else:
		effect = NanobotEffect.new()
	effect.robot = robot
	parent.add_child(effect)
	# Overlay the robot exactly so effect-local coordinates == robot-local coordinates.
	effect.position = robot.position
	effect.scale = robot.scale
	effect.rotation = robot.rotation
	effect.pivot_offset = robot.pivot_offset
	effect.size = robot.size
	# Drop point converted into the robot's (and thus the effect's) local space. Uses the
	# same global-transform basis as the hover box's get_global_rect hit test above.
	var local: Vector2 = robot.get_global_transform().affine_inverse() * release_global_pos
	effect.start(local)


# --- grabbed-item scaling -------------------------------------------------

## The dock renders each item at its slot's 2x so the icons read well at rest. A grabbed
## item, though, is dragged over the scene, so it should match the background's on-screen
## pixel ratio (one item texel == one background texel) instead of the dock's blanket 2x -
## which previously just halved to the slot-less 1x. We connect every dock item's grab and
## release: the grab applies the scene-matched scale, the release restores the resting scale
## (the slot supplies the 2x again).
func _connect_item_grab_scaling() -> void:
	var ids: Array[StringName] = [OIL_ITEM_ID, NANOBOT_ITEM_ID, BATTERY_ITEM_ID, TASER_ITEM_ID]
	for id in MAINTENANCE_ITEM_IDS:
		ids.append(id)
	for id in ids:
		var item := _find_draggable_item_by_id(self, id)
		if item == null:
			continue
		if not item.drag_started.is_connected(_on_dock_item_grabbed):
			item.drag_started.connect(_on_dock_item_grabbed)
		if not item.drag_released.is_connected(_on_dock_item_released):
			item.drag_released.connect(_on_dock_item_released)


func _on_dock_item_grabbed(item: DraggableItem) -> void:
	_match_item_to_background(item)


func _on_dock_item_released(item: DraggableItem, _release_global_pos: Vector2) -> void:
	if item == _held_item:
		_held_item = null
	if item == null or not is_instance_valid(item):
		return
	# A spent oil can falls away with gravity instead of snapping home at the resting scale.
	if item == _oil_item and _oil_empty:
		_start_oil_can_fall()
		return
	# Back to the resting scale; the dock slot's own 2x makes it dock-sized again.
	item.scale = Vector2.ONE


## Scales `item` so its texture draws at the background's pixel ratio. The background art
## (maintenance.png) is authored 1:1 with the 500x400 scene canvas, so one background texel
## is scene_canvas.scale screen pixels. The item is a TextureRect drawn KEEP_ASPECT inside
## its rect - i.e. at fit = min(rect / texture) - so cancelling that fit makes one item
## texel the same on-screen size as one background texel, whatever the item's rect or the
## texture's size. Re-run whenever the item's texture changes size (e.g. the oil can
## swapping to its taller pour frames), since the fit - and so the needed scale - changes.
func _match_item_to_background(item: DraggableItem) -> void:
	if item == null or not is_instance_valid(item) or scene_canvas == null:
		return
	if item.texture == null:
		return
	var rect_size := item.size
	var tex_size := item.texture.get_size()
	if rect_size.x <= 0.0 or rect_size.y <= 0.0 or tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var fit := minf(rect_size.x / tex_size.x, rect_size.y / tex_size.y)
	if fit <= 0.0:
		return
	# Scale around the item's centre so it stays pinned under the cursor as it grows.
	item.pivot_offset = rect_size * 0.5
	var factor := scene_canvas.scale.x / fit
	item.scale = Vector2(factor, factor)


# --- items from the inventory ----------------------------------------------

## The four items used to sit in a dock down the sides of the screen; now they come out of
## the inventory (grab_inventory_item). The dock's slots stay, hidden, as the items' homes
## between uses - anything dropped back "home" simply disappears.
func _hide_item_dock() -> void:
	if item_dock == null:
		return
	for column_name in ["LeftColumn", "RightColumn"]:
		var column := item_dock.get_node_or_null(NodePath(column_name)) as CanvasItem
		if column != null:
			column.visible = false


## Items can be taken out of the inventory (InventoryOverlay.GRABBER_GROUP) while the hand
## is empty and the laptop isn't up.
func can_grab_inventory_items() -> bool:
	return _held_item == null and _held_limb == null and not _laptop_open() and item_dock != null


## Takes the inventory item `entry` into the hand: one of the four picks up its dock item,
## which then works just as it did from the dock (oil pours over her, the battery seats in
## the pelvis, the nanobots spread, the taser zaps) when let go; anything else is held as its
## icon and does nothing when let go. Either way it's centred under the cursor at the held
## size, and a right-click puts it back (see _cancel_held_item).
func grab_inventory_item(entry: Dictionary) -> bool:
	if not can_grab_inventory_items():
		return false
	var id := String(entry.get("id", ""))
	# A robot part with a free slot on her is held up to her to put on (it snaps in only once
	# what it anchors to is on her). With no free slot, it's only held as its icon (below).
	if String(entry.get("kind", "")) == "robot_part" and GameState.get_robot_part_count(id) > 0 \
			and _grab_limb(id):
		return true
	# A limb segment (thigh, forearm...) that can go on next somewhere builds that limb up.
	if GameState.limb_for_segment(id) != "" and _grab_limb(id):
		return true
	var item: DraggableItem = null
	if INVENTORY_DOCK_ITEM_IDS.has(id):
		item = _find_draggable_item_by_id(item_dock, INVENTORY_DOCK_ITEM_IDS[id])
	_held_generic = item == null
	if item == null:
		item = _make_generic_held_item(entry.get("texture") as Texture2D)
		if item == null:
			return false
	elif item.get_parent() != item_dock:
		item.get_parent().remove_child(item)
		item_dock.add_child(item)
	item.visible = true
	item.scale = Vector2.ONE
	item.position = item_dock.get_local_mouse_position() - item.size * 0.5
	_held_item = item
	item.start_drag()
	if _held_generic:
		_size_generic_held_item(item)
	return true


## A plain held icon for an item with no use here; it's freed when let go or put back.
func _make_generic_held_item(texture: Texture2D) -> DraggableItem:
	if texture == null:
		return null
	var item := DraggableItem.new()
	item.name = "HeldItem"
	item.texture = texture
	item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.size = HELD_ITEM_RECT_SIZE
	item_dock.add_child(item)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.drag_released.connect(func(released: DraggableItem, _at: Vector2) -> void: released.queue_free())
	return item


## Sizes a plain held icon like the four dock items in hand: as a 96px icon would be at the
## background's pixel ratio (HELD_ITEM_TEXELS), whatever the icon's own resolution.
func _size_generic_held_item(item: DraggableItem) -> void:
	var tex_size := item.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0 or scene_canvas == null:
		return
	var fit := minf(item.size.x / tex_size.x, item.size.y / tex_size.y)
	var factor := scene_canvas.scale.x * HELD_ITEM_TEXELS / (fit * maxf(tex_size.x, tex_size.y))
	item.pivot_offset = item.size * 0.5
	item.scale = Vector2(factor, factor)


## Right-click while holding: the item goes back into the inventory unused. (An oil can
## that has run dry is spent either way, so it falls away as if let go.)
func _cancel_held_item() -> void:
	var item := _held_item
	_held_item = null
	if item == null or not is_instance_valid(item):
		return
	item.cancel_drag()
	if _held_generic:
		item.queue_free()
		return
	if item == _oil_item and _oil_empty:
		_start_oil_can_fall()
		return
	item.scale = Vector2.ONE
	if item.home_slot != null and is_instance_valid(item.home_slot):
		item.place_in(item.home_slot)


# --- limbs from the inventory ----------------------------------------------

## Takes a robot part (or limb segment) out of the inventory into the hand, held as its own
## art in the robot's space, by its middle. For an arm / leg / hand with both sides free,
## it's whichever side the cursor is nearer (see _update_held_limb).
func _grab_limb(id: String) -> bool:
	if robot == null or not robot.has_method("part_textures") or _limb_sides(id).is_empty():
		return false
	_held_limb_id = id
	_held_limb_side = ""
	_held_limb_snapped = false
	# Each side's art and the rect it covers on her, worked out once.
	_held_limb_art = {}
	for side in _limb_sides(id):
		var textures := _held_limb_textures(side)
		_held_limb_art[side] = [textures, _art_rect(textures)]
	_held_limb = Control.new()
	_held_limb.name = "HeldLimb"
	_held_limb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_limb.size = robot.size
	robot.get_parent().add_child(_held_limb)
	_update_held_limb()
	return true


## The sides part `id` can go on: each free side of an arm / leg / hand, or [""] for any
## other part whose slot is free. For a limb segment, the sides whose limb it's next for.
## Empty when there are none.
func _limb_sides(id: String) -> Array[String]:
	var sides: Array[String] = []
	var limb := GameState.limb_for_segment(id)
	if limb != "":
		for side in GameState.PART_SIDES:
			if GameState.next_limb_segment(limb, side) == id:
				sides.append(side)
	elif GameState.is_paired_part(id):
		for side in GameState.PART_SIDES:
			if not GameState.is_part_attached_on(id, side):
				sides.append(side)
	elif GameState.is_robot_part_id(id) and GameState.get_attached_part_count(id) < 1:
		sides.append("")
	return sides


## Draws the held limb as `side`'s art (full-canvas layers in place).
func _show_held_limb_side(side: String) -> void:
	for child in _held_limb.get_children():
		child.queue_free()
	_held_limb_side = side
	var art: Array = _held_limb_art.get(side, [[], Rect2(Vector2.ZERO, robot.size)])
	for tex in art[0]:
		var layer := TextureRect.new()
		layer.texture = tex
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.texture_filter = robot.texture_filter
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.size = robot.size
		_held_limb.add_child(layer)


## The rect the opaque pixels cover across full-canvas `textures` (the whole robot if none).
func _art_rect(textures: Array[Texture2D]) -> Rect2:
	var used := Rect2i()
	for tex in textures:
		var image := tex.get_image()
		if image == null:
			continue
		var rect := image.get_used_rect()
		if rect.size != Vector2i.ZERO:
			used = rect if used.size == Vector2i.ZERO else used.merge(rect)
	return Rect2(used) if used.size != Vector2i.ZERO else Rect2(Vector2.ZERO, robot.size)


## The point (robot pixels) a piece covering `art` is held by: its middle - pulled onto the
## part of it that's on screen when that's off it, or onto the nearest point on screen when
## all of it is (her shins and feet run off the bottom of the view), so its place can always
## be reached with the cursor.
func _hold_point(art: Rect2) -> Vector2:
	var to_robot := robot.get_global_transform_with_canvas().affine_inverse()
	var view := (to_robot * get_viewport().get_visible_rect()).grow(-LIMB_HOLD_SCREEN_MARGIN)
	var reachable := art.intersection(view)
	if reachable.size == Vector2.ZERO:
		reachable = view
	return art.get_center().clamp(reachable.position, reachable.end)


## The art for the held part on `side`.
func _held_limb_textures(side: String) -> Array[Texture2D]:
	return robot.call("part_textures", _held_limb_id, side)


## Each frame while a limb is held: it follows the cursor by its middle - on the side nearer
## the cursor, for a paired part - and snaps into its place on her once it's within
## LIMB_SNAP_DISTANCE of it and can go on there.
func _update_held_limb() -> void:
	if _held_limb == null or not is_instance_valid(_held_limb):
		return
	var mouse := robot.get_local_mouse_position()
	var best_side := _held_limb_side
	var best_distance := INF
	for side in _held_limb_art:
		var distance := mouse.distance_to(_hold_point(_held_limb_art[side][1]))
		if distance < best_distance:
			best_distance = distance
			best_side = side
	if best_side != _held_limb_side or _held_limb.get_child_count() == 0:
		_show_held_limb_side(best_side)
	_held_limb_centre = _hold_point(_held_limb_art[_held_limb_side][1])
	var offset := mouse - _held_limb_centre
	_held_limb_snapped = _snap_distance(offset) <= LIMB_SNAP_DISTANCE and _limb_placeable(_held_limb_id, _held_limb_side)
	_held_limb.position = robot.position + (Vector2.ZERO if _held_limb_snapped else offset)


## How far the cursor (`offset` from the held piece's hold point) is from where it snaps in:
## the hold point itself, or for a leg piece anywhere on the line from it up
## LEG_SNAP_EXTRA_UP (so its snap zone is stretched up towards her hips).
func _snap_distance(offset: Vector2) -> float:
	if _held_limb_id != "leg" and GameState.limb_for_segment(_held_limb_id) != "leg":
		return offset.length()
	return offset.distance_to(Vector2(0.0, clampf(offset.y, -LEG_SNAP_EXTRA_UP, 0.0)))


## Whether part `id` can go on `side` now: it needs what it anchors to on her - a leg the
## stomach, a hand its arm, the stomach and an arm the chest - and neither a leg nor an arm
## goes where one is part-built. A limb segment goes on only as the next piece of its limb.
func _limb_placeable(id: String, side: String) -> bool:
	var limb := GameState.limb_for_segment(id)
	if limb != "":
		return GameState.next_limb_segment(limb, side) == id
	return GameState.can_equip_part(id, side)


## Let go of the held limb: snapped into place, it goes on her with its place sounds, used up
## from the inventory - a whole part into its slot (and that slot locked, as on the laptop), a
## segment onto the limb it builds (the last one makes the limb whole). Anywhere else it goes
## back in the inventory.
func _place_or_drop_held_limb() -> void:
	var placed := _held_limb_snapped
	var id := _held_limb_id
	var side := _held_limb_side
	_clear_held_limb()
	if not placed:
		return
	var limb := GameState.limb_for_segment(id)
	if limb != "":
		if not GameState.add_limb_segment(limb, side, id):
			return
	elif GameState.lock_limb(id, side).is_empty():
		return
	_play_limb_place_sounds(id)


func _cancel_held_limb() -> void:
	_clear_held_limb()


func _clear_held_limb() -> void:
	if _held_limb != null and is_instance_valid(_held_limb):
		_held_limb.queue_free()
	_held_limb = null
	_held_limb_snapped = false


## The thunk of a part going on, then its decompress hiss LIMB_DECOMPRESS_DELAY later: the
## heavy pair for a whole limb or body part, the small pair for a hand or a limb segment.
## Each plays at its own random pitch (see _random_place_pitch).
func _play_limb_place_sounds(id: String) -> void:
	var small := id in SMALL_PLACE_PART_IDS or GameState.limb_for_segment(id) != ""
	var places: Array[String] = SMALL_PLACE_SOUNDS if small else LIMB_PLACE_SOUNDS
	var hisses: Array[String] = SMALL_DECOMPRESS_SOUNDS if small else LIMB_DECOMPRESS_SOUNDS
	_play_one_shot(LIMB_PLACE_SOUND_DIR + places[randi() % places.size()], _random_place_pitch())
	var hiss := LIMB_PLACE_SOUND_DIR + hisses[randi() % hisses.size()]
	get_tree().create_timer(LIMB_DECOMPRESS_DELAY).timeout.connect(func() -> void:
		if is_inside_tree():
			_play_one_shot(hiss, _random_place_pitch()))


## A random pitch for the place sounds: up or down by a whole percent, at most
## LIMB_PLACE_PITCH_VARIATION_PERCENT.
func _random_place_pitch() -> float:
	var percent := randi_range(-LIMB_PLACE_PITCH_VARIATION_PERCENT, LIMB_PLACE_PITCH_VARIATION_PERCENT)
	return 1.0 + float(percent) / 100.0


## The red top-right oil readout, styled like the stress-test HUD labels. Parented to the
## full-screen HUD root (not the CameraWindow, which overflows/clips under the aspect COVER,
## nor the scene) so it stays pinned to the top-right of the view, never the background.
func _spawn_oil_label() -> void:
	var hud_root: Node = get_node_or_null("FullscreenLayer/FullscreenRoot")
	if hud_root == null:
		hud_root = camera_window
	if hud_root == null:
		return
	_oil_label = Label.new()
	_oil_label.name = "OilLabel"
	_oil_label.anchor_left = 1.0
	_oil_label.anchor_top = 0.0
	_oil_label.anchor_right = 1.0
	_oil_label.anchor_bottom = 0.0
	_oil_label.offset_left = -220.0
	_oil_label.offset_top = 12.0
	_oil_label.offset_right = -12.0
	_oil_label.offset_bottom = 52.0
	_oil_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_oil_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_oil_label.add_theme_color_override("font_color", OIL_LABEL_COLOR)
	_oil_label.add_theme_font_size_override("font_size", OIL_LABEL_FONT_SIZE)
	_oil_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_oil_label.z_index = 120
	hud_root.add_child(_oil_label)
	_refresh_oil_label()


## Suspicion, anger and fatigue, stacked under the oil readout in the top-right and kept
## up to date as they change.
func _spawn_stat_labels() -> void:
	var hud_root: Node = _oil_label.get_parent() if _oil_label != null else null
	if hud_root == null:
		return
	var top := _oil_label.offset_bottom
	for stat in ["suspicion", "anger", "fatigue"]:
		var label := Label.new()
		label.name = String(stat).capitalize() + "Label"
		label.anchor_left = 1.0
		label.anchor_right = 1.0
		label.offset_left = -220.0
		label.offset_right = -12.0
		label.offset_top = top
		label.offset_bottom = top + STAT_LABEL_HEIGHT
		label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_color_override("font_color", STAT_LABEL_COLORS[stat])
		label.add_theme_font_size_override("font_size", STAT_LABEL_FONT_SIZE)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = _oil_label.z_index
		hud_root.add_child(label)
		_stat_labels[stat] = label
		top += STAT_LABEL_HEIGHT
	for changed in [GameState.suspicion_changed, GameState.anger_changed, GameState.fatigue_changed]:
		if not changed.is_connected(_refresh_stat_labels):
			changed.connect(_refresh_stat_labels)
	_refresh_stat_labels()


func _refresh_stat_labels(_value: int = 0) -> void:
	var values := {"suspicion": GameState.suspicion, "anger": GameState.anger, "fatigue": GameState.fatigue}
	for stat in _stat_labels:
		var label: Label = _stat_labels[stat]
		if is_instance_valid(label):
			label.text = "%s: %d" % [String(stat).capitalize(), int(values[stat])]


## Caches the oil draggable and builds its idle texture + pour-animation frames.
func _cache_oil_item() -> void:
	_oil_item = _find_draggable_item_by_id(self, OIL_ITEM_ID)
	if _oil_idle_texture == null:
		_oil_idle_texture = load(OIL_IDLE_TEXTURE_PATH) as Texture2D
	if _oil_pour_frames.is_empty():
		_oil_pour_frames = _build_oil_pour_frames()


## Slices the vertical oil-pour sheet into its square frames.
func _build_oil_pour_frames() -> Array[AtlasTexture]:
	var out: Array[AtlasTexture] = []
	var sheet := load(OIL_POUR_SHEET_PATH) as Texture2D
	if sheet == null or OIL_POUR_FRAME_COUNT <= 0:
		return out
	var fw := sheet.get_width()
	var fh := int(sheet.get_height() / OIL_POUR_FRAME_COUNT)
	for i in OIL_POUR_FRAME_COUNT:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(0, i * fh, fw, fh)
		out.append(atlas)
	return out


## Drains the oil while the can is held pouring over (or just above) the robot, plays the
## pour animation while it does, and keeps the label in sync every frame.
func _update_oil_pour(delta: float) -> void:
	if _oil_item == null or not is_instance_valid(_oil_item):
		_cache_oil_item()
	# An emptied can just waits (tipped over) until released - the fall/refill is handled
	# by _on_dock_item_released, so don't touch its texture, rotation or scale here.
	if _oil_empty:
		_refresh_oil_label()
		return
	var pouring := _oil_is_pouring()
	if pouring:
		_oil_remaining = maxf(0.0, _oil_remaining - OIL_POUR_RATE * delta)
		_advance_oil_pour_animation(delta)
		if _oil_remaining <= 0.0:
			_enter_oil_empty()
	else:
		_reset_oil_pour_animation()
	_refresh_oil_label()


## The can has run dry: swap back to the (upright) idle can art but tip it 90° so its top
## faces west, keeping it at the scene pixel ratio while it is still held.
func _enter_oil_empty() -> void:
	_oil_empty = true
	if _oil_item == null or not is_instance_valid(_oil_item):
		return
	if _oil_idle_texture != null:
		_oil_item.texture = _oil_idle_texture
	if _oil_item.is_dragging():
		_match_item_to_background(_oil_item)  # sets the centre pivot + scene scale
	_oil_item.pivot_offset = _oil_item.size * 0.5
	_oil_item.rotation = OIL_EMPTY_ROTATION


## Lets the emptied can fall away with (accelerating) gravity when the player lets go,
## cancelling the normal snap-home. When it lands, a spare oil can (if any) refills it.
func _start_oil_can_fall() -> void:
	var item := _oil_item
	if item == null or not is_instance_valid(item):
		return
	if item.has_method("stop_home_motion"):
		item.stop_home_motion()  # cancel WorkInventory's snap-home tween
	# Reparent to the camera window so the can can fall across the whole scene, kept at the
	# scene's pixel ratio.
	var target_parent: Control = camera_window if camera_window != null else self
	var gpos := item.global_position
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	target_parent.add_child(item)
	item.global_position = gpos
	_match_item_to_background(item)
	item.pivot_offset = item.size * 0.5
	var drop := (target_parent.size.y if target_parent is Control else 800.0) + 400.0
	var fall_to := item.position + Vector2(randf_range(-24.0, 24.0), drop)
	var tw := item.create_tween()
	# EASE_IN on a quadratic reads as gravity (accelerating downward); spin as it drops.
	tw.tween_property(item, "position", fall_to, OIL_FALL_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(item, "rotation", item.rotation - PI, OIL_FALL_SECONDS)
	tw.chain().tween_callback(_resolve_oil_after_fall)


## After the can falls: it was one of the player's oil cans (each "oil" in the inventory is a
## can of OIL_TOTAL), so it's used up. The next can taken out of the inventory is full.
func _resolve_oil_after_fall() -> void:
	var item := _oil_item
	if item == null or not is_instance_valid(item):
		return
	if int(GameState.ingredients.get("oil", 0)) >= 1:
		GameState.add_ingredient("oil", -1)
	_oil_remaining = OIL_TOTAL
	_oil_empty = false
	item.rotation = 0.0
	item.scale = Vector2.ONE
	if _oil_idle_texture != null:
		item.texture = _oil_idle_texture
	if item.home_slot != null and is_instance_valid(item.home_slot):
		item.place_in(item.home_slot)
	_refresh_oil_label()


## True while the oil can is being dragged, still has oil, and the robot is under the pour:
## the mouse is over the robot, or the robot is within OIL_POUR_PROXIMITY_PX directly below
## the mouse (so holding the can just above the robot still counts).
func _oil_is_pouring() -> bool:
	if _oil_item == null or not is_instance_valid(_oil_item):
		return false
	if not _oil_item.visible or not _oil_item.is_dragging():
		return false
	if _oil_remaining <= 0.0:
		return false
	if _hover_box == null or not is_instance_valid(_hover_box) or not _hover_box.is_visible_in_tree():
		return false
	var rect := _hover_box.get_global_rect()
	var m := get_global_mouse_position()
	if rect.has_point(m):
		return true
	# Robot within OIL_POUR_PROXIMITY_PX directly below the mouse.
	if m.x >= rect.position.x and m.x <= rect.position.x + rect.size.x:
		var gap := rect.position.y - m.y  # > 0 means the robot's top is below the mouse
		if gap >= 0.0 and gap <= OIL_POUR_PROXIMITY_PX:
			return true
	return false


func _advance_oil_pour_animation(delta: float) -> void:
	if _oil_item == null or not is_instance_valid(_oil_item) or _oil_pour_frames.is_empty():
		return
	_oil_pour_anim_time += delta
	var frame := int(_oil_pour_anim_time / maxf(0.01, OIL_POUR_FRAME_SECONDS)) % _oil_pour_frames.size()
	_oil_item.texture = _oil_pour_frames[frame]
	# The pour frames are taller than the idle can, so their KEEP_ASPECT fit differs -
	# re-match the grab scale so the can stays at the background's pixel ratio, not shrunk.
	_match_item_to_background(_oil_item)


func _reset_oil_pour_animation() -> void:
	_oil_pour_anim_time = 0.0
	if _oil_item != null and is_instance_valid(_oil_item) and _oil_idle_texture != null \
			and _oil_item.texture != _oil_idle_texture:
		_oil_item.texture = _oil_idle_texture
		# Swapping back to the shorter idle can changes the fit; re-match while still held
		# (at rest the release handler already restored the resting scale, so leave it).
		if _oil_item.is_dragging():
			_match_item_to_background(_oil_item)


func _refresh_oil_label() -> void:
	if _oil_label != null and is_instance_valid(_oil_label):
		_oil_label.text = "Oil: %d" % int(round(_oil_remaining))


func _find_draggable_item_by_id(node: Node, item_id: StringName) -> DraggableItem:
	for child in node.get_children():
		if child is DraggableItem and child.item_id == item_id:
			return child
		var found := _find_draggable_item_by_id(child, item_id)
		if found != null:
			return found
	return null


func _toggle_robot_box_zoom() -> void:
	if _zoomed:
		_reset_zoom()
	else:
		_zoom_to_robot_box()


func _zoom_to_robot_box() -> void:
	if camera_window == null or scene_canvas == null:
		return

	var robot_rect := _robot_bbox_in_scene_canvas()
	var view_top := clampf(robot_rect.position.y, 0.0, BASE_SCENE_SIZE.y)
	var full_robot_view_height := BASE_SCENE_SIZE.y - view_top
	if full_robot_view_height <= 0.0 or camera_window.size.y <= 0.0:
		return

	_zoom_scale = maxf(1.0, BASE_SCENE_SIZE.y / full_robot_view_height) * ZOOM_MULTIPLIER
	_center_zoomed_view_horizontally()
	_view_top = _max_view_top()
	_animate_to_view(_view_left, _view_top)
	_zoomed = true


func _reset_zoom() -> void:
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoomed = false
	_zoom_scale = 1.0
	_view_left = 0.0
	_view_top = 0.0
	_apply_default_canvas_transform()


func _scroll_zoomed_view(button_index: int) -> void:
	var step := _current_view_size().y * SCROLL_STEP_VIEW_FRACTION
	if button_index == MOUSE_BUTTON_WHEEL_UP:
		_view_top -= step
	else:
		_view_top += step
	_view_top = clampf(_view_top, 0.0, _max_view_top())
	_animate_to_view(_view_left, _view_top)


func _apply_default_canvas_transform() -> void:
	if camera_window == null or scene_canvas == null:
		return
	if camera_window.size == Vector2.ZERO:
		return

	_canvas_base_scale = minf(
		camera_window.size.x / BASE_SCENE_SIZE.x,
		camera_window.size.y / BASE_SCENE_SIZE.y
	)
	scene_canvas.size = BASE_SCENE_SIZE
	scene_canvas.pivot_offset = Vector2.ZERO
	var view_scale := _default_view_scale()
	scene_canvas.scale = Vector2(view_scale, view_scale)
	scene_canvas.position = _default_view_base_position() + _mouse_follow_offset


## The scale of the resting (non robot-box) camera view: the plain fit scale nudged in by
## mouse_follow_zoom_scale so there is margin to drift into as the view tracks the mouse.
## The robot-box zoom deliberately ignores this and works off the pure fit scale.
func _default_view_scale() -> float:
	return _canvas_base_scale * maxf(1.0, mouse_follow_zoom_scale)


## Centered on-screen position of the slightly-zoomed default view, before the sway offset.
func _default_view_base_position() -> Vector2:
	var display_size := BASE_SCENE_SIZE * _default_view_scale()
	return (camera_window.size - display_size) * 0.5


func _camera_mouse_follow_enabled() -> bool:
	var state := get_node_or_null("/root/GameState")
	return state == null or bool(state.get("camera_mouse_follow_enabled"))


## Called every frame: while the whole-scene view is shown (not robot-box zoomed), drift it
## toward the mouse by a small, edge-softened offset added on top of the resting position.
## During the robot-box zoom (or when the CAMERA SWAY setting is off) the offset eases back
## to zero so nothing fights the zoom.
func _update_camera_mouse_follow(delta: float) -> void:
	if camera_window == null or scene_canvas == null or camera_window.size == Vector2.ZERO:
		return
	var zoom_animating := _zoom_tween != null and _zoom_tween.is_running()
	var at_default_view := not _zoomed and not zoom_animating
	var smoothing := 1.0 - exp(-mouse_follow_smoothing * maxf(0.0, delta))
	var following := _camera_mouse_follow_enabled() and at_default_view
	var target := _mouse_follow_target() if following else Vector2.ZERO
	# The sway holds still while the inventory is open.
	if not InventoryOverlay.is_open(get_tree()):
		_mouse_follow_offset = _mouse_follow_offset.lerp(target, smoothing)
	# The robot-box zoom tween owns the canvas position while it runs; only steer the
	# resting default view here.
	if at_default_view:
		scene_canvas.position = _default_view_base_position() + _mouse_follow_offset


## The sway offset the current mouse position calls for. The pull toward the cursor grows
## from the view centre and tapers exponentially toward the edges (via _mouse_follow_falloff)
## so it never lurches, then is clamped to the margin the slight zoom created so no scene
## edge is ever revealed. The horizontal and vertical multipliers exaggerate each axis.
func _mouse_follow_target() -> Vector2:
	if mouse_follow_strength == 0.0:
		return Vector2.ZERO
	var view_size := camera_window.size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return Vector2.ZERO
	var center := view_size * 0.5
	var mouse := camera_window.get_local_mouse_position()
	var normalized := Vector2((mouse.x - center.x) / center.x, (mouse.y - center.y) / center.y)
	var pull := Vector2(_mouse_follow_falloff(normalized.x), _mouse_follow_falloff(normalized.y))
	# Negative: shifting the canvas the opposite way moves the *view* toward the cursor, so
	# the camera drifts with the mouse.
	var offset := -pull * mouse_follow_strength
	offset.x *= mouse_follow_horizontal_strength
	offset.y *= mouse_follow_vertical_strength
	offset *= _camera_sway_factor
	# Never drift past the slight zoom's margin (which would show the scene's edges).
	var margin := (BASE_SCENE_SIZE * _default_view_scale() - view_size) * 0.5
	offset.x = clampf(offset.x, -maxf(0.0, margin.x), maxf(0.0, margin.x))
	offset.y = clampf(offset.y, -maxf(0.0, margin.y), maxf(0.0, margin.y))
	return offset


## Signed, saturating edge falloff for one axis: near the centre it grows ~linearly with the
## cursor's distance; toward the edge each extra bit of distance adds exponentially less, so
## the pull eases off smoothly (never snapping at the border).
func _mouse_follow_falloff(x: float) -> float:
	return signf(x) * (1.0 - exp(-absf(x) * mouse_follow_edge_falloff))


func _animate_to_view(view_left: float, view_top: float) -> void:
	var target_scale := _canvas_base_scale * _zoom_scale
	var target_position := Vector2(
		-view_left * target_scale,
		-view_top * target_scale
	)

	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.set_parallel(true)
	_zoom_tween.set_trans(PAN_TRANS)
	_zoom_tween.set_ease(PAN_EASE)
	_zoom_tween.tween_property(scene_canvas, "scale", Vector2(target_scale, target_scale), PAN_DURATION)
	_zoom_tween.tween_property(scene_canvas, "position", target_position, PAN_DURATION)


func _center_zoomed_view_horizontally() -> void:
	var view_size := _current_view_size()
	var max_view_left := maxf(0.0, BASE_SCENE_SIZE.x - view_size.x)
	_view_left = clampf(BASE_SCENE_SIZE.x * 0.5 - view_size.x * 0.5, 0.0, max_view_left)


func _current_view_size() -> Vector2:
	var target_scale := _canvas_base_scale * _zoom_scale
	if target_scale <= 0.0:
		return BASE_SCENE_SIZE
	return camera_window.size / target_scale


func _max_view_top() -> float:
	return maxf(0.0, BASE_SCENE_SIZE.y - _current_view_size().y)


func _robot_bbox_in_scene_canvas() -> Rect2:
	var to_scene := scene_canvas.get_global_transform_with_canvas().affine_inverse() \
		* robot.get_global_transform_with_canvas()
	var points := [
		to_scene * _robot_bbox_local.position,
		to_scene * (_robot_bbox_local.position + Vector2(_robot_bbox_local.size.x, 0.0)),
		to_scene * (_robot_bbox_local.position + Vector2(0.0, _robot_bbox_local.size.y)),
		to_scene * (_robot_bbox_local.position + _robot_bbox_local.size),
	]
	var min_point: Vector2 = points[0]
	var max_point: Vector2 = points[0]
	for point in points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)


func _on_camera_window_resized() -> void:
	if _zoomed:
		return
	_apply_default_canvas_transform()


func _on_end_button_pressed() -> void:
	finish()
