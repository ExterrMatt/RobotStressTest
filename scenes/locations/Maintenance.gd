extends LocationBase

const RobotHoverBox: GDScript = preload("res://scenes/locations/RobotHoverBox.gd")
const LAPTOP_SCENE: PackedScene = preload("res://scenes/locations/Laptop.tscn")

const PAN_DURATION: float = 0.35
const PAN_TRANS: int = Tween.TRANS_SINE
const PAN_EASE: int = Tween.EASE_IN_OUT
const BASE_SCENE_SIZE: Vector2 = Vector2(500.0, 400.0)
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
const MAINTENANCE_ITEM_IDS: Array[StringName] = [
	&"taser",
]
## The battery is not a generic full-robot drop; it targets the pelvis hover box
## and plays the battery-insert animation (see _spawn_pose_boxes / _on_battery_released).
const BATTERY_ITEM_ID: StringName = &"battery"
## The nanobots (quick_patch) are not a slot drop either: releasing them over the robot
## makes them vanish at the drop point and spawns the spreading NanobotEffect there
## (see _connect_nanobot_item / _on_nanobots_released).
const NANOBOT_ITEM_ID: StringName = &"quick_patch"

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

## Design values for the corner END button, kept in sync with Main's shared
## floating END/LEAVE button: the GoldHudButton look at 1.5x font + padding.
const END_BUTTON_FONT_SIZE: int = 48         # Main.LARGE_SCENE_HUD_FONT_SIZE (32) * 1.5
const END_BUTTON_PADDING_SCALE: float = 1.5  # Main.LARGE_SCENE_END_BUTTON_SIZE_SCALE

@onready var camera_window: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow
@onready var scene_canvas: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas
@onready var robot: Control = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/SceneCanvas/RobotLayer/MaintenanceRobot
@onready var end_button: Button = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/EndButton
@onready var laptop_button: Button = $FullscreenLayer/FullscreenRoot/SceneScaler/CameraWindow/LaptopButton
## Idle template of the nanobot spread effect. Its exported variables are tuned in the
## editor; each nanobot drop duplicates it so the copy carries those settings.
@onready var _nanobot_effect_template: NanobotEffect = $NanobotEffectTemplate

## The laptop overlay while it is open (assembly app); null when closed.
var _laptop_overlay: Node = null
## While the laptop is open the camera sway is damped to a fifth so it barely drifts.
const LAPTOP_CAMERA_SWAY_FACTOR: float = 0.2
var _camera_sway_factor: float = 1.0

var _robot_bbox_local: Rect2 = Rect2()
var _hover_box: Control = null
var _drop_slots: Array[DropSlot] = []
## Per-leg hover boxes (click to swing that leg out) and the pelvis battery-drop
## box, keyed "left"/"right"/"pelvis". Created in _spawn_pose_boxes().
var _pose_boxes: Dictionary = {}
var _battery_item: DraggableItem = null
var _nanobot_item: DraggableItem = null
var _oil_item: DraggableItem = null
var _oil_label: Label = null
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
	_connect_item_grab_scaling()
	_spawn_oil_label()
	_style_button_like_workshop(end_button)
	_style_button_like_workshop(laptop_button)
	if laptop_button != null and not laptop_button.pressed.is_connected(_on_laptop_button_pressed):
		laptop_button.pressed.connect(_on_laptop_button_pressed)
	_connect_inventory_signals()
	call_deferred("_cache_oil_item")
	# Pre-build the robot silhouette mask now (off the drop) so the first nanobot drop,
	# which needs it, doesn't pay the one-time build cost as a visible hitch.
	call_deferred("_warm_nanobot_mask")


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


## Rebuilds the robot's layer stack from the current inventory and re-derives every
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


## Pre-builds (and caches) the robot's silhouette mask so a later nanobot drop reads it
## instead of building it mid-effect. Cheap when the cache is already warm.
func _warm_nanobot_mask() -> void:
	if robot != null and is_instance_valid(robot) and robot.has_method("get_opaque_mask"):
		robot.call("get_opaque_mask")


## Restyle the in-scene END button to match Main's shared corner END/LEAVE button
## (the gold-bordered GoldHudButton look at 1.5x font + padding). Only the design
## changes: the button keeps its authored bottom-right anchor and offsets, and
## since it grows toward the top-left (grow direction BEGIN) its bottom-right
## corner stays exactly where it is while the larger design expands up and left.
func _style_button_like_workshop(btn: Button) -> void:
	if btn == null:
		return
	btn.theme_type_variation = &"GoldHudButton"
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", END_BUTTON_FONT_SIZE)
	# Scale each state's stylebox padding to match the enlarged font while leaving
	# the theme's border width untouched (so it stays crisp, like Main's button).
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var base := btn.get_theme_stylebox(state)
		if base == null:
			continue
		var sb := base.duplicate() as StyleBox
		sb.content_margin_left = base.get_margin(SIDE_LEFT) * END_BUTTON_PADDING_SCALE
		sb.content_margin_top = base.get_margin(SIDE_TOP) * END_BUTTON_PADDING_SCALE
		sb.content_margin_right = base.get_margin(SIDE_RIGHT) * END_BUTTON_PADDING_SCALE
		sb.content_margin_bottom = base.get_margin(SIDE_BOTTOM) * END_BUTTON_PADDING_SCALE
		btn.add_theme_stylebox_override(state, sb)


## Open the laptop (assembly app) as a fullscreen overlay on top of maintenance —
## the same "instantiate the scene and show it over this one" approach the workshop
## uses for its minigame. While it is up, maintenance's own robot input is paused so
## clicks belong to the laptop; closing it restores everything.
func _on_laptop_button_pressed() -> void:
	if _laptop_overlay != null and is_instance_valid(_laptop_overlay):
		return
	var laptop: Node = LAPTOP_SCENE.instantiate()
	# Laptop.gd has no class_name, so drive it dynamically.
	laptop.set("overlay_mode", true)
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


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return

	if robot_box_zoom_enabled and _zoomed \
			and mouse_event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_scroll_zoomed_view(mouse_event.button_index)
		get_viewport().set_input_as_handled()
		return

	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

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

	# Leg boxes: click to swing that leg out.
	if robot.has_method("leg_rect") and robot.has_method("has_leg"):
		for side in ["left", "right"]:
			if not bool(robot.call("has_leg", side)):
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
	var ids: Array[StringName] = [OIL_ITEM_ID, NANOBOT_ITEM_ID, BATTERY_ITEM_ID]
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


## After the can falls: if the player owns another oil can, consume it and hand back a full
## 100/100 can in the dock; otherwise the can is spent and gone.
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
		item.visible = true
		if item.home_slot != null and is_instance_valid(item.home_slot):
			item.place_in(item.home_slot)
	else:
		item.visible = false
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
